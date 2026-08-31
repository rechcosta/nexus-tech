<div align="center">

# Architecture

**Nexus Tech** · IFRS Campus Osório

*What exists, why it is this way, and what changes next.*

[Português](ARCHITECTURE.md) · **English**

</div>

> Code identifiers appear in Portuguese throughout, as they are the actual
> names in the source. A short glossary closes this document.

---

## Contents

**[1. Overview](#1-overview)** · **[2. Principles](#2-principles)** · **[3. Layers](#3-layers)** · **[4. Domain](#4-domain-model)** · **[5. Persistence](#5-persistence)** · **[6. Security](#6-security)** · **[7. State](#7-state-management)** · **[8. Errors](#8-error-handling)** · **[9. Critical flows](#9-critical-flows)** · **[10. Decisions](#10-decisions-and-trade-offs)** · **[11. Evolution](#11-evolution)**

---

## 1. Overview

A Flutter application using Firebase as a backend-as-a-service. There is no
custom server: business logic lives in the client, and security is enforced by
**Firestore Rules** and **Storage Rules**.

```
┌──────────────────────────────────────────────────────────┐
│                     Flutter client                       │
│                                                          │
│   ┌────────┐      ┌───────────┐      ┌──────────────┐    │
│   │ Screens│ ───▶ │ Providers │ ───▶ │ Repositories │    │
│   │  (UI)  │ ◀─── │  (state)  │ ◀─── │  (Firebase)  │    │
│   └────────┘      └───────────┘      └──────┬───────┘    │
└─────────────────────────────────────────────┼────────────┘
                                              ▼
                        ┌──────────────────────────────────┐
                        │  Firebase — enforces the rules   │
                        │  Auth · Firestore · Storage      │
                        │  firestore.rules · storage.rules │
                        └──────────────────────────────────┘
```

**Central trade-off.** Firebase removed months of backend work, but every
future decision about scale, cost and vendor dependency runs through it.
Reversing it means rewriting the repository layer — and only that layer, which
is precisely the point of the isolation described in section 3.

---

## 2. Principles

Where principles conflict, the lower-numbered one prevails.

**2.1 · Single responsibility per layer.** The UI never reaches Firebase.
Providers never import Flutter packages beyond `material`. Repositories never
decide business rules.

**2.2 · Defence in depth.** A Dart validator is user experience. A Firestore
Rule is security. A Storage Rule is security again. Any single layer is
insufficient on its own.

**2.3 · Real time where the user expects to see change.** `Stream` for what
changes during a session; `Future` for what does not.

**2.4 · Typed exceptions.** Every Firebase failure passes through
`mapFirestoreError()` and becomes an `AppException`. The UI never receives a
raw `FirebaseException`.

**2.5 · Fail honestly.** A failure in a primary operation aborts with a clear
message. A failure in a secondary operation — audit logging, counting — is
tolerated and the flow continues.

---

## 3. Layers

### 3.1 Presentation — `features/*/screens` and `widgets`

Widgets consume providers through `context.watch` and `context.read`, with no
direct dependency on Firebase or repositories.

Uniform patterns: forms built on `GlobalKey<FormState>` with pure validators;
loading, empty, error and content states always made explicit; lists rendered
with `ListView.separated`.

### 3.2 State — `features/*/providers`

`ChangeNotifier` over `package:provider`. Ten global providers, registered in
`App` rather than in screens — otherwise opening and closing a screen would
discard in-flight requests.

| Provider | Responsibility |
|---|---|
| `AuthProvider` | Authentication and profile, **observed in real time** |
| `CadastroProvider` | Initial registration and area management |
| `DemandasProvider` | Requester listing and filters |
| `DemandaFormProvider` | Creation, editing and pending attachments |
| `ProfessorDemandasProvider` | Public shelf and the professor's own demands |
| `AcaoDemandaProvider` | Ephemeral state of status transitions |
| `PerfilProvider` | Profile and photograph editing |
| `NotificacoesProvider` | Notification centre and bell counter |
| `ChatsProvider` | Conversation list and unread messages |
| `AdminProvider` | Reports, faculty and requesters |

**Criterion for promoting to global.** The last three feed **visual counters**
that must be correct on any tab. Instantiating them per screen would reset the
count on every navigation.

**What stays local.** The open conversation and the detail screens consume
repository streams directly through `StreamBuilder`. Their state is born and
dies with the screen.

### 3.3 Data — `core/repositories`

The only layer that imports `cloud_firestore`, `firebase_storage` and
`firebase_auth`. Everything leaving it is a domain object.

```dart
Future<X> operation(...) async {
  try {
    final result = await _firestore. …;
    return mapFromFirestore(result);
  } catch (e) {
    throw mapFirestoreError(e, recurso: 'ResourceName');
  }
}
```

### 3.4 Domain — `core/models`

Pure Dart classes, with one deliberate exception: the state enums
(`StatusDemanda`, `StatusDenuncia`, `TipoNotificacao`) carry `label`, `icone`
and `cor`. Encapsulating the canonical presentation in the domain prevents the
same visual decision from being rewritten on every screen.

Uniform pattern: `fromMap(id, Map)`, `toMap()` and `copyWith()` where
applicable. All deserialisation is defensive — documents written by earlier
versions must never break reading.

---

## 4. Domain model

### 4.1 Users

```
              ┌───────────────────┐
              │ Usuario (abstract)│
              │ uid · email       │
              │ nome · role       │
              │ criadoEm · fotoUrl│
              └─────────┬─────────┘
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   Demandante       Professor      Administrador
   (requester)      (faculty)      (base fields)
   telefone         siape
   tipo             areasTecnicas
   cpfCnpj          areasInteresse
   endereco         ativo
   strikes          desativadoEm
   banido           motivoDesativacao
   banidoEm
   motivoBanimento
```

Requesters require a national tax number; professors require a SIAPE registry
number. Enforcing this in the constructor prevents partially valid objects.
`UsuarioRepository` reads the `role` field and instantiates the matching
subclass; a missing or corrupted `role` returns `null`, treated as
"registration required".

**Moderation state lives on the user.** `banido` (banned) and `ativo` (active)
are profile properties so that Firestore Rules can consult them with a single
read of a document they would already need. A separate suspensions collection
would demand an extra read on every protected write.

**Banning is a derived rule.**
`banido == (strikes >= AppConstants.strikesParaBanimento)`. There is no
independent switch — neither in report adjudication nor in the administrator's
manual adjustment. A separate switch would permit the incoherent state of a
suspended account holding a single warning.

### 4.2 Demand — state machine

```
                    ┌─────────────┐
       publish ───▶ │ cadastrada  │ ───── edit
                    └──┬───────┬──┘       [requester]
       [professor]     │       │     cancel [requester]
        reserve        ▼       ▼
              ┌─────────────┐ ┌───────────┐
              │  emAnalise  │ │ cancelada │
              └──┬───────┬──┘ └─────┬─────┘
     return      │       │   accept │
     or expire   │       ▼          ▼
     (24 h) ─────┘  ┌────────────┐  republish ──▶ new demand
                    │ emProducao │                (cadastrada)
                    └─────┬──────┘
                          ▼  complete
                    ┌────────────┐
                    │ concluida  │
                    └────────────┘
```

Valid transitions are declared in a single map, `StatusDemanda._transicoes` —
the single source of truth consulted by repository transactions. Derived
getters (`podeAssumir`, `podeConcluir`, `visivelNaPrateleira`) prevent status
conditionals from spreading through the UI.

Terminal states have no exit: republishing a cancelled demand **creates a new
demand**, rather than transitioning the original.

### 4.3 Communication and moderation

| Entity | Identifier | Note |
|---|---|---|
| `Chat` | equal to `demandaId` | One chat per demand, no more and no fewer |
| `Mensagem` | generated | Subcollection of `Chat`; immutable history |
| `Notificacao` | generated | Type determines icon, colour and navigation target |
| `Denuncia` | `{demandaId}__{professorUid}` | Each professor reports a demand once |

**Deterministic identifiers by design.** Using `demandaId` as the chat
identifier makes creation idempotent: a network retry, or re-acceptance after
a return to the shelf, rewrites the same document instead of creating parallel
conversations. The same reasoning applies to reports, where uniqueness also
turns "have I already reported this?" into a point read, with no query and no
index.

**Deliberate denormalisation.** `Chat.participantes` duplicates both
identifiers into an array because Firestore cannot disjoin across distinct
fields in a single query. `Chat.naoLidas` keeps unread counters on the chat
document, written in the same transaction as the message, so that the
conversation list never has to traverse the subcollection.

---

## 5. Persistence

### 5.1 Collections

```
users/{uid}              identifier = Auth uid
demandas/{id}
  anexos/{anexoId}       subcollection
chats/{demandaId}        identifier = demandaId
  mensagens/{msgId}      subcollection, immutable
notificacoes/{id}        in-app notices
denuncias/{id}           deterministic identifier
areas_tecnicas/{id}      shared vocabulary
areas_interesse/{id}
audit_logs/{id}          append-only; readable by administrators alone
```

**Subcollections rather than embedded arrays.** A Firestore document is capped
at 1 MB. Attachments and messages grow without a predictable ceiling; embedded,
overflow is a matter of time. Subcollections also allow paginating the most
recent entries and applying independent rules.

**Notifications in a root collection.** This simplifies the read rule and lets
a future Cloud Function observe a single collection rather than a collection
group.

### 5.2 Composite indexes

| Collection | Fields |
|---|---|
| `demandas` | `demandanteUid` · `criadoEm` ▾ |
| `demandas` | `demandanteUid` · `status` · `criadoEm` ▾ ▴ |
| `demandas` | `status` · `criadoEm` ▾ |
| `demandas` | `professorUid` · `criadoEm` ▾ |
| `demandas` | `professorUid` · `status` · `criadoEm` ▾ |
| `notificacoes` | `destinatarioUid` · `criadoEm` ▾ |
| `notificacoes` | `destinatarioUid` · `lida` |
| `chats` | `participantes` (array) · `ultimaMensagemEm` ▾ |
| `denuncias` | `status` · `criadoEm` ▾ |
| `denuncias` | `professorUid` · `criadoEm` ▾ |
| `denuncias` | `demandanteUid` · `criadoEm` ▾ |
| `audit_logs` | `autorUid` · `acao` |

Declared in `firestore.indexes.json`. Without the index, the query fails at
runtime — never at compile time.

> **The `orderBy` pitfall.** Firestore omits documents that lack the ordered
> field. The conversation list orders by `ultimaMensagemEm`; a freshly created
> chat, which does not yet have that field, would simply not appear. This is
> why chat creation is always followed by a system message — it is what gives
> the field its first value.

### 5.3 Storage

```
demandas/{demandaId}/anexos/{timestamp}_{name}.{ext}
users/{uid}/{file}
```

`customMetadata` carries `enviadoPorUid`, allowing Storage Rules to authorise
deletion without consulting Firestore.

---

## 6. Security

### 6.1 Layer 1 — client

`core/utils/validators.dart` implements the official modulo-11 check for
Brazilian tax numbers, rejects repeated sequences, validates national area
codes and distinguishes landline from mobile. It serves user experience and
avoids pointless requests. **It is not security.**

### 6.2 Layer 2 — Firestore Rules

Three mechanisms carry the rules.

**Minimal write surface.** Each writer profile declares exactly which fields it
may change, through `diff(resource.data).affectedKeys().hasOnly([...])`. This
is an allow-list, not a deny-list: a new field is denied by default and is only
opened by a conscious decision.

**Account state as a condition.**

```
function contaSuspensa() {
  return meuPerfil().get('banido', false) == true;
}
function professorAtivo() {
  return meuPerfil().get('ativo', true) == true;
}
```

Creating a demand requires `!contaSuspensa()` — this is what gives a ban its
practical effect. Professor transitions require `professorAtivo()`. The
`get(field, default)` form covers documents predating these fields, preserving
historical behaviour.

**Accepted cost.** Each such call is a billed read. They therefore appear only
on **writes**, never in read rules, which carry the highest volume.

**Irreversible operations restricted.** `republicadaComoId` may be set only
once; messages and attachments accept neither update nor deletion; report
adjudication belongs to administrators alone.

### 6.3 Layer 3 — Storage Rules

Explicit MIME types (PDF, DOCX, JPEG, PNG), a 10 MB ceiling for attachments and
5 MB for photographs, deletion restricted to the original uploader, and no
update — attachments are immutable.

### 6.4 Role identification

The administrator role and the professor exception are determined by address
lists maintained **in duplicate**, in Dart and in the Rules. Comments in both
files warn about the required synchronisation.

The coupling is known and provisionally accepted. The proper solution — custom
claims assigned by a Cloud Function — is recorded in
[CLOUD_FUNCTIONS.md](CLOUD_FUNCTIONS.en.md).

---

## 7. State management

### 7.1 Pattern

```dart
class XProvider extends ChangeNotifier {
  // private state fields
  // getters expose reads
  // public methods trigger operations
  // notifyListeners() on every transition
}
```

### 7.2 Streams and lifecycle

Listing providers keep a `StreamSubscription` alive for the duration of the
session. Changing a filter cancels the current subscription and creates another
with the updated query; `dispose()` cancels on exit.

The user profile is observed throughout the session. **This is why
administrative decisions take effect immediately**: with a point read, the user
would keep operating under the previous profile until reopening the app —
precisely the interval in which a suspension ought to apply.

### 7.3 Text search

Applied in memory over the already-loaded list. Adequate at the scale of a
single campus. The professor's shelf — which aggregates every demand in the
system — is the first point that will require server-side search.

---

## 8. Error handling

```
AppException (sealed)
├── NetworkException          connectivity failure
├── PermissionException       denied by the Rules
├── NotFoundException         document does not exist
├── ServerException           generic server failure
├── ValidationException       invalid client data
├── ConflictException         the resource changed between read and write
├── ContaBloqueadaException   account suspended or profile deactivated
└── AuthException             authentication failure
```

`mapFirestoreError()` converts by code, with no message string matching
anywhere else in the system.

`ConflictException` signals genuine concurrency: two professors on the same
demand, two administrators on the same report. `ContaBloqueadaException` exists
separately from `PermissionException` because the messages differ — one reports
a lack of permission, the other reports account suspension and states what to
do about it.

**Selective tolerance.** Audit records, counts and notification enqueuing fail
silently. Primary operations never do.

---

## 9. Critical flows

### 9.1 Authentication and routing

```
LoginScreen → AuthService.signInWithGoogle()
                      │
                      ▼  authStateChanges emits User
              AuthProvider subscribes to users/{uid}
                      │
     ┌────────────────┼────────────────┐
     ▼                ▼                ▼
  existing        administrator     no registration
  registration    (auto-created)    → screen chosen by
     │                │                the address
     └────────┬───────┘
              ▼
      account blocked? ── yes ──▶ ContaBloqueadaScreen
              │ no
              ▼
      screen for the role
```

`AppRouter` evaluates blocks **before** the role: a suspended account has no
workspace, it has an explanation.

### 9.2 Republication — atomic operation

Cancelling and republishing creates the new demand and marks the original with
`republicadaComoId` in a single `WriteBatch`. Without atomicity there would be
an interval in which the new demand already exists while the original still
offers the republish button, permitting duplicates.

Three layers of defence: the UI hides the button; the repository uses an atomic
batch; the Rule prevents a second write to the field.

### 9.3 Acceptance — status and conversation channel

```
DemandaRepository.assumir()
   │
   ▼  runTransaction
   ├── read the demand — validate status and ownership
   ├── update to emProducao
   └── create chats/{demandaId}
   │
   ▼  atomic commit
   ├──▶ audit record          (failure tolerated)
   ├──▶ system chat message   (tolerated, yet required — §5.2)
   └──▶ requester notification(failure tolerated)
```

**Why atomic.** Otherwise the state "demand in production with no conversation
channel" would exist — visible to the user and impossible for them to resolve.

**Why the welcome message sits outside the transaction.** Writing to a
subcollection of a document the transaction is itself creating would depend on
a read that does not yet exist.

### 9.4 Report, warning and suspension

```
professor reports ──▶ administrator queue ──▶ adjudication
                                                   │
                                       upheld ─────┤
                                                   ▼
                            runTransaction
                            ├── read the report — refuse if already judged
                            ├── read the user   — before any write
                            ├── strikes + 1 · banned = (strikes >= 3)
                            └── status, opinion and responsible party
                                                   │
                                      commit ──────┤
                                                   ▼
                                     audit · notify both parties
```

Refusing an already-judged report resolves concurrency between administrators.
Atomicity prevents both "upheld report without a warning" and a duplicated
warning from repeated activation.

### 9.5 Chat message

The transaction reads the chat, validates participation and state, writes the
message and updates the preview and the unread counter. The counter is
**computed**, not incremented by a server operator: the document has already
been read within the transaction, and an explicit value lets the Rule validate
the result.

The notification is created **only when the recipient had no unread messages**
in that conversation. In an active exchange, notifying on every message would
saturate the centre; notifying on the first of a burst conveys the same signal.
The visual counter, always updated, covers the rest.

---

## 10. Decisions and trade-offs

| Decision | Rationale | Revisit when |
|---|---|---|
| **Firebase as the whole backend** | Removes infrastructure; native real time; free tier sufficient | Monthly cost becomes material, or queries Firestore cannot serve |
| **Provider over Riverpod or BLoC** | Scope fits; team knows it; migration would cost sprints with no visible value | A first dependency between providers appears |
| **No abstract repository** | No real intention of switching databases; abstraction would be cost without benefit | Automated repository testing begins |
| **Enum over a formal state machine** | Five states and simple transitions; a library would be excess | Ten or more states, or conditional transitions |
| **Soft deletion of demands** | History is part of the product; auditing requires the record | — |
| **Chat in Firestore, not Realtime Database** | Atomicity across collections; a single rules language; modest real volume | Chat becomes a continuous-use channel |
| **Metrics computed client-side** | One query per professor consulted is cheaper than consistent counters | Hundreds of demands per faculty member |
| **Conditional chat notification** | Notifying on every message would saturate the centre | — |

**On the number of providers.** Moving from six to ten crossed the threshold
recorded as a revisit trigger. Staying with Provider was a conscious decision:
none of the new providers shares state with the others, and coupling between
them is nil. The first mutual dependency makes migration mandatory.

---

## 11. Evolution

### Dependent on the Firebase plan

The free tier provisions neither Cloud Functions nor Cloud Storage on new
projects. The adopted principle was **to leave no feature half-built**: each
one has a version that works today, with the paid-plan portion isolated behind
an explicit extension point.

| Item | Current state | Outstanding |
|---|---|---|
| Push notification | In-app centre complete | Function observing `notificacoes` |
| Automatic 24 h return | Client-side reconciliation | Scheduled task |
| Role custom claims | Lists duplicated in Dart and Rules | Function assigning the claim |
| Attachment antivirus | Rules limit type and size | Content inspection |
| Data retention | Continuous growth | Scheduled purge |

Full catalogue, with the existing hook for each item:
[**CLOUD_FUNCTIONS.md**](CLOUD_FUNCTIONS.en.md).

### High priority

- **Firestore Rules tests with the Firebase Emulator.** The rules concentrate
  the system's security and carry no automated coverage. This is the layer in
  which a mistake is simultaneously silent and severe.
- **Integration tests for the three critical transactions** — republication,
  acceptance with chat creation, and adjudication with a warning.
- **Server-side pagination and filtering** for the professor's shelf.

### Medium priority

- **Named routes.** Navigation from notifications already translates type and
  role into a route by hand. With deep links, it stops scaling.
- **Chat attachments.** The upload infrastructure exists; the subcollection and
  the interface do not.
- **Public profile separated from the private document.** Firestore offers no
  per-field rule, so a professor sees the full registration data of any
  requester.

### Low priority, high value

- **Observability.** Crashlytics and Performance Monitoring require only
  activation. The failure tolerances spread across repositories conceal real
  problems until someone reports them.
- **Continuous integration.** The automated pipeline was removed; `analyze` and
  `test` now depend on manual discipline before each distribution.

### Periodic review

Monthly Firebase cost, with attention to Rules that perform reads. Code volume,
whose threshold for modularisation into local packages is on the order of
thirty thousand lines. Message volume per conversation, currently capped at the
two hundred most recent.

---

## Glossary

| Portuguese | English |
|---|---|
| `demanda` | demand — a request published by an organisation |
| `demandante` | requester — the organisation or person publishing |
| `professor` | professor — faculty member who takes on demands |
| `prateleira` | shelf — the public listing of available demands |
| `denúncia` | report — a professor flagging an irregular demand |
| `strike` | warning; three suspend the account |
| `anexo` | attachment |
| `cadastrada · emAnalise · emProducao · concluida · cancelada` | registered · under review · in production · completed · cancelled |

---

<div align="center">

**Living documentation.**
Whoever changes the code updates this document — and brings the *why*, not just
the *what*.

</div>
