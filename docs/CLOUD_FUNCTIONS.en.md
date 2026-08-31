<div align="center">

# Free tier and paid plan

**Nexus Tech** · IFRS Campus Osório

*What already works, what depends on the paid plan, and where each piece fits.*

[Português](CLOUD_FUNCTIONS.md) · **English**

</div>

---

## Governing principle

Nothing was left half-built awaiting the paid plan. **Every feature has a
version that operates today on the free tier**, and the portion depending on
the paid plan is isolated behind an explicit extension point — usually a field
already written but not yet consumed.

Once the paid plan is enabled, the work consists of writing the functions
catalogued here. There is no application refactoring, no data-model change and
no pending migration.

---

## 1. Why Cloud Functions requires the paid plan

Cloud Functions rests on Cloud Build, Artifact Registry and Cloud Run — Google
Cloud services unavailable on the free tier, even when consumption stays within
quota. The block follows from the **service**, not the volume.

What does **not** require the paid plan, and was therefore used freely:

| Resource | Note |
|---|---|
| Firestore — reads, writes and streams | 50k reads and 20k writes per day |
| Firestore Rules, including cross-document `get()` | Each `get()` counts as a read |
| Transactions and `WriteBatch` | The basis of the system's atomicity |
| Aggregation queries (`count()`) | Used in metrics and attachments |
| Google Authentication | — |
| Crashlytics and Performance Monitoring | Require activation only |
| **FCM** | The library is free; what is missing is **who** dispatches — §3.1 |

**Cloud Storage** now requires the paid plan on new projects: provisioning the
default bucket demands a billing account. Older projects keep their existing
bucket.

---

## 2. What already operates fully

These features are **complete**. Nothing in them changes when the paid plan is
enabled.

### 2.1 Requester–professor conversation

Created within the same transaction that moves the demand into production.
Messages, unread counters and closure on completion or cancellation — all in
real time over Firestore.

`ChatRepository` · `chats/{demandaId}` · `chats/{demandaId}/mensagens`

### 2.2 In-app notification centre

Notices with a counter, read marking and navigation to the event's target.
Covers the whole cycle: review, acceptance, return, completion, cancellation,
new message, report received and adjudicated, warning, suspension, profile
deactivation and reactivation.

`NotificacaoRepository` · `notificacoes/{id}`

> What depends on the paid plan here is **only the push** — the notice with the
> application closed. The in-app notice is complete. See §3.1.

### 2.3 Reports, warnings and suspension

The professor reports; the administrator adjudicates; an upheld report
increments warnings **within the same transaction**; on reaching the threshold,
the account is suspended. Rules refuse demand creation from a suspended
account, so suspension holds even outside the application.

`DenunciaRepository.julgar` · `denuncias/{id}` · `firestore.rules`

### 2.4 Administrative panel

System overview, report queue, faculty management with individual metrics, and
requester management with warnings and suspension. All in real time.

`AdminRepository` · `features/admin/`

### 2.5 Faculty activation and deactivation

The administrator disables the profile; the professor is notified, routing
takes them to the blocking screen **within the open session**, and Rules refuse
demand transitions from an inactive profile.

---

## 3. Catalogue of paid-plan dependencies

### 3.1 Push notification — high priority

**What is missing.** Sending requires a trusted server. The client cannot
dispatch notices to third parties without exposing the server key.

**What exists.** A complete in-app centre. The user sees everything on opening
the application; what does not happen is the notice while it is closed.

**Ready hook.** Every document in `notificacoes` is created with
`enviada: false`. The function observes the collection and flips the flag.

```js
exports.dispatchPush = onDocumentCreated('notificacoes/{id}', async (event) => {
  const n = event.data.data();
  if (n.enviada) return;

  const tokens = await tokensFor(n.destinatarioUid);
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

**Application change.** Add `firebase_messaging`, request permission and store
the device token in `users/{uid}.fcmTokens`. This is the only pending
data-model change in the whole catalogue, and it is additive.

### 3.2 Automatic 24-hour return

**What is missing.** A scheduled task returning **every** demand whose review
window expired to the shelf, regardless of anyone opening the application.

**What exists.** Client-side reconciliation: a professor's own expired demands
are returned when they open their list. This covers the common case but not the
absent professor — the demand stays held until they return.

```js
exports.expireReviews = onSchedule('every 60 minutes', async () => {
  const now = new Date().toISOString();
  const expired = await db.collection('demandas')
    .where('status', '==', 'emAnalise')
    .where('analiseExpiraEm', '<', now)
    .get();

  const batch = db.batch();
  expired.forEach((doc) => batch.update(doc.ref, {
    status: 'cadastrada',
    professorUid: null, professorNome: null,
    analiseIniciadaEm: null, analiseExpiraEm: null,
    atualizadoEm: now,
  }));
  await batch.commit();
});
```

Requires the index `demandas (status, analiseExpiraEm)`.

### 3.3 Role custom claims

**What is missing.** Today "who is an administrator" is decided by an address
list **duplicated** across Dart and the Rules. Adding someone requires editing
both and republishing the application.

**Solution.** A function that reads the list from a configuration collection and
assigns `role` as a claim. Rules then consult `request.auth.token.role`, and
adding an administrator becomes a Firestore write.

### 3.4 Attachment antivirus

**What exists.** Storage Rules restrict MIME type and size, which stops the
accidental but not a malicious document.

**Solution.** An `onObjectFinalized` trigger submitting the file for content
inspection, removing the object and its record on detection, and notifying the
uploader.

### 3.5 Denormalised metric counters

**What exists.** Metrics are aggregated client-side from the consulted
professor's demands — one query per faculty member opened, not a global scan.

**When to migrate.** Above a few hundred demands per faculty member. An
`onDocumentWritten('demandas/{id}')` function would keep `users/{uid}.metricas`
current, and the panel would read a single document.

### 3.6 Conversation moderation

Rules declare `allow update, delete: if false` on the message subcollection —
an immutable history, by design. Removing an abusive message upon report
requires the admin SDK, which bypasses the Rules.

### 3.7 Orphaned file cleanup

Hard-deleting a demand leaves its attachments in storage. An
`onDocumentDeleted` trigger would remove the corresponding prefix. Hard
deletion is not exposed in the interface, so the problem has not yet
materialised.

### 3.8 Data retention

`audit_logs` and `notificacoes` grow without bound. A scheduled task would
remove read notifications older than ninety days and archive old records.
Growth is linear and modest, but this is real debt.

### 3.9 Transactional email

The official *Trigger Email* extension consumes a collection and dispatches by
SMTP. Extensions require the paid plan. The `notificacoes` collection serves as
the trigger.

### 3.10 Backfilling conversations

**Not dependent on the paid plan**, but listed here as the only pending
migration.

Demands already in production **before** chat was introduced have no document
under `chats/`. The application handles this without failing — the screen
explains that demands accepted in earlier versions have no conversation — but
those pairs are left without a channel.

At small volume, returning and re-accepting the demand resolves it. At larger
volume, a one-off script using the admin SDK, runnable from any machine without
the paid plan, walks the demands in production and creates the corresponding
conversation, followed by a system message — without which the conversation
does not appear in the list.

---

## 4. Hooks already present in the code

| Hook | Location | Serves |
|---|---|---|
| `notificacoes.enviada` | `NotificacaoRepository.enfileirar` | §3.1, §3.9 |
| `demandas.analiseExpiraEm` | `DemandaRepository.marcarParaAnalise` | §3.2 |
| `Demanda.analiseExpirou` | `core/models/demanda.dart` | §3.2 — same rule on both sides |
| `audit_logs` (append-only) | every repository | §3.8, auditing |
| `denuncias.strikeAplicado` | `DenunciaRepository.julgar` | moderation trail |
| `AppConstants.adminEmails` | `core/constants/` | §3.3 |
| `chats.ativo` | `ChatRepository.encerrar` | §3.6 |

---

## 5. Suggested implementation order

By largest gap closed per unit of effort:

1. **§3.2 — automatic return.** The only gap with a visible functional effect
   today. A small function.
2. **§3.1 — push.** The application already surfaces everything internally;
   push changes the system's response time.
3. **§3.3 — custom claims.** Removes the coupling that today requires
   republishing the application to add an administrator.
4. **§3.4 — antivirus.** Closes the attachment security requirement.
5. **§3.8 — retention.** Before volumes become bothersome.
6. **§3.5, §3.6, §3.7** — as usage justifies.

---

## 6. Cost estimate

The paid plan charges for usage **above** the free quota, which remains in
force. For this project's profile — one campus, dozens of active users:

| Item | Monthly free quota | Estimated usage |
|---|---|---|
| Function invocations | 2 million | thousands |
| GB-seconds of compute | 400,000 | hundreds |
| Cloud Build | 120 min per day | a few minutes per deploy |
| Firestore | 50k reads per day | well below |

**Conclusion.** Expected monthly cost approaches zero; the paid plan is
required by the **existence** of the service, not by consumption. Even so,
configure a **budget with an alert** before migrating — an accidental loop in a
function is the classic way to produce an unexpected invoice.

---

<div align="center">

**Living documentation.**
On implementing an item, move it from section 3 to section 2 and update the
corresponding hook in section 4.

</div>
