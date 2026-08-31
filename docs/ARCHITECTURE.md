<div align="center">

# Arquitetura

**Nexus Tech** · IFRS Campus Osório

*O que existe, por que está assim, e o que muda a seguir.*

**Português** · [English](ARCHITECTURE.en.md)

</div>

---

## Sumário

**[1. Visão geral](#1-visão-geral)** · **[2. Princípios](#2-princípios)** · **[3. Camadas](#3-camadas)** · **[4. Domínio](#4-modelo-de-domínio)** · **[5. Persistência](#5-persistência)** · **[6. Segurança](#6-segurança)** · **[7. Estado](#7-gerenciamento-de-estado)** · **[8. Erros](#8-tratamento-de-erros)** · **[9. Fluxos críticos](#9-fluxos-críticos)** · **[10. Decisões](#10-decisões-e-trade-offs)** · **[11. Evolução](#11-pontos-de-evolução)**

---

## 1. Visão geral

Aplicação Flutter com Firebase como *backend as a service*. Não há servidor próprio: a lógica de negócio reside no cliente e a segurança é imposta por **Firestore Rules** e **Storage Rules**.

```
┌──────────────────────────────────────────────────────────┐
│                     Cliente Flutter                      │
│                                                          │
│   ┌────────┐      ┌───────────┐      ┌──────────────┐    │
│   │ Telas  │ ───▶ │ Providers │ ───▶ │ Repositórios │    │
│   │  (UI)  │ ◀─── │  (estado) │ ◀─── │  (Firebase)  │    │
│   └────────┘      └───────────┘      └──────┬───────┘    │
└─────────────────────────────────────────────┼────────────┘
                                              ▼
                        ┌──────────────────────────────────┐
                        │  Firebase — impõe as regras      │
                        │  Auth · Firestore · Storage      │
                        │  firestore.rules · storage.rules │
                        └──────────────────────────────────┘
```

**Trade-off central.** O Firebase eliminou meses de desenvolvimento de backend, mas toda decisão futura sobre escala, custo e dependência de fornecedor passa por ele. A reversão exige reescrever a camada de repositórios — e apenas ela, o que é justamente o objetivo do isolamento descrito na seção 3.

---

## 2. Princípios

Em caso de conflito, prevalece o princípio de menor número.

**2.1 · Camadas com responsabilidade única.** A interface nunca acessa o Firebase. O provider nunca importa pacotes do Flutter além do `material`. O repositório nunca decide regra de negócio.

**2.2 · Segurança em profundidade.** O validador em Dart é experiência de uso. A Firestore Rule é segurança. A Storage Rule é segurança novamente. Cada camada isolada é insuficiente.

**2.3 · Tempo real onde o usuário espera ver mudança.** `Stream` para o que muda durante a sessão; `Future` para o que não muda.

**2.4 · Exceções tipadas.** Toda falha do Firebase atravessa `mapFirestoreError()` e se torna uma `AppException`. A interface nunca recebe uma `FirebaseException` bruta.

**2.5 · Falhar com honestidade.** Falha em operação principal aborta com mensagem clara. Falha em operação secundária — registro de auditoria, contagem — é tolerada e o fluxo prossegue.

---

## 3. Camadas

### 3.1 Apresentação — `features/*/screens` e `widgets`

Widgets que consomem providers via `context.watch` e `context.read`, sem dependência direta de Firebase ou repositórios.

Padrões uniformes: formulários com `GlobalKey<FormState>` e validadores puros; estados de carregamento, vazio, erro e conteúdo sempre explícitos; listas em `ListView.separated`.

### 3.2 Estado — `features/*/providers`

`ChangeNotifier` sobre `package:provider`. Dez providers globais, registrados em `App` e não nas telas — do contrário, abrir e fechar uma tela descartaria requisições em andamento.

| Provider | Responsabilidade |
|---|---|
| `AuthProvider` | Autenticação e perfil **observado em tempo real** |
| `CadastroProvider` | Cadastro inicial e gestão de áreas |
| `DemandasProvider` | Listagem do demandante e filtros |
| `DemandaFormProvider` | Criação, edição e anexos pendentes |
| `ProfessorDemandasProvider` | Prateleira pública e demandas do professor |
| `AcaoDemandaProvider` | Estado efêmero das transições de status |
| `PerfilProvider` | Edição de perfil e fotografia |
| `NotificacoesProvider` | Central de avisos e contador do sino |
| `ChatsProvider` | Lista de conversas e mensagens não lidas |
| `AdminProvider` | Denúncias, docentes e demandantes |

**Critério para promover a global.** Os três últimos alimentam **contadores visuais** que precisam estar corretos em qualquer aba. Instanciá-los por tela zeraria a contagem a cada navegação.

**O que permanece local.** A conversa aberta e as telas de detalhe consomem os streams do repositório diretamente, via `StreamBuilder`. Seu estado nasce e morre com a tela.

### 3.3 Dados — `core/repositories`

Única camada que importa `cloud_firestore`, `firebase_storage` e `firebase_auth`. Tudo que sai daqui é objeto de domínio.

```dart
Future<X> operacao(...) async {
  try {
    final resultado = await _firestore. …;
    return mapearDeFirestore(resultado);
  } catch (e) {
    throw mapFirestoreError(e, recurso: 'NomeDoRecurso');
  }
}
```

### 3.4 Domínio — `core/models`

Classes Dart puras, com uma exceção deliberada: as enums de estado (`StatusDemanda`, `StatusDenuncia`, `TipoNotificacao`) carregam `label`, `icone` e `cor`. Encapsular a apresentação canônica no domínio evita que a mesma decisão visual seja reescrita em cada tela.

Padrão uniforme: `fromMap(id, Map)`, `toMap()` e `copyWith()` quando aplicável. Toda desserialização é defensiva — documentos criados por versões anteriores não podem derrubar a leitura.

---

## 4. Modelo de domínio

### 4.1 Usuários

```
              ┌───────────────────┐
              │ Usuario (abstrata)│
              │ uid · email       │
              │ nome · role       │
              │ criadoEm · fotoUrl│
              └─────────┬─────────┘
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   Demandante       Professor      Administrador
   telefone         siape          (campos da base)
   tipo             areasTecnicas
   cpfCnpj          areasInteresse
   endereco         ativo
   strikes          desativadoEm
   banido           motivoDesativacao
   banidoEm
   motivoBanimento
```

O demandante exige CPF ou CNPJ; o professor exige SIAPE. A exigência no construtor previne objetos parcialmente válidos. `UsuarioRepository` lê o campo `role` e instancia a subclasse correspondente; um `role` ausente ou corrompido retorna `null`, tratado como "cadastro necessário".

**Estado de moderação reside no usuário.** `banido` e `ativo` são propriedades do perfil para que as Firestore Rules possam consultá-las com uma única leitura do documento que já precisariam ler. Uma coleção separada de suspensões exigiria leitura adicional em cada escrita protegida.

**Banimento é regra derivada.** `banido == (strikes >= AppConstants.strikesParaBanimento)`. Não existe interruptor independente — nem no julgamento de denúncia, nem no ajuste manual do administrador. Um interruptor separado permitiria o estado incoerente de conta suspensa com uma única advertência.

### 4.2 Demanda — máquina de estados

```
                    ┌─────────────┐
      publicar ───▶ │ cadastrada  │ ───── editar
                    └──┬───────┬──┘       [demandante]
       [professor]     │       │     cancelar [demandante]
        reservar       ▼       ▼
              ┌─────────────┐ ┌───────────┐
              │  emAnalise  │ │ cancelada │
              └──┬───────┬──┘ └─────┬─────┘
     devolver    │       │  assumir │
     ou expirar  │       ▼          ▼
     (24 h) ─────┘  ┌────────────┐  republicar ──▶ demanda nova
                    │ emProducao │                 (cadastrada)
                    └─────┬──────┘
                          ▼  concluir
                    ┌────────────┐
                    │ concluida  │
                    └────────────┘
```

As transições válidas são declaradas em um único mapa, `StatusDemanda._transicoes` — fonte única de verdade consultada pelas transações do repositório. Getters derivados (`podeAssumir`, `podeConcluir`, `visivelNaPrateleira`) evitam condicionais de status espalhadas pela interface.

Estados terminais não têm saída: a republicação de uma demanda cancelada **cria uma demanda nova**, e não uma transição da original.

### 4.3 Comunicação e moderação

| Entidade | Identificador | Observação |
|---|---|---|
| `Chat` | igual ao `demandaId` | Um chat por demanda, nem mais nem menos |
| `Mensagem` | gerado | Subcoleção de `Chat`; histórico imutável |
| `Notificacao` | gerado | O tipo determina ícone, cor e destino de navegação |
| `Denuncia` | `{demandaId}__{professorUid}` | Um professor denuncia cada demanda uma vez |

**Identificadores determinísticos por desenho.** Usar o `demandaId` como identificador do chat torna a criação idempotente: uma repetição por falha de rede ou uma reassunção após devolução reescrevem o mesmo documento em vez de criar conversas paralelas. O mesmo raciocínio se aplica à denúncia, onde a unicidade também transforma "já denunciei isto?" em uma leitura pontual, sem consulta nem índice.

**Denormalização deliberada.** `Chat.participantes` duplica os dois identificadores em um vetor porque o Firestore não realiza disjunção entre campos distintos em uma única consulta. `Chat.naoLidas` mantém os contadores no documento do chat, escritos na mesma transação da mensagem, para que a lista de conversas não precise percorrer a subcoleção.

---

## 5. Persistência

### 5.1 Coleções

```
users/{uid}              identificador = uid do Auth
demandas/{id}
  anexos/{anexoId}       subcoleção
chats/{demandaId}        identificador = demandaId
  mensagens/{msgId}      subcoleção, imutável
notificacoes/{id}        avisos in-app
denuncias/{id}           identificador determinístico
areas_tecnicas/{id}      vocabulário compartilhado
areas_interesse/{id}
audit_logs/{id}          somente adição; leitura restrita ao administrador
```

**Subcoleções em vez de vetores embutidos.** O documento do Firestore tem limite de 1 MB. Anexos e mensagens crescem sem teto previsível; embutidos, o estouro é questão de tempo. A subcoleção ainda permite paginar os mais recentes e aplicar regras independentes.

**Notificações em coleção raiz.** Simplifica a regra de leitura e permite que uma futura Cloud Function observe uma única coleção, em vez de um *collection group*.

### 5.2 Índices compostos

| Coleção | Campos |
|---|---|
| `demandas` | `demandanteUid` · `criadoEm` ▾ |
| `demandas` | `demandanteUid` · `status` · `criadoEm` ▾ ▴ |
| `demandas` | `status` · `criadoEm` ▾ |
| `demandas` | `professorUid` · `criadoEm` ▾ |
| `demandas` | `professorUid` · `status` · `criadoEm` ▾ |
| `notificacoes` | `destinatarioUid` · `criadoEm` ▾ |
| `notificacoes` | `destinatarioUid` · `lida` |
| `chats` | `participantes` (vetor) · `ultimaMensagemEm` ▾ |
| `denuncias` | `status` · `criadoEm` ▾ |
| `denuncias` | `professorUid` · `criadoEm` ▾ |
| `denuncias` | `demandanteUid` · `criadoEm` ▾ |
| `audit_logs` | `autorUid` · `acao` |

Definidos em `firestore.indexes.json`. Sem o índice, a consulta falha em tempo de execução — nunca em compilação.

> **Armadilha do `orderBy`.** O Firestore omite documentos que não possuem o campo ordenado. A lista de conversas ordena por `ultimaMensagemEm`; um chat recém-criado, ainda sem esse campo, não apareceria. Por isso a criação do chat é sempre seguida de uma mensagem de sistema — é ela que atribui o primeiro valor ao campo.

### 5.3 Storage

```
demandas/{demandaId}/anexos/{timestamp}_{nome}.{ext}
users/{uid}/{arquivo}
```

`customMetadata` carrega `enviadoPorUid`, o que permite às Storage Rules autorizarem a exclusão sem consultar o Firestore.

---

## 6. Segurança

### 6.1 Camada 1 — cliente

`core/utils/validators.dart` implementa CPF e CNPJ pelo módulo 11 oficial, rejeita sequências repetidas, valida os DDDs da Anatel e distingue telefone fixo de celular. Serve à experiência de uso e evita requisições inúteis. **Não constitui segurança.**

### 6.2 Camada 2 — Firestore Rules

Três mecanismos sustentam as regras.

**Superfície mínima de escrita.** Cada perfil declara exatamente quais campos pode alterar, via `diff(resource.data).affectedKeys().hasOnly([...])`. É uma lista de permissões, não de proibições: um campo novo nasce negado e só é liberado por decisão consciente.

**Estado da conta como condição.**

```
function contaSuspensa() {
  return meuPerfil().get('banido', false) == true;
}
function professorAtivo() {
  return meuPerfil().get('ativo', true) == true;
}
```

A criação de demandas exige `!contaSuspensa()` — é isso que confere efeito prático ao banimento. As transições do professor exigem `professorAtivo()`. O padrão em `get(campo, padrão)` cobre documentos anteriores a esses campos, preservando o comportamento histórico.

**Custo assumido.** Cada chamada dessas é uma leitura tarifada. Por isso aparecem apenas em **escritas**, jamais nas regras de leitura, que constituem o caminho de maior volume.

**Operações irreversíveis restritas.** `republicadaComoId` só pode ser preenchido uma vez; mensagens e anexos não aceitam atualização nem exclusão; o julgamento de denúncia é exclusivo do administrador.

### 6.3 Camada 3 — Storage Rules

Tipos MIME explícitos (PDF, DOCX, JPEG, PNG), limite de 10 MB para anexos e 5 MB para fotografias, exclusão restrita a quem enviou, e ausência de atualização — anexos são imutáveis.

### 6.4 Identificação de papéis

O papel de administrador e a exceção de professor são determinados por listas de endereços mantidas **em duplicidade**, no Dart e nas Rules. Comentários em ambos os arquivos advertem sobre a sincronização.

O acoplamento é conhecido e aceito provisoriamente. A solução adequada — *custom claims* atribuídas por Cloud Function — está registrada em [CLOUD_FUNCTIONS.md](CLOUD_FUNCTIONS.md).

---

## 7. Gerenciamento de estado

### 7.1 Padrão

```dart
class XProvider extends ChangeNotifier {
  // campos privados de estado
  // getters expõem leitura
  // métodos públicos disparam operações
  // notifyListeners() em cada transição
}
```

### 7.2 Streams e ciclo de vida

Os providers de listagem mantêm `StreamSubscription` ativa enquanto houver sessão. Alterar um filtro cancela a inscrição corrente e cria outra com a consulta atualizada; `dispose()` cancela na saída.

O perfil do usuário é observado durante toda a sessão. **Essa é a razão de decisões administrativas surtirem efeito imediato**: com leitura pontual, o usuário permaneceria operando sob o perfil anterior até reabrir a aplicação — precisamente o intervalo em que a suspensão deveria vigorar.

### 7.3 Busca textual

Aplicada em memória, sobre a lista já carregada. Adequada à escala de um campus. A prateleira do professor — que agrega todas as demandas do sistema — é o primeiro ponto que exigirá busca no servidor.

---

## 8. Tratamento de erros

```
AppException (sealed)
├── NetworkException          falha de conectividade
├── PermissionException       negado pelas Rules
├── NotFoundException         documento inexistente
├── ServerException           falha genérica do servidor
├── ValidationException       dado inválido do cliente
├── ConflictException         o recurso mudou entre leitura e escrita
├── ContaBloqueadaException   conta suspensa ou perfil desativado
└── AuthException             falha de autenticação
```

`mapFirestoreError()` converte por código, sem comparação de mensagens em nenhum outro ponto do sistema.

`ConflictException` sinaliza concorrência real: dois professores sobre a mesma demanda, dois administradores sobre a mesma denúncia. `ContaBloqueadaException` existe separada de `PermissionException` porque as mensagens diferem — uma informa ausência de permissão, a outra informa suspensão da conta e indica o que fazer.

**Tolerância seletiva.** Registros de auditoria, contagens e enfileiramento de notificações falham em silêncio. Operações principais nunca.

---

## 9. Fluxos críticos

### 9.1 Autenticação e roteamento

```
LoginScreen → AuthService.signInWithGoogle()
                      │
                      ▼  authStateChanges emite User
              AuthProvider assina users/{uid}
                      │
     ┌────────────────┼────────────────┐
     ▼                ▼                ▼
  cadastro       administrador     sem cadastro
  existente      (criado auto)     → tela conforme
     │                │               o endereço
     └────────┬───────┘
              ▼
      conta bloqueada? ── sim ──▶ ContaBloqueadaScreen
              │ não
              ▼
      tela conforme o papel
```

`AppRouter` avalia os bloqueios **antes** do papel: uma conta suspensa não possui área de trabalho, possui uma explicação.

### 9.2 Republicação — operação atômica

Cancelar e republicar cria a nova demanda e marca a original com `republicadaComoId` em um único `WriteBatch`. Sem atomicidade existiria o intervalo em que a nova demanda já existe e a original ainda oferece o botão de republicar, permitindo duplicatas.

Defesa em três camadas: a interface oculta o botão; o repositório usa lote atômico; a Rule impede o segundo preenchimento do campo.

### 9.3 Aceite — status e canal de conversa

```
DemandaRepository.assumir()
   │
   ▼  runTransaction
   ├── leitura da demanda — valida status e propriedade
   ├── atualização para emProducao
   └── criação de chats/{demandaId}
   │
   ▼  commit atômico
   ├──▶ registro de auditoria       (tolerante a falha)
   ├──▶ mensagem de sistema no chat (tolerante, porém necessária — §5.2)
   └──▶ notificação ao demandante   (tolerante a falha)
```

**Por que atômico.** Sem isso existiria o estado "demanda em produção sem canal de conversa" — visível ao usuário e impossível de resolver por ele.

**Por que a mensagem de boas-vindas fica fora da transação.** Escrever em subcoleção de documento que a própria transação está criando dependeria de uma leitura ainda inexistente.

### 9.4 Denúncia, advertência e suspensão

```
professor denuncia ──▶ fila do administrador ──▶ julgamento
                                                     │
                                       procedente ───┤
                                                     ▼
                              runTransaction
                              ├── leitura da denúncia — recusa se já julgada
                              ├── leitura do usuário  — antes de qualquer escrita
                              ├── strikes + 1 · banido = (strikes >= 3)
                              └── status, parecer e responsável
                                                     │
                                        commit ──────┤
                                                     ▼
                                      auditoria · notifica ambas as partes
```

A recusa de denúncia já julgada resolve a concorrência entre administradores. A atomicidade impede tanto "denúncia procedente sem advertência" quanto advertência duplicada por acionamento repetido.

### 9.5 Mensagem de chat

A transação lê o chat, valida participação e estado, grava a mensagem e atualiza a prévia e o contador de não lidas. O contador é **calculado**, não incrementado por operador de servidor: o documento já foi lido na transação, e o valor explícito permite que a Rule valide o resultado.

A notificação é criada **apenas quando o destinatário não possuía mensagens não lidas** naquela conversa. Em conversa ativa, avisar a cada mensagem saturaria a central; avisar na primeira de uma sequência transmite o mesmo sinal. O contador visual, atualizado sempre, cobre o restante.

---

## 10. Decisões e trade-offs

| Decisão | Motivo | Reavaliar quando |
|---|---|---|
| **Firebase como backend completo** | Elimina infraestrutura; tempo real nativo; camada gratuita suficiente | Custo mensal relevante, ou consultas que o Firestore não suporta |
| **Provider em vez de Riverpod ou BLoC** | Escopo cabe; equipe conhece; migração custaria sprints sem valor visível | Surgir a primeira dependência entre providers |
| **Sem repositório abstrato** | Não há intenção real de trocar de banco; a abstração seria custo sem benefício | Início de testes automatizados de repositório |
| **Enum em vez de máquina de estados formal** | Cinco estados e transições simples; biblioteca seria excesso | Dez ou mais estados, ou transições condicionais |
| **Exclusão lógica de demandas** | O histórico é parte do produto; a auditoria exige o registro | — |
| **Chat no Firestore, não no Realtime Database** | Atomicidade entre coleções; uma única linguagem de regras; volume real modesto | O chat se tornar canal de uso contínuo |
| **Métricas calculadas no cliente** | Uma consulta por professor consultado é mais barata que contadores consistentes | Centenas de demandas por docente |
| **Notificação de chat condicional** | Avisar a cada mensagem saturaria a central | — |

**Sobre o número de providers.** A passagem de seis para dez cruzou o limiar registrado como gatilho de reavaliação. A permanência em Provider foi decisão consciente: nenhum dos novos compartilha estado com os demais, e o acoplamento entre eles é nulo. A primeira dependência mútua torna a migração obrigatória.

---

## 11. Pontos de evolução

### Dependentes do plano Firebase

O plano gratuito não provisiona Cloud Functions nem Cloud Storage em projetos novos. O princípio adotado foi **não deixar funcionalidade pela metade**: cada uma possui versão operante hoje, com a parte dependente do plano pago isolada em um ponto de extensão explícito.

| Item | Situação atual | Pendência |
|---|---|---|
| Notificação por *push* | Central in-app completa | Função que observa `notificacoes` |
| Devolução automática em 24 h | Reconciliação no cliente | Tarefa agendada |
| *Custom claims* de papel | Listas duplicadas em Dart e Rules | Função que atribui a *claim* |
| Antivírus em anexos | Rules limitam tipo e tamanho | Verificação de conteúdo |
| Retenção de dados | Crescimento contínuo | Expurgo agendado |

Catálogo completo, com o gancho existente para cada item: [**CLOUD_FUNCTIONS.md**](CLOUD_FUNCTIONS.md).

### Prioridade alta

- **Testes das Firestore Rules com o Firebase Emulator.** As regras concentram a segurança do sistema e não possuem cobertura automatizada. É a camada em que um erro é simultaneamente silencioso e grave.
- **Testes de integração das três transações críticas** — republicação, aceite com criação de chat, e julgamento com advertência.
- **Paginação e filtros no servidor** para a prateleira do professor.

### Prioridade média

- **Rotas nomeadas.** A navegação a partir de notificações já traduz tipo e papel em rota manualmente. Com *deep links*, deixa de escalar.
- **Anexos no chat.** A infraestrutura de envio existe; faltam a subcoleção e a interface.
- **Perfil público separado do documento privado.** O Firestore não oferece regra por campo, de modo que um professor visualiza dados cadastrais completos de qualquer demandante.

### Prioridade baixa, valor alto

- **Observabilidade.** Crashlytics e *Performance Monitoring* exigem apenas ativação. As tolerâncias a falha espalhadas pelos repositórios ocultam problemas reais até que alguém os relate.
- **Integração contínua.** O fluxo automatizado foi removido; `analyze` e `test` passaram a depender de disciplina manual antes de cada distribuição.

### Revisões periódicas

Custo mensal do Firebase, com atenção às Rules que realizam leitura. Volume de código, cujo limiar para modularização em pacotes locais é da ordem de trinta mil linhas. Volume de mensagens por conversa, hoje limitado às duzentas mais recentes.

---

<div align="center">

**Documentação viva.**
Quem altera o código atualiza este documento — e traz o *porquê*, não apenas o *o quê*.

</div>
