<div align="center">

# Plano gratuito e plano pago

**Nexus Tech** · IFRS Campus Osório

*O que já funciona, o que depende do plano pago, e onde cada peça se encaixa.*

**Português** · [English](CLOUD_FUNCTIONS.en.md)

</div>

---

## Princípio adotado

Nada foi deixado pela metade à espera do plano pago. **Cada funcionalidade tem
uma versão que opera hoje no plano gratuito**, e a parcela que depende do plano
pago está isolada em um ponto de extensão explícito — em geral um campo já
gravado que ainda não é consumido.

Quando o plano pago for habilitado, o trabalho consiste em escrever as funções
catalogadas aqui. Não há refatoração de aplicação, alteração de modelo de dados
nem migração pendente.

---

## 1. Por que Cloud Functions exige plano pago

Cloud Functions se apoia em Cloud Build, Artifact Registry e Cloud Run —
serviços do Google Cloud indisponíveis no plano gratuito, ainda que o consumo
permaneça dentro da cota. O bloqueio decorre do **serviço**, não do volume.

O que **não** exige plano pago, e por isso foi empregado sem restrição:

| Recurso | Observação |
|---|---|
| Firestore — leitura, escrita e *streams* | 50 mil leituras e 20 mil escritas diárias |
| Firestore Rules, inclusive `get()` entre documentos | Cada `get()` conta como leitura |
| Transações e `WriteBatch` | Base da atomicidade do sistema |
| Consultas de agregação (`count()`) | Empregadas em métricas e anexos |
| Authentication com Google | — |
| Crashlytics e Performance Monitoring | Requerem apenas ativação |
| **FCM** | A biblioteca é gratuita; falta **quem** dispara — §3.1 |

**Cloud Storage** passou a exigir plano pago em projetos novos: o
provisionamento do balde padrão demanda conta de faturamento. Projetos
anteriores mantêm o balde existente.

---

## 2. O que já opera integralmente

Estas funcionalidades estão **completas**. Nada nelas muda quando o plano pago
for habilitado.

### 2.1 Conversa entre demandante e professor

Criada na mesma transação que move a demanda para produção. Mensagens,
contadores de não lidas e encerramento ao concluir ou cancelar — tudo em tempo
real sobre o Firestore.

`ChatRepository` · `chats/{demandaId}` · `chats/{demandaId}/mensagens`

### 2.2 Central de notificações in-app

Avisos com contador, marcação de leitura e navegação para o destino do evento.
Cobre todo o ciclo: análise, aceite, devolução, conclusão, cancelamento,
mensagem nova, denúncia recebida e julgada, advertência, suspensão, desativação
e reativação de perfil.

`NotificacaoRepository` · `notificacoes/{id}`

> O que depende do plano pago aqui é **apenas o *push*** — o aviso com a
> aplicação fechada. O aviso interno está pronto. Ver §3.1.

### 2.3 Denúncias, advertências e suspensão

O professor denuncia; o administrador julga; a denúncia procedente incrementa
as advertências **na mesma transação**; ao atingir o limite, a conta é suspensa.
As Rules recusam a criação de demandas por conta suspensa, de modo que a
suspensão vale inclusive fora da aplicação.

`DenunciaRepository.julgar` · `denuncias/{id}` · `firestore.rules`

### 2.4 Painel administrativo

Visão geral do sistema, fila de denúncias, gestão do corpo docente com métricas
individuais, e gestão de demandantes com advertências e suspensão. Tudo em
tempo real.

`AdminRepository` · `features/admin/`

### 2.5 Ativação e desativação de docentes

O administrador desliga o perfil; o professor é notificado, o roteamento o
conduz à tela de bloqueio **na sessão já aberta**, e as Rules recusam
transições de demanda vindas de perfil inativo.

---

## 3. Catálogo do que depende do plano pago

### 3.1 Notificação por *push* — prioridade alta

**O que falta.** O envio exige servidor de confiança. O cliente não pode
disparar avisos para terceiros sem expor a chave do servidor.

**O que existe.** Central in-app completa. O usuário vê tudo ao abrir a
aplicação; o que não ocorre é o aviso com ela fechada.

**Gancho pronto.** Todo documento em `notificacoes` nasce com
`enviada: false`. A função observa a coleção e inverte a marca.

```js
exports.despacharPush = onDocumentCreated('notificacoes/{id}', async (event) => {
  const n = event.data.data();
  if (n.enviada) return;

  const tokens = await tokensDe(n.destinatarioUid);
  if (tokens.length) {
    await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: n.titulo, body: n.corpo },
      data: { tipo: n.tipo, demandaId: n.demandaId ?? '', chatId: n.chatId ?? '' },
    });
  }
  await event.data.ref.update({ enviada: true });
});
```

**Alteração na aplicação.** Adicionar `firebase_messaging`, solicitar permissão
e gravar o *token* do dispositivo em `users/{uid}.fcmTokens`. É a única
alteração de modelo de dados pendente em todo o catálogo, e é aditiva.

### 3.2 Devolução automática em 24 horas

**O que falta.** Tarefa agendada que devolva à prateleira **todas** as demandas
cuja análise expirou, independentemente de alguém abrir a aplicação.

**O que existe.** Reconciliação no cliente: as demandas expiradas do próprio
professor são devolvidas quando ele abre a lista. Cobre o caso comum, mas não o
professor ausente — a demanda permanece retida até que ele retorne.

```js
exports.expirarAnalises = onSchedule('every 60 minutes', async () => {
  const agora = new Date().toISOString();
  const vencidas = await db.collection('demandas')
    .where('status', '==', 'emAnalise')
    .where('analiseExpiraEm', '<', agora)
    .get();

  const lote = db.batch();
  vencidas.forEach((doc) => lote.update(doc.ref, {
    status: 'cadastrada',
    professorUid: null, professorNome: null,
    analiseIniciadaEm: null, analiseExpiraEm: null,
    atualizadoEm: agora,
  }));
  await lote.commit();
});
```

Exige o índice `demandas (status, analiseExpiraEm)`.

### 3.3 *Custom claims* de papel

**O que falta.** Hoje "quem é administrador" é decidido por lista de endereços
**duplicada** entre o Dart e as Rules. Incluir alguém exige editar ambos e
republicar a aplicação.

**Solução.** Função que lê a lista de uma coleção de configuração e atribui
`role` como *claim*. As Rules passam a consultar `request.auth.token.role`, e
incluir um administrador torna-se uma escrita no Firestore.

### 3.4 Antivírus em anexos

**O que existe.** As Storage Rules restringem tipo MIME e tamanho, o que barra
o acidental mas não um documento malicioso.

**Solução.** Gatilho `onObjectFinalized` que submete o arquivo a verificação de
conteúdo, remove o objeto e o registro em caso de detecção, e notifica quem
enviou.

### 3.5 Contadores desnormalizados de métricas

**O que existe.** As métricas são agregadas no cliente a partir das demandas do
professor consultado — uma consulta por docente aberto, não uma varredura
global.

**Quando migrar.** Acima de algumas centenas de demandas por docente. Uma função
`onDocumentWritten('demandas/{id}')` manteria `users/{uid}.metricas` atualizado,
e o painel passaria a ler um único documento.

### 3.6 Moderação de conversas

As Rules definem `allow update, delete: if false` na subcoleção de mensagens —
histórico imutável, por desenho. Remover mensagem abusiva mediante denúncia
exige o SDK administrativo, que ignora as Rules.

### 3.7 Limpeza de arquivos órfãos

A exclusão definitiva de uma demanda deixa os anexos no armazenamento. Um
gatilho `onDocumentDeleted` removeria o prefixo correspondente. A exclusão
definitiva não está exposta na interface, de modo que o problema ainda não se
materializa.

### 3.8 Retenção de dados

`audit_logs` e `notificacoes` crescem indefinidamente. Uma tarefa agendada
removeria notificações lidas com mais de noventa dias e arquivaria registros
antigos. O crescimento é linear e modesto, mas trata-se de dívida real.

### 3.9 Correio eletrônico transacional

A extensão oficial *Trigger Email* consome uma coleção e despacha por SMTP.
Extensões exigem plano pago. A coleção `notificacoes` serve de gatilho.

### 3.10 Preenchimento retroativo de conversas

**Não depende do plano pago**, mas consta aqui por ser a única migração
pendente.

Demandas que já estavam em produção **antes** da introdução do chat não possuem
documento em `chats/`. A aplicação trata o caso sem falhar — a tela explica que
demandas aceitas em versões anteriores não têm conversa — mas essas duplas ficam
sem canal.

Em volume pequeno, devolver e reassumir a demanda resolve. Em volume maior, um
script pontual com o SDK administrativo, executável de qualquer máquina sem
plano pago, percorre as demandas em produção e cria a conversa correspondente,
seguida de uma mensagem de sistema — sem ela a conversa não aparece na lista.

---

## 4. Ganchos existentes no código

| Gancho | Onde | Serve a |
|---|---|---|
| `notificacoes.enviada` | `NotificacaoRepository.enfileirar` | §3.1, §3.9 |
| `demandas.analiseExpiraEm` | `DemandaRepository.marcarParaAnalise` | §3.2 |
| `Demanda.analiseExpirou` | `core/models/demanda.dart` | §3.2 — mesma regra dos dois lados |
| `audit_logs` (somente adição) | todos os repositórios | §3.8, auditoria |
| `denuncias.strikeAplicado` | `DenunciaRepository.julgar` | rastro de moderação |
| `AppConstants.adminEmails` | `core/constants/` | §3.3 |
| `chats.ativo` | `ChatRepository.encerrar` | §3.6 |

---

## 5. Ordem sugerida de implementação

Da maior lacuna resolvida por unidade de esforço:

1. **§3.2 — devolução automática.** Única lacuna com efeito funcional visível
   hoje. Função pequena.
2. **§3.1 — *push*.** A aplicação já exibe tudo internamente; o *push* altera o
   tempo de resposta do sistema.
3. **§3.3 — *custom claims*.** Elimina o acoplamento que hoje exige republicar
   a aplicação para incluir um administrador.
4. **§3.4 — antivírus.** Fecha o requisito de segurança de anexos.
5. **§3.8 — retenção.** Antes que os volumes incomodem.
6. **§3.5, §3.6, §3.7** — conforme o uso justificar.

---

## 6. Estimativa de custo

O plano pago cobra pelo uso **acima** da cota gratuita, que permanece válida.
Para o perfil deste projeto — um campus, dezenas de usuários ativos:

| Item | Cota gratuita mensal | Uso estimado |
|---|---|---|
| Invocações de função | 2 milhões | milhares |
| GB-segundo de computação | 400 mil | centenas |
| Cloud Build | 120 min por dia | poucos minutos por publicação |
| Firestore | 50 mil leituras por dia | bem abaixo |

**Conclusão.** O custo mensal esperado aproxima-se de zero; o plano pago é
exigido pela **existência** do serviço, não pelo consumo. Ainda assim, configure
um **orçamento com alerta** antes de migrar — um laço acidental em uma função é
a forma clássica de gerar uma fatura inesperada.

---

<div align="center">

**Documentação viva.**
Ao implementar um item, mova-o da seção 3 para a seção 2 e atualize o gancho
correspondente na seção 4.

</div>
