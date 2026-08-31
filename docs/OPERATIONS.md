<div align="center">

# Operações

**Nexus Tech** · IFRS Campus Osório

*Procedimentos que acontecem raramente e precisam ser feitos do jeito certo.*

**Português** · [English](OPERATIONS.en.md)

</div>

---

## Sumário

**[1. Ambientes](#1-ambientes)** · **[2. Criar um ambiente de teste](#2-criar-um-ambiente-de-teste)** · **[3. Publicar Rules e índices](#3-publicar-rules-e-índices)** · **[4. Alternar entre ambientes](#4-alternar-entre-ambientes)** · **[5. Papéis e contas](#5-papéis-e-contas)** · **[6. Distribuir uma versão](#6-distribuir-uma-versão)** · **[7. Chaves e segredos](#7-chaves-e-segredos)**

---

## 1. Ambientes

O projeto opera sobre **dois projetos Firebase independentes**. A separação
existe porque exercitar o ciclo de moderação — publicar demandas fictícias,
denunciar, aplicar advertências, suspender contas — sobre dados reais não tem
desfazer.

| | Produção | Testes |
|---|---|---|
| **Alias no CLI** | `prod` | `dev` |
| **Firestore** | `(default)` · `southamerica-east1` | `(default)` · `southamerica-east1` |
| **Storage** | disponível | ausente — exige plano pago |
| **Uso** | versão distribuída aos testadores | tudo que puder quebrar |

Os aliases estão em `.firebaserc`, o que dispensa editar arquivos para alternar
o destino de um comando:

```bash
firebase deploy --only firestore:rules --project dev
firebase deploy --only firestore:rules --project prod
```

> **`--project` não é opcional.** O alias `default` aponta para **produção**.
> Um `firebase deploy` sem a bandeira atinge o ambiente real.

**Isolamento.** Projetos distintos não compartilham dados, contas de
autenticação, regras, índices, armazenamento nem cota. Os caminhos completos dos
recursos são distintos, ainda que o banco de ambos se chame `(default)` — assim
como dois repositórios Git distintos podem ambos ter um ramo `main`.

---

## 2. Criar um ambiente de teste

### 2.1 Criar o projeto

```bash
firebase projects:create <id-do-projeto> --display-name "Nexus Tech DEV"
```

O identificador é **permanente e globalmente único**. Convém espelhar o de
produção com um sufixo.

Registre o alias em `.firebaserc`:

```json
{ "projects": { "default": "<prod>", "prod": "<prod>", "dev": "<dev>" } }
```

### 2.2 Ligar os serviços no console

Um projeto novo nasce com os serviços desligados, e as APIs só são habilitadas
na primeira abertura de cada um. **Este passo não é automatizável pelo CLI.**

**Firestore** → *Criar banco de dados* → modo **produção** → local
`southamerica-east1`.

> **O identificador do banco precisa ser `(default)`, com os parênteses.**
> Eles fazem parte do identificador. Um banco criado como `default`, sem eles,
> é um banco **nomeado** como qualquer outro: `FirebaseFirestore.instance` não
> o encontra e o deploy de Rules não o atinge — sem que nada acuse erro. No
> campo *Database ID*, mantenha o valor já preenchido em vez de digitar.
>
> Também não adianta criar o `(default)` ao lado: **múltiplos bancos exigem
> plano pago**. No plano gratuito é um banco por projeto. Se o banco nasceu com
> outro nome, apague-o e recrie aceitando o identificador sugerido.

**Authentication** → *Começar* → aba *Sign-in method* → **Google** → ativar e
informar o endereço de suporte.

**Storage** → *Começar* → `southamerica-east1`.

> **O Storage exige plano pago em projetos novos.** O provisionamento do balde
> padrão passou a requerer conta de faturamento. Sem ele, o envio de anexos
> falha — com erro tratado pela aplicação, não com queda — e todo o restante do
> ciclo funciona. As alternativas são ativar o plano pago com orçamento zerado
> e alerta, ou usar o emulador local (§7.3).

### 2.3 Registrar os aplicativos

```bash
flutterfire configure --project=<id-do-projeto>
```

O comando registra os aplicativos e **sobrescreve três arquivos versionados**:
`lib/firebase_options.dart`, `android/app/google-services.json` e o bloco
`flutter` de `firebase.json`. É por isso que existe a seção 4.

### 2.4 Impressão digital do certificado — Android

Sem a impressão digital registrada, o login com Google no Android falha com
`ApiException: 10` (`DEVELOPER_ERROR`), sem mensagem que indique a causa.

```bash
# obter a impressão digital da chave de depuração
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA1

# registrar
firebase apps:list --project dev
firebase apps:android:sha:create <APP_ID_ANDROID> <SHA1> --project dev
firebase apps:android:sha:list   <APP_ID_ANDROID> --project dev
```

Em seguida execute `flutterfire configure` novamente: o cliente OAuth só passa
a existir após o registro da impressão digital.

> **O par (`applicationId` + impressão digital) é único em todo o Google
> Cloud.** Dois projetos não podem reivindicar o mesmo par; a tentativa retorna
> `409 ALREADY_EXISTS`. Como a chave de depuração é a mesma nos dois ambientes,
> o `applicationId` precisa diferir — daí o `applicationIdSuffix = ".dev"` no
> tipo de build `debug`, em `android/app/build.gradle.kts`. O efeito colateral
> é bem-vindo: os dois aplicativos convivem no mesmo aparelho, com rótulos
> distintos.
>
> **Consequência:** builds de depuração passam a funcionar **apenas** com a
> configuração do ambiente de teste. Com a configuração de produção, o plugin
> `google-services` recusa a compilação por não encontrar cliente para o pacote
> com sufixo. Na prática, virou uma trava: depuração corresponde a testes,
> versão de lançamento corresponde a produção.

### 2.5 Verificar

```bash
grep -m1 projectId lib/firebase_options.dart   # ambiente em uso
```

---

## 3. Publicar Rules e índices

Um projeto novo nasce com regras restritivas e **nenhum índice**. Sem este
passo, as listagens de conversas, notificações e denúncias falham em tempo de
execução.

```bash
# produção
firebase deploy --only firestore:rules,firestore:indexes,storage --project prod

# testes — sem storage, que não está provisionado (§2.2)
firebase deploy --only firestore:rules,firestore:indexes --project dev
```

> **No ambiente de teste, nunca execute `firebase deploy` sem `--only`.** O
> arquivo `firebase.json` declara um bloco `storage`, e o deploy inteiro é
> abortado por ausência do balde — sem publicar sequer as regras do Firestore.

Os índices levam alguns minutos para sair do estado *Building*. Acompanhe em
**Firestore → Índices**.

---

## 4. Alternar entre ambientes

Os arquivos de configuração do Firebase são **versionados**. Enquanto os
ambientes não forem separados por *flavors* de build, alternar é uma operação
manual — e a verificação abaixo é a única rede de proteção.

**Voltar para produção**, obrigatoriamente antes de gerar qualquer versão para
distribuição:

```bash
flutterfire configure --project=<projeto-de-producao>
```

Ou, se a configuração de produção estiver íntegra no último commit:

```bash
git checkout -- lib/firebase_options.dart \
                android/app/google-services.json \
                firebase.json
```

**Antes de commitar**, confira o que está sendo enviado:

```bash
git diff --name-only | grep -E 'firebase_options|google-services|firebase.json'
```

Se algo for listado, confirme para qual projeto aponta.

> **Caminho definitivo.** Criar *product flavors* no Gradle
> (`flutter run --flavor dev`) tornaria a troca impossível de errar. A adiação
> é consciente: exige alterar `build.gradle.kts` e o fluxo de distribuição.

---

## 5. Papéis e contas

### 5.1 Como um papel é atribuído

O papel é decidido **no primeiro acesso** e gravado em `users/{uid}`. A partir
daí, é o documento que vale.

| Papel | Critério |
|---|---|
| **Administrador** | Endereço listado em `AppConstants.adminEmails` |
| **Professor** | Endereço do domínio institucional `@osorio.ifrs.edu.br` |
| **Demandante** | Qualquer outra conta Google |

Existe ainda uma lista de exceção, `AppConstants.professorTestEmails`, que
permite validar o fluxo docente com uma conta pessoal. Está demarcada no código
com o aviso **REMOVER ANTES DE PRODUÇÃO** e deve ser esvaziada na publicação
definitiva.

> **A verificação de administrador precede a de professor.** Um endereço
> presente nas duas listas será tratado como administrador e nunca exercerá o
> papel docente. As listas são mantidas **disjuntas** por isso.

Exercitar o ciclo completo — publicação, análise, aceite, denúncia e julgamento
— requer **três contas Google distintas**, uma por papel. Qualquer conta serve
como demandante, sem configuração.

### 5.2 Adicionar um administrador

1. Incluir o endereço em `lib/core/constants/app_constants.dart`
   (`adminEmails`).
2. Incluir **o mesmo endereço** em `firestore.rules`, no auxiliar
   `isAdminEmail()`.
3. Publicar as regras: `firebase deploy --only firestore:rules --project prod`.
4. A pessoa faz login. O perfil de administrador é criado automaticamente.

> O passo 4 vale apenas para quem **nunca acessou**. Quem já possui documento
> em `users/{uid}` mantém o papel gravado — ver §5.3.

### 5.3 Reclassificar uma conta

Alterar as listas não reclassifica quem já acessou. É decisão deliberada:
impede que uma edição de lista altere o papel de contas em uso.

1. Firebase Console → Firestore → `users` → localizar o documento pelo campo
   `email`.
2. Anotar o identificador do documento, que é o `uid`.
3. Excluir o documento.
4. A pessoa sai e entra novamente. O papel é recalculado.

**O que se perde:** histórico do perfil — fotografia, áreas, telefone — e, para
demandantes, as advertências acumuladas. Demandas e conversas **não** são
afetadas: referenciam o `uid`, que não muda.

> No ambiente de teste esse procedimento raramente é necessário: as contas
> nascem sem documento, e o papel vale já no primeiro acesso.

---

## 6. Distribuir uma versão

> O fluxo automatizado de integração contínua foi removido. O processo é
> **manual**, executado a partir da máquina de quem publica.

**Antes de tudo**, confirme o ambiente:

```bash
grep -m1 projectId lib/firebase_options.dart   # precisa ser o de produção
```

```bash
# 1. portões de qualidade — não são opcionais
flutter analyze
flutter test

# 2. build assinado
export KEYSTORE_PATH=~/.keystores/nexus-release.jks
export KEYSTORE_PASSWORD=… KEY_ALIAS=nexus KEY_PASSWORD=…
flutter build apk --release

# 3. distribuição
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app <APP_ID_ANDROID> \
  --groups "QA-team" \
  --release-notes "o que mudou nesta versão" \
  --project prod
```

Os testadores do grupo recebem aviso por correio eletrônico em poucos minutos.

> Sem integração contínua, `analyze` e `test` deixaram de ser automáticos. Os
> passos 1 e 2 são a única barreira restante antes de a versão chegar aos
> testadores.

**Adicionar um testador.** Firebase Console → App Distribution → *Testers &
Groups* → grupo `QA-team` → *Add testers*. A próxima distribuição já o inclui;
para conceder acesso às versões anteriores, adicione-o individualmente em cada
uma na aba *Releases*.

---

## 7. Chaves e segredos

### 7.1 Rotacionar a chave de assinatura

> **Risco alto.** Trocar a chave altera a identidade do aplicativo perante o
> Google. Toda autenticação deixa de funcionar até que a nova impressão digital
> seja registrada, e os testadores precisam desinstalar a versão anterior antes
> de receber a próxima — assinaturas incompatíveis não se sobrepõem.
>
> Execute apenas se a chave foi comprometida ou perdida.

```bash
keytool -genkey -v -keystore nexus-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nexus
keytool -list -v -keystore ~/.keystores/nexus-release.jks -alias nexus
```

Guarde o arquivo fora do repositório e as credenciais em gerenciador de senhas.
Registre as novas impressões digitais SHA-1 e SHA-256 no console do Firebase e
avise os testadores sobre a necessidade de desinstalação.

### 7.2 Segredos órfãos

Com a remoção do fluxo automatizado, nenhum segredo do repositório é consumido
por automação. As chaves de conta de serviço permanecem válidas até serem
revogadas — convém revogá-las e remover os segredos:

```bash
gh secret delete FIREBASE_SERVICE_ACCOUNT_JSON
gh secret delete ANDROID_KEYSTORE_BASE64
gh secret delete ANDROID_KEYSTORE_PASSWORD
gh secret delete ANDROID_KEY_ALIAS
gh secret delete ANDROID_KEY_PASSWORD
gh secret delete FIREBASE_APP_ID_ANDROID
```

Revogue a chave em GCP Console → IAM & Admin → Service Accounts → aba *Keys*.

### 7.3 Emulador local

Para verificações que dispensam contas reais — em especial os **testes das
Firestore Rules**, hoje inexistentes e apontados como lacuna prioritária na
arquitetura:

```bash
firebase emulators:start --only firestore,auth,storage
```

Não substitui o ambiente de teste, mas é o caminho adequado para cobrir as
regras com testes automatizados.

---

<div align="center">

**Documentação viva.**
Procedimento que mudar na prática deve mudar aqui no mesmo dia.

</div>
