# Operações — Nexus Tech

Playbook para tarefas que acontecem raramente mas precisam ser feitas do jeito certo.

## Rodar uma release beta

1. GitHub > aba **Actions** > workflow "Beta Android — Firebase App Distribution".
2. Botão **"Run workflow"**. Em "release notes", descreve o que mudou — vai pro e-mail dos testers.
3. Acompanha o log. Tempo médio: 5–10 min.
4. Quando o step "Distribute APK" der verde, testers no grupo `QA-team` recebem e-mail "Nexus Tech is ready to test" em até 2 min.

## Adicionar um novo tester

Firebase Console > App Distribution > **Testers & Groups** > grupo `QA-team` > "Add testers" > e-mail do convidado > Save.

Próxima distribuição inclui o novo. Pra dar acesso a TODAS as releases passadas, depois de criar abre a release na aba "Releases" e "Add tester" individualmente.

## Rotacionar a release keystore

⚠️ **Risco alto.** Mudar a keystore = nova identidade do app no Google. Toda autenticação (Google Sign-In, etc.) quebra até registrar o novo SHA. Testers terão que desinstalar e reinstalar antes de receber a nova versão (assinaturas incompatíveis).

Só faz se a keystore foi comprometida ou perdida.

1. Gera nova: `keytool -genkey -v -keystore nexus-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nexus`
2. Guarda em `~/.keystores/` (fora do repo).
3. Atualiza secrets: `base64 -w0 ~/.keystores/nexus-release.jks | gh secret set ANDROID_KEYSTORE_BASE64`. Repete para `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
4. Pega o SHA-1 e SHA-256 da nova: `keytool -list -v -keystore ~/.keystores/nexus-release.jks -alias nexus`.
5. Firebase Console > Project Settings > Android app > "Add fingerprint" > cola SHA-1 e SHA-256. Salva.
6. Avisa testers que precisam **desinstalar a versão atual** antes de receberem a próxima.

## Rotacionar o service account do GitHub Actions

Se o `FIREBASE_SERVICE_ACCOUNT_JSON` vazar:

1. GCP Console > IAM & Admin > Service Accounts > `github-actions-distrib` > aba **Keys** > deleta a chave comprometida.
2. "Add Key" > Create new key > JSON. Baixa.
3. `gh secret set FIREBASE_SERVICE_ACCOUNT_JSON < /caminho/para/o.json`
4. Apaga o JSON local.

## Adicionar um admin

1. Edita `lib/core/constants/app_constants.dart` > `adminEmails` > inclui o e-mail.
2. Edita `firestore.rules` > `isAdminEmail()` > inclui o mesmo e-mail.
3. Comita e push. Firestore Rules são deployadas manualmente por enquanto:
```bash
   firebase deploy --only firestore:rules
```
4. Pessoa nova faz login com Google — registro de admin é criado automaticamente no primeiro acesso.

## Secrets atualmente em uso

| Secret | Última rotação | Quando rotacionar | 
|---|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | 2026-05-17 | Após suspeita de vazamento |
| `ANDROID_KEYSTORE_BASE64` | 2026-05-17 | Só se comprometida |
| `ANDROID_KEYSTORE_PASSWORD` | 2026-05-17 | Junto com a keystore |
| `ANDROID_KEY_ALIAS` | 2026-05-17 |  Estático (`nexus`) |
| `ANDROID_KEY_PASSWORD` | 2026-05-17 | Junto com a keystore |
| `FIREBASE_APP_ID_ANDROID` | (não rotaciona — é o ID público do app) | Nunca |