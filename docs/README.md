<div align="center">

<img src="/assets/images/nexus-appicon.png" width="140" alt="Nexus Tech" />

# Nexus Tech

### A ponte entre quem tem problema e quem sabe resolver.

Empresas, ONGs e a comunidade publicam demandas.
Professores do **IFRS Campus Osório** transformam em projetos reais.

<br />

[![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter&logoColor=white&style=for-the-badge)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white&style=for-the-badge)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black&style=for-the-badge)](https://firebase.google.com)

![Sprint 2 entregue](https://img.shields.io/badge/sprint_2-entregue-success?style=flat-square)
![Plataformas](https://img.shields.io/badge/Android_·_iOS_·_Web-supported-2D5A2D?style=flat-square)
![IFRS](https://img.shields.io/badge/IFRS-Campus_Osório-2D5A2D?style=flat-square)

[**Arquitetura →**](./ARCHITECTURE.md) · [**Roadmap ↓**](#-roadmap) · [**Quickstart ↓**](#-quickstart)

</div>

---

## Como funciona

<table>
<tr>
<td align="center" width="33%">

### 📝
**Demandante publica**

Descreve necessidade, público-alvo, impacto. Anexa documentos.

</td>
<td align="center" width="33%">

### 👨‍🏫
**Professor encontra**

Filtra por área técnica, decide assumir conforme expertise.

</td>
<td align="center" width="33%">

### 🚀
**Vira projeto real**

TCC, projeto de extensão ou parceria acadêmica com impacto.

</td>
</tr>
</table>

> Antes do Nexus Tech, essa conexão dependia de contato pessoal, e-mail solto ou sorte. Demanda boa morria por não chegar ao professor certo.

---

## ⚡ Quickstart

```bash
git clone <repo-url> && cd nexus_tech
flutter pub get
flutter run
```

> **Pré-requisitos:** Flutter 3.38+ · Dart 3.10+ · Android SDK 21+ ou Xcode 15+
> Configs do Firebase já versionadas (chaves públicas do cliente — segurança real está nas Rules).

<details>
<summary><b>Deploy de Rules e Indexes</b></summary>

```bash
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only storage
```

</details>

<details>
<summary><b>Trocar para um projeto Firebase próprio</b></summary>

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

</details>

---

## 🧩 Stack

<table>
<tr>
<td>

**Frontend**
- Flutter 3.38+
- Dart 3.10+
- Material 3
- Provider (estado)

</td>
<td>

**Backend (Firebase)**
- Auth + Google Sign-In
- Cloud Firestore
- Storage
- Rules (server-side)

</td>
<td>

**Plataformas**
- Android (foco)
- iOS
- Web · Linux · macOS · Windows

</td>
</tr>
</table>

---

## ✨ O que já existe

<table>
<tr>
<td valign="top" width="50%">

**Autenticação**
- ✅ Login com Google
- ✅ Cadastro diferenciado por papel
- ✅ Detecção automática de admin
- ✅ CPF/CNPJ módulo 11
- ✅ Validação de DDDs Anatel

**Demandas (lado do demandante)**
- ✅ Criar, editar, cancelar
- ✅ Republicar (transação atômica)
- ✅ Filtros acumulativos (status × período)
- ✅ Busca por título
- ✅ Tempo real via streams

</td>
<td valign="top" width="50%">

**Anexos**
- ✅ Upload (PDF, DOCX, JPG, PNG)
- ✅ Limite de 10 MB
- ✅ Abrir externamente
- ✅ Remover (uploader original)

**Áreas técnicas / interesse**
- ✅ Vocabulário compartilhado
- ✅ Dedup por chave normalizada
- ✅ Extensível pelos professores
- ✅ Query indexada para evitar duplicatas

</td>
</tr>
</table>

---

## 📐 Arquitetura de forma simplificada

```
   UI  ─────▶  Providers  ─────▶  Repositories  ─────▶  Firebase
(telas)      (estado, regras)     (única fronteira         (Auth · Firestore · Storage)
                                   com Firebase)              + Rules (defesa em profundidade)
```

**Princípios:**
- UI nunca toca Firebase. Repositório nunca decide regra de negócio.
- Segurança em 3 camadas: cliente (UX) · Firestore Rules · Storage Rules.
- Streams onde o usuário espera ver mudar agora. Futures onde não muda.
- Exceções tipadas e centralizadas — UI nunca vê `FirebaseException` crua.

📖 Detalhes, trade-offs e decisões com motivo em [**ARCHITECTURE.md**](./ARCHITECTURE.md).

---

## 🗂️ Estrutura

<details>
<summary><b>lib/ — abrir árvore completa</b></summary>

```
lib/
├── main.dart                        Bootstrap + Firebase init
├── firebase_options.dart            Gerado pelo FlutterFire
│
├── app/                             Cola do app
│   ├── app.dart                     MultiProvider + MaterialApp
│   ├── router.dart                  Roteamento por auth + role
│   └── theme.dart                   Material 3 + cores institucionais
│
├── core/                            Compartilhado por todas as features
│   ├── constants/                   Domínio institucional, admins
│   ├── exceptions/                  Sealed AppException + handler
│   ├── models/                      Usuario, Demanda, Anexo, Area...
│   ├── providers/                   AuthProvider (global)
│   ├── repositories/                Única camada que toca Firebase
│   ├── services/                    AuthService (Google + Firebase)
│   └── utils/                       Validators (CPF, CNPJ, DDD), formatters
│
└── features/
    ├── auth/                        Login + Cadastro
    └── demandas/                    CRUD + form + listagem + detalhes
```

</details>

**Regra simples:** se uma segunda feature pode precisar disso, vai pra `core/`. Caso contrário, fica isolado.

---

## 🛣️ Roadmap

| Sprint | Foco | Status |
|:--:|---|:--:|
| **1** | Auth, cadastro, áreas | ✅ |
| **2** | CRUD de demandas + anexos | ✅ |
| **3** | Prateleira do professor · fluxo de assunção · transições de status | 🔜 |
| **4** | Chat · notificações · sistema de strikes | 📋 |
| **5** | Painel administrativo · dashboards | 📋 |

---

## ⚠️ Limitações 

> Deixei documentado para manter a transparência no projeto.

<table>
<tr><td>🧪</td><td><b>Sem testes automatizados</b> — decisão temporária. Validadores e fluxo de republicação entram antes do Sprint 3.</td></tr>
<tr><td>🛡️</td><td><b>Antivírus de anexos não é real</b> — só extensão + MIME + tamanho são validados. Verificação real exige Cloud Function pós-upload.</td></tr>
<tr><td>🔍</td><td><b>Busca por título é client-side</b> — funciona para o demandante (poucas demandas). Vai precisar evoluir para a prateleira do professor.</td></tr>
<tr><td>🤖</td><td><b>Sem CI/CD</b> — builds e deploys são manuais.</td></tr>
<tr><td>👤</td><td><b>Lista de admins é enumerada em código</b> — adicionar/remover exige redeploy. Migração futura: custom claims.</td></tr>
</table>

---

## 👥 Time de Desenvolvimento

<table>
<tr>
<td>

**Desenvolvimento**
Gustavo Rech Costa
*Bolsista — ADS, IFRS Campus Osório*

</td>
<td>

**Orientação**
Profª Karen Borges
*IFRS Campus Osório*

</td>
<td>

**Instituição**
Instituto Federal do RS
*Campus Osório · 2025–2026*

</td>
</tr>
</table>

---

<div align="center">

Desenvolvido na Fábrica de Software Acadêmica - IFRS Campus Osório

</div>