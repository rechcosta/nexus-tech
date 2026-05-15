# Arquitetura — Nexus Tech

**O que existe, por que está assim, e o que vai mudar.** Documento vivo — pode ser desafiado, só traga argumento.

## Sumário

1. [Visão de 30 segundos](#1-visão-de-30-segundos)
2. [Princípios](#2-princípios)
3. [Camadas](#3-camadas)
4. [Modelo de domínio](#4-modelo-de-domínio)
5. [Persistência](#5-persistência)
6. [Segurança](#6-segurança-em-profundidade)
7. [Gerenciamento de estado](#7-gerenciamento-de-estado)
8. [Tratamento de erros](#8-tratamento-de-erros)
9. [Fluxos críticos](#9-fluxos-críticos)
10. [Decisões e trade-offs](#10-decisões-e-trade-offs)
11. [Pontos de evolução](#11-pontos-de-evolução)

---

## 1. Visão de 30 segundos

App Flutter com Firebase como backend completo. Sem servidor próprio. Lógica de negócio no cliente; segurança garantida por **Firestore Rules** e **Storage Rules**.

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cliente Flutter                         │
│                                                                 │
│   ┌──────────┐    ┌────────────┐    ┌──────────────────┐        │
│   │  Telas   │───▶│  Providers │───▶│   Repositórios   │        │
│   │  (UI)    │◀───│  (estado)  │◀───│  (Firebase API)  │        │
│   └──────────┘    └────────────┘    └────────┬─────────┘        │
└──────────────────────────────────────────────┼──────────────────┘
                                               │
                                               ▼
                          ┌────────────────────────────────────┐
                          │  Firebase (impõe regras)           │
                          │   Auth · Firestore · Storage       │
                          │   firestore.rules + storage.rules  │
                          └────────────────────────────────────┘
```

**Trade-off central:** Firebase eliminou meses de backend, mas toda decisão futura sobre escala, custo e lock-in depende dele. Não é reversível sem reescrever a camada de repositórios.

---

## 2. Princípios

Em conflito, vence o princípio mais alto da lista.

**2.1 Camadas com responsabilidade clara.** UI nunca toca Firebase. Provider nunca importa pacote Flutter fora do material. Repositório nunca decide regra de negócio. Provider importando `cloud_firestore` direto = cheiro de código.

**2.2 Segurança em profundidade.** Validador no Dart é UX. Firestore Rule é segurança. Storage Rule é segurança de novo. Cada uma sozinha está incompleta.

**2.3 Tempo real onde o usuário espera ver mudar.** `Stream<>` para listas e detalhes que mudam durante a sessão (minhas demandas, observar uma demanda, anexos). `Future<>` para o que não muda (áreas, contagens, dados de cadastro).

**2.4 Exceções tipadas.** Toda falha do Firebase atravessa `mapFirestoreError()` e vira `AppException`. UI nunca vê `FirebaseException` crua.

**2.5 Falhar honestamente.** Operação principal falha = aborta com mensagem clara. Operação secundária (audit log, contagem) falha = best-effort e segue.

---

## 3. Camadas

### 3.1 Apresentação (`features/*/screens` e `widgets`)

Widgets stateful/stateless. Consomem providers via `context.watch` e `context.read`. Zero dependência direta de Firebase ou repositórios.

Padrões consistentes:
- Formulários: `GlobalKey<FormState>` + `Form` + `TextFormField` com validators puros.
- Estados visuais: loading, vazio, erro e conteúdo são sempre explícitos.
- Listas: `ListView.separated` para uniformidade.

### 3.2 Estado (`*/providers`)

`ChangeNotifier` via `package:provider`. Um provider, uma responsabilidade.

| Provider | Escopo | Responsabilidade |
|---|---|---|
| `AuthProvider` | Global | Estado de autenticação, role, cadastro existente |
| `CadastroProvider` | Global | Form de cadastro inicial + gestão de áreas |
| `DemandasProvider` | Global | Listagem "Minhas Demandas" + filtros |
| `DemandaFormProvider` | Global | Form de criar/editar/cancelar + anexos pendentes |

Todos no `App` (não nas telas) para evitar `abrir tela → instancia → faz request → fecha tela → perde tudo`. Reset explícito via `form.resetar()` nos pontos certos.

**Por que não Riverpod/Bloc?** Escopo atual cabe em Provider; curva de aprendizado não se justifica. Reavaliar quando passar de 6 providers.

### 3.3 Dados (`core/repositories`)

Única camada que importa `cloud_firestore`, `firebase_storage`, `firebase_auth`. Tudo que sai daqui é objeto de domínio.

Padrão:

```dart
Future<X> minhaOperacao(...) async {
  try {
    final result = await _firestore.[...];
    return mapFromFirestore(result);
  } catch (e) {
    throw mapFirestoreError(e, recurso: 'NomeRecurso');
  }
}
```

### 3.4 Domínio (`core/models`)

Classes Dart puras. Sem dependência de Flutter (exceção: `StatusDemanda` usa `Color` e `IconData` para encapsular apresentação canônica e evitar duplicação).

Padrão: `fromMap(id, Map)`, `toMap()`, `copyWith()` quando aplicável.

---

## 4. Modelo de domínio

### 4.1 Usuários — herança sobre composição

```
       ┌──────────────────┐
       │  Usuario (abstr) │
       │  uid, email,     │
       │  nome, role,     │
       │  criadoEm        │
       └────────┬─────────┘
                │
   ┌────────────┼────────────┐
   ▼            ▼            ▼
 Demandante  Professor  Administrador
 telefone    siape      (apenas
 tipo        areas      campos
 cpfCnpj     ativo      da base)
 endereco
 strikes
```

Demandante exige CPF/CNPJ; professor exige SIAPE. Encapsular no construtor previne objetos meio-inválidos. `UsuarioRepository.buscarPorUid()` lê `role` e instancia a subclasse correta — se `role` está corrompido, retorna `null` (trata como "precisa cadastrar de novo").

### 4.2 Demanda — máquina de estados

```
                  ┌─────────────┐
       criar ───▶ │ cadastrada  │ ──── editar campos
                  └──┬───────┬──┘      [demandante]
                     │       │
   (sprint 3:    │       │  cancelar (UC16)
    professor    │       │  [demandante]
    assume)      │       │
                 ▼       ▼
          ┌───────────┐ ┌───────────┐
          │ emAnalise │ │ cancelada │
          └─────┬─────┘ └─────┬─────┘
                │             │
                ▼             ▼
          ┌────────────┐  republicar  ──▶  nova demanda
          │ emProducao │   (atômico:        status:cadastrada
          └─────┬──────┘    cria nova +
                │           marca original
                ▼           com republicadaComoId)
          ┌────────────┐
          │ concluida  │
          └────────────┘
```

A enum `StatusDemanda` carrega `label`, `icone` e `cor` — ponto único de verdade visual. Mudar cor de "em produção" é uma linha.

Transições válidas estão em getters: `status.podeEditarDemandante`, `status.podeCancelarDemandante`. UI consulta; sem `if (status == X || status == Y)` espalhado.

### 4.3 Anexo vs. AnexoPendente

Dois tipos com ciclos de vida diferentes:

- **`AnexoPendente`** — só em memória, no provider. Selecionado mas não enviado.
- **`Anexo`** — já vive no Storage + Firestore.

Separação evita órfãos: se usuário desiste do form, pendentes morrem com o provider; nada sobe à toa.

---

## 5. Persistência

### 5.1 Estrutura no Firestore

```
users/{uid}            ─ ID = uid do Auth
demandas/{id}          ─ ID gerado pelo Firestore
  anexos/{anexoId}     ─ subcoleção (1:N)
areas_tecnicas/{id}    ─ vocabulário compartilhado, dedup por chave
areas_interesse/{id}   ─ idem
audit_logs/{id}        ─ append-only, lido só por admin
```

**Por que anexos como subcoleção, não array embutido?** Documento Firestore tem limite de 1 MB. Array com base64 explode. Subcoleção permite queries pontuais, contagem barata via `count()`, regras independentes.

**Por que áreas em coleção compartilhada, não array no doc do professor?** Reuso entre professores, normalização (evita "Web" vs "web" vs "WEB"), query indexada para dedup. Ver `area_repository.dart#criarSeNaoExiste`.

### 5.2 Índices compostos

Em `firestore.indexes.json`:

```
demandas: (demandanteUid asc, criadoEm desc)
demandas: (demandanteUid asc, status asc, criadoEm desc)
demandas: (demandanteUid asc, status asc, criadoEm asc)
```

Necessários porque filtros são acumulativos (demandanteUid + status + período). Sem o índice, query falha em runtime.

### 5.3 Storage layout

```
demandas/{demandaId}/anexos/{timestamp}_{nomeOriginal}.{ext}
```

`customMetadata` carrega `enviadoPorUid` e `demandaId` — Rules autorizam delete sem consultar Firestore.

---

## 6. Segurança em profundidade

### 6.1 Camada 1 — Cliente (UX, não segurança)

`core/utils/validators.dart` e `input_formatters.dart`:

- **CPF/CNPJ:** módulo 11 oficial da Receita, rejeita sequências repetidas.
- **DDD:** whitelist dos 67 DDDs válidos da Anatel.
- **Celular vs fixo:** terceiro dígito após DDD.
- **Telefone:** máscara dinâmica entre 10 e 11 dígitos.

Para feedback rápido e evitar chamadas inúteis. **Não confie nisso para segurança.**

### 6.2 Camada 2 — Firestore Rules

Em `firestore.rules`. Caso não-óbvio (republicação atômica):

```
allow update: if isSignedIn() && (
  // editor regular (UC17)
  (isOwner(...) && resource.data.status == 'cadastrada') ||
  
  // republicar — só preenche republicadaComoId, só uma vez
  (
    isOwner(...) &&
    resource.data.status == 'cancelada' &&
    (!('republicadaComoId' in resource.data) ||
      resource.data.republicadaComoId == null) &&
    request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['republicadaComoId']) &&
    request.resource.data.republicadaComoId is string
  ) ||
  
  isProfessorEmail() || isAdminEmail()
);
```

Essa Rule sozinha impede que via API direta alguém crie 1.000 republicações da mesma demanda. UI esconde botão; Rule garante.

### 6.3 Camada 3 — Storage Rules

Em `storage.rules`:

- Tipos MIME explícitos (PDF, DOCX, JPG, PNG).
- Tamanho máximo de 10 MB.
- Delete só pelo uploader original (via `customMetadata.enviadoPorUid`).
- Anexos imutáveis (sem update).

### 6.4 Definição de admin

Admin é definido por **e-mail**, em duas listas que precisam estar sincronizadas:

- `AppConstants.adminEmails` (Dart)
- `firestore.rules#isAdminEmail()` (rule)

Comentários explícitos em ambos lados alertam dessa sincronização. Acoplamento conhecido — melhor seria custom claims do Firebase Auth, mas exige Cloud Function. Marcado como evolução futura.

---

## 7. Gerenciamento de estado

### 7.1 Padrão de provider

```dart
enum _Status { initial, loading, success, error }

class XProvider extends ChangeNotifier {
  _Status _status = _Status.initial;
  String? _erro;
  
  // getters expõem estado read-only
  // métodos públicos disparam operações async
  // notifyListeners() em cada transição
}
```

UI lê via `Consumer<>` ou `context.watch<>`. Operações disparam por `context.read<>()`. Sem `setState` para dados.

### 7.2 Streams e ciclo de vida

`DemandasProvider` mantém uma `StreamSubscription` viva enquanto o usuário está logado. Quando o filtro muda: cancela inscrição atual, cria nova com query atualizada. `dispose()` cancela na saída.

`AuthProvider` mantém `authStateChanges` ligado a vida toda do app — propositadamente.

### 7.3 Filtros e busca

`aplicarFiltros()` atualiza filtros e re-executa `observar()`, que cancela inscrição anterior e cria nova com query nova. Barato porque snapshot vem do cache quando possível.

Busca por título é **client-side** no getter `demandas` do provider. Funciona para o demandante (dezenas de demandas). Para a prateleira do professor (todas as demandas do sistema) vai precisar evoluir.

---

## 8. Tratamento de erros

### 8.1 Hierarquia

```
AppException (sealed)
 ├── NetworkException        "Sem conexão..."
 ├── PermissionException     "Você não tem permissão..."
 ├── NotFoundException       "Recurso não encontrado..."
 ├── ServerException         "Erro no servidor..."
 ├── ValidationException     <mensagem específica>
 └── AuthException           "Falha na autenticação..."
```

### 8.2 Conversão centralizada

`mapFirestoreError()` faz `switch` no `FirebaseException.code`:

| Código Firebase | Exceção |
|---|---|
| `permission-denied` | `PermissionException` |
| `not-found` | `NotFoundException(recurso)` |
| `unavailable`, `deadline-exceeded` | `NetworkException` |
| `unauthenticated` | `AuthException` |
| outro | `ServerException` |

Sem string-matching de mensagem em nenhum outro lugar.

### 8.3 Best-effort vs. abort

Best-effort (falha silenciosa, não bloqueia):
- Audit logs.
- `contarAnexos()` (retorna 0).
- Cleanup de upload órfão no Storage.

Operações principais **nunca** são best-effort. Falha = aborta = mostra erro.

---

## 9. Fluxos críticos

### 9.1 Login e roteamento

```
LoginScreen
   │ entrarComGoogle()
   ▼
AuthService.signInWithGoogle()
   │
   ▼ stream emite User
authStateChanges → AuthProvider._onAuthChanged()
   │
   ├── já existe no Firestore? ──── sim ──▶ status: autenticado
   │
   ├── e-mail é admin? ──── sim ──▶ cria Administrador automaticamente
   │
   └── e-mail é IFRS? ──── sim ──▶ status: autenticadoSemCadastro
                                       roteia CadastroProfessor
                            não ──▶ status: autenticadoSemCadastro
                                       roteia CadastroDemandante
```

`AppRouter` é um único `switch` sobre `auth.status`. Sem pacote de rotas, sem deep links — escolha consciente para um app de 7 telas.

### 9.2 Criar demanda com anexos

```
DemandaFormScreen → DemandaFormProvider.criar()
   │
   ├──▶ DemandaRepository.criar(demanda)
   │       └─▶ Firestore add() → ID
   │           └─▶ audit_logs add() (best-effort)
   │
   └──▶ para cada AnexoPendente:
           └─▶ AnexoRepository.upload()
                  ├─▶ Storage.putFile() com customMetadata
                  └─▶ Firestore add() em demandas/{id}/anexos
                     (demanda já existe; falha aqui não a destrói)
```

### 9.3 Cancelar + republicar — operação atômica

Fluxo com mais cuidado arquitetural do app:

```
demanda original (cancelada)              demanda nova
       │                                        │
       │  user clica "Republicar"               │
       ▼                                        │
DemandaFormProvider.criar(                      │
  originalCanceladaId: <id da cancelada>        │
)                                               │
       │                                        │
       ▼                                        │
DemandaRepository.criar(demanda, originalId)    │
       │                                        │
       ▼                                        │
       WriteBatch                               │
       ├──── batch.set(novaRef, dados) ────────▶│
       ├──── batch.update(originalRef, {        │
       │       republicadaComoId: novaRef.id    │
       │     })                                 │
       │                                        │
       ▼                                        │
       batch.commit() ── ATÔMICO ──▶ ambas ou nenhuma
```

Sem `WriteBatch`, haveria janela onde a nova demanda existe mas a original ainda mostra o botão "republicar" → duas republicações. Com batch, isso é impossível mesmo se a rede cair entre as escritas.

Defesa em três camadas:
- **UI:** botão escondido se `republicadaComoId != null`.
- **Provider/Repo:** WriteBatch atômico.
- **Rules:** `republicadaComoId` só pode ser preenchido uma vez.

### 9.4 Listagem em tempo real com filtros

```
DemandasProvider.observar(uid)
   │
   ▼
DemandaRepository.listarDoDemandante(uid, status?, periodo?)
   │
   ▼
Firestore Query encadeada:
   .where('demandanteUid', isEqualTo: uid)
   .where('status', isEqualTo: ...)     ← se filtro
   .where('criadoEm', '>=', ...)         ← se período
   .where('criadoEm', '<', ...)          ← se "após 30 dias"
   .orderBy('criadoEm', descending: true)
   │
   ▼
snapshots() → Stream<List<Demanda>>
   │
   ▼ provider escuta, notifyListeners()
   │
   ▼ ListView reconstrói só cards que mudaram
```

Busca por título aplicada **depois**, em memória (§7.3).

---

## 10. Decisões e trade-offs

### 10.1 Firebase como backend completo

| Ganho | Custo |
|---|---|
| Zero infra | Vendor lock-in |
| Real-time de graça | Limites de query do Firestore |
| Auth + Storage + DB integrados | Custo cresce com uso |
| Free tier confortável para acadêmico | Sem SQL, sem joins |

**Reavaliar quando:** custo passar de R$ 200/mês ou for preciso fazer queries que o Firestore não suporta.

### 10.2 Provider sobre Riverpod/Bloc

Provider tem menos features. Time atual conhece, escopo cabe. Migrar custaria 1–2 sprints sem entregar valor visível.

**Reavaliar quando:** passar de 10 providers ou compartilhar estado entre features virar dor recorrente.

### 10.3 Sem repositório abstrato

Repositórios são classes concretas dependentes do Firestore. Sem `IDemandaRepository` com implementação trocável.

**Por quê:** sem intenção real de trocar de banco; abstração custaria boilerplate sem benefício. **Custo aceito:** testes precisam de mock manual ou Firebase emulator.

**Reavaliar quando:** começar testes a sério.

### 10.4 Status como enum, não FSM formal

`StatusDemanda` é uma enum com 5 valores. Transições codificadas em Firestore Rules + getters da enum. Sem lib de FSM ou pattern Estado — seria over-engineering.

**Reavaliar quando:** 10+ estados ou transições condicionais complexas.

### 10.5 Soft-delete em demandas

Canceladas não são deletadas. Documento permanece com `status: cancelada` + `motivoCancelamento`.

**Por quê:** histórico é parte do produto (demandante quer ver canceladas em "Minhas Demandas"), auditoria precisa do dado, republicação aponta para a original.

**Hard delete:** só admin, e ainda não na UI.

### 10.6 Form unificado criar/editar

`DemandaFormScreen` com enum `DemandaFormModo { criar, editar }`. Uma tela em vez de duas quase idênticas.

**Custo aceito:** asserts no construtor garantem combinações válidas. Se surgir um terceiro modo, refatora.

### 10.7 Áreas em coleção compartilhada com dedup

`areas_tecnicas` e `areas_interesse` como coleções, cada doc com `chave` (lowercase + trim) para dedup via query indexada.

**Por quê:** reuso entre professores, normalização sem duplicatas ("Web" vs "web" vs "WEB"), e prepara filtro de demandas por área no Sprint 3.

---

## 11. Pontos de evolução

### Alta urgência (Sprint 3)

- **Prateleira do professor.** Paginação real (`limit + startAfter`), filtros server-side por área, e provavelmente busca textual via Algolia/Typesense ou indexação manual.
- **Transições de status.** Novas Rules e provavelmente Cloud Functions para validar prazos (UC09 fala em 24h para análise).
- **Testes.** Validadores (CPF/CNPJ/DDD) e republicação atômica no mínimo.

### Média urgência (Sprint 4)

- **Push notifications** via FCM.
- **Chat.** Firestore-as-chat (simples mas caro) vs. Realtime Database (mais barato).
- **Sistema de strikes.** Cloud Function para incremento atômico.

### Baixa urgência, alto valor

- **Antivírus real** via Cloud Function pós-upload integrando VirusTotal/ClamAV. UC20 R03 pede; cumprimos parcialmente.
- **Custom claims para admin** em vez de lista enumerada. Cloud Function lê lista do Firestore, atribui claim — adicionar admin sem redeploy.
- **CI/CD com GitHub Actions.** Build automático, deploy de Rules, testes em PR.
- **Observabilidade.** Crashlytics + Performance Monitoring (só ligar no Firebase) + retenção de audit logs.

### Reavaliações periódicas

- **Custo Firebase** mensal em produção.
- **Tamanho do código.** Acima de 30k linhas, considerar quebrar em packages locais (`packages/core`, `packages/features_demanda`).
- **Provider count.** Acima de 8 providers globais, pensar em Riverpod ou injeção formal.

---

<div align="center">

**Documentação viva.** Quem editar o código, atualize aqui. Trazer o "porquê", não só o "o quê".

</div>