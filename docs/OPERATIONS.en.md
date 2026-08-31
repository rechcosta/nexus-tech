<div align="center">

# Operations

**Nexus Tech** · IFRS Campus Osório

*Procedures that happen rarely and must be done correctly.*

[Português](OPERATIONS.md) · **English**

</div>

---

## Contents

**[1. Environments](#1-environments)** · **[2. Creating a test environment](#2-creating-a-test-environment)** · **[3. Publishing Rules and indexes](#3-publishing-rules-and-indexes)** · **[4. Switching environments](#4-switching-environments)** · **[5. Roles and accounts](#5-roles-and-accounts)** · **[6. Distributing a release](#6-distributing-a-release)** · **[7. Keys and secrets](#7-keys-and-secrets)**

---

## 1. Environments

The project runs on **two independent Firebase projects**. The separation
exists because exercising the moderation cycle — publishing fictitious demands,
reporting them, issuing warnings, suspending accounts — against real data
cannot be undone.

| | Production | Test |
|---|---|---|
| **CLI alias** | `prod` | `dev` |
| **Firestore** | `(default)` · `southamerica-east1` | `(default)` · `southamerica-east1` |
| **Storage** | available | absent — requires the paid plan |
| **Use** | build distributed to testers | anything that may break |

Aliases live in `.firebaserc`, so switching a command's target requires no file
edits:

```bash
firebase deploy --only firestore:rules --project dev
firebase deploy --only firestore:rules --project prod
```

> **`--project` is not optional.** The `default` alias points at
> **production**. A `firebase deploy` without the flag reaches the real
> environment.

**Isolation.** Distinct projects share no data, authentication accounts, rules,
indexes, storage or quota. Full resource paths differ even though both
databases are named `(default)` — much as two distinct Git repositories may
both have a `main` branch.

---

## 2. Creating a test environment

### 2.1 Create the project

```bash
firebase projects:create <project-id> --display-name "Nexus Tech DEV"
```

The identifier is **permanent and globally unique**. Mirroring the production
identifier with a suffix is advisable.

Register the alias in `.firebaserc`:

```json
{ "projects": { "default": "<prod>", "prod": "<prod>", "dev": "<dev>" } }
```

### 2.2 Enable services in the console

A new project starts with every service disabled, and the APIs are only
activated the first time each service is opened. **This step cannot be
automated through the CLI.**

**Firestore** → *Create database* → **production** mode → location
`southamerica-east1`.

> **The database identifier must be `(default)`, parentheses included.**
> They are part of the identifier. A database created as `default`, without
> them, is a **named** database like any other:
> `FirebaseFirestore.instance` will not find it and rule deployment will not
> reach it — with nothing reporting an error. In the *Database ID* field, keep
> the pre-filled value rather than typing.
>
> Creating `(default)` alongside it does not help either: **multiple databases
> require the paid plan.** On the free tier it is one database per project. If
> the database was created under another name, delete it and recreate it
> accepting the suggested identifier.

**Authentication** → *Get started* → *Sign-in method* tab → **Google** →
enable and provide the support address.

**Storage** → *Get started* → `southamerica-east1`.

> **Storage requires the paid plan on new projects.** Provisioning the default
> bucket now demands a billing account. Without it, attachment upload fails —
> with an error handled by the application, not a crash — and the rest of the
> cycle works. The alternatives are enabling the paid plan with a zero budget
> and an alert, or using the local emulator (§7.3).

### 2.3 Register the applications

```bash
flutterfire configure --project=<project-id>
```

The command registers the applications and **overwrites three version-tracked
files**: `lib/firebase_options.dart`, `android/app/google-services.json`, and
the `flutter` block of `firebase.json`. This is why section 4 exists.

### 2.4 Certificate fingerprint — Android

Without a registered fingerprint, Google sign-in on Android fails with
`ApiException: 10` (`DEVELOPER_ERROR`), carrying no message that points at the
cause.

```bash
# obtain the debug key fingerprint
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA1

# register it
firebase apps:list --project dev
firebase apps:android:sha:create <ANDROID_APP_ID> <SHA1> --project dev
firebase apps:android:sha:list   <ANDROID_APP_ID> --project dev
```

Then run `flutterfire configure` again: the OAuth client only comes into being
after the fingerprint is registered.

> **The pair (`applicationId` + fingerprint) is unique across all of Google
> Cloud.** Two projects cannot claim the same pair; the attempt returns
> `409 ALREADY_EXISTS`. Since the debug key is shared between environments, the
> `applicationId` must differ — hence `applicationIdSuffix = ".dev"` on the
> `debug` build type in `android/app/build.gradle.kts`. The side effect is
> welcome: both applications coexist on one device, under distinct labels.
>
> **Consequence:** debug builds now work **only** with the test configuration.
> Under the production configuration, the `google-services` plugin refuses to
> compile because it finds no client for the suffixed package. In practice this
> became a safeguard: debug maps to test, release maps to production.

### 2.5 Verify

```bash
grep -m1 projectId lib/firebase_options.dart   # environment in use
```

---

## 3. Publishing Rules and indexes

A new project starts with restrictive rules and **no indexes**. Without this
step, the conversation, notification and report listings fail at runtime.

```bash
# production
firebase deploy --only firestore:rules,firestore:indexes,storage --project prod

# test — without storage, which is not provisioned (§2.2)
firebase deploy --only firestore:rules,firestore:indexes --project dev
```

> **In the test environment, never run `firebase deploy` without `--only`.**
> `firebase.json` declares a `storage` block, and the whole deployment aborts
> for want of the bucket — without publishing even the Firestore rules.

Indexes take a few minutes to leave the *Building* state. Follow progress under
**Firestore → Indexes**.

---

## 4. Switching environments

Firebase configuration files are **version-tracked**. Until the environments are
separated by build flavors, switching is a manual operation — and the check
below is the only safety net.

**Return to production**, mandatorily before generating any build for
distribution:

```bash
flutterfire configure --project=<production-project>
```

Or, if the production configuration is intact in the last commit:

```bash
git checkout -- lib/firebase_options.dart \
                android/app/google-services.json \
                firebase.json
```

**Before committing**, inspect what is going out:

```bash
git diff --name-only | grep -E 'firebase_options|google-services|firebase.json'
```

If anything is listed, confirm which project it points to.

> **The definitive path.** Creating Gradle product flavors
> (`flutter run --flavor dev`) would make the switch impossible to get wrong.
> Deferring it is a conscious choice: it requires changing `build.gradle.kts`
> and the distribution flow.

---

## 5. Roles and accounts

### 5.1 How a role is assigned

The role is decided **on first access** and written to `users/{uid}`. From then
on, the document governs.

| Role | Criterion |
|---|---|
| **Administrator** | Address listed in `AppConstants.adminEmails` |
| **Professor** | Address on the institutional domain `@osorio.ifrs.edu.br` |
| **Requester** | Any other Google account |

An exception list, `AppConstants.professorTestEmails`, additionally allows
validating the faculty flow with a personal account. It is marked in the source
with a **REMOVE BEFORE PRODUCTION** warning and should be emptied for the final
release.

> **The administrator check precedes the professor check.** An address present
> in both lists is treated as an administrator and never exercises the faculty
> role. The lists are kept **disjoint** for this reason.

Exercising the full cycle — publication, review, acceptance, reporting and
adjudication — requires **three distinct Google accounts**, one per role. Any
account serves as a requester, with no configuration.

### 5.2 Adding an administrator

1. Add the address to `lib/core/constants/app_constants.dart` (`adminEmails`).
2. Add **the same address** to `firestore.rules`, in the `isAdminEmail()`
   helper.
3. Publish the rules:
   `firebase deploy --only firestore:rules --project prod`.
4. The person signs in. The administrator profile is created automatically.

> Step 4 applies only to someone who has **never signed in**. Anyone who
> already has a `users/{uid}` document keeps the recorded role — see §5.3.

### 5.3 Reclassifying an account

Changing the lists does not reclassify anyone who has already signed in. This
is deliberate: it prevents a list edit from altering the role of accounts in
use.

1. Firebase Console → Firestore → `users` → find the document by its `email`
   field.
2. Note the document identifier, which is the `uid`.
3. Delete the document.
4. The person signs out and back in. The role is recomputed.

**What is lost:** profile history — photograph, areas, telephone — and, for
requesters, accumulated warnings. Demands and conversations are **not**
affected: they reference the `uid`, which does not change.

> In the test environment this procedure is rarely needed: accounts start with
> no document, so the role applies from first access.

---

## 6. Distributing a release

> The automated continuous integration pipeline was removed. The process is
> **manual**, run from the publisher's machine.

**First of all**, confirm the environment:

```bash
grep -m1 projectId lib/firebase_options.dart   # must be the production project
```

```bash
# 1. quality gates — not optional
flutter analyze
flutter test

# 2. signed build
export KEYSTORE_PATH=~/.keystores/nexus-release.jks
export KEYSTORE_PASSWORD=… KEY_ALIAS=nexus KEY_PASSWORD=…
flutter build apk --release

# 3. distribution
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app <ANDROID_APP_ID> \
  --groups "QA-team" \
  --release-notes "what changed in this build" \
  --project prod
```

Testers in the group receive an email notice within minutes.

> Without continuous integration, `analyze` and `test` are no longer automatic.
> Steps 1 and 2 are the only remaining barrier before a build reaches testers.

**Adding a tester.** Firebase Console → App Distribution → *Testers & Groups* →
`QA-team` group → *Add testers*. The next distribution includes them; to grant
access to earlier builds, add them individually under the *Releases* tab.

---

## 7. Keys and secrets

### 7.1 Rotating the signing key

> **High risk.** Changing the key alters the application's identity before
> Google. All authentication stops working until the new fingerprint is
> registered, and testers must uninstall the previous build before receiving
> the next one — incompatible signatures cannot overwrite each other.
>
> Do this only if the key was compromised or lost.

```bash
keytool -genkey -v -keystore nexus-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias nexus
keytool -list -v -keystore ~/.keystores/nexus-release.jks -alias nexus
```

Keep the file outside the repository and the credentials in a password manager.
Register the new SHA-1 and SHA-256 fingerprints in the Firebase console and
warn testers about the required uninstall.

### 7.2 Orphaned secrets

With the automated pipeline removed, no repository secret is consumed by
automation. Service account keys remain valid until revoked, so revoking them
and removing the secrets is advisable:

```bash
gh secret delete FIREBASE_SERVICE_ACCOUNT_JSON
gh secret delete ANDROID_KEYSTORE_BASE64
gh secret delete ANDROID_KEYSTORE_PASSWORD
gh secret delete ANDROID_KEY_ALIAS
gh secret delete ANDROID_KEY_PASSWORD
gh secret delete FIREBASE_APP_ID_ANDROID
```

Revoke the key under GCP Console → IAM & Admin → Service Accounts → *Keys* tab.

### 7.3 Local emulator

For checks that do not require real accounts — in particular the **Firestore
Rules tests**, currently absent and flagged as the top architectural gap:

```bash
firebase emulators:start --only firestore,auth,storage
```

It does not replace the test environment, but it is the proper path to covering
the rules with automated tests.

---

<div align="center">

**Living documentation.**
A procedure that changes in practice should change here the same day.

</div>
