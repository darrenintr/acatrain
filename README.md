# Acatrain

An offline-first Flutter study app with Firebase-backed content and a Cloudflare Workers MCP publishing API. This is an MVP foundation, not a complete Quizlet clone.

## Included

- Responsive Material 3 home, searchable subject library, flashcards, multiple-choice tests, explanations and mistake practice.
- A simple five-box review schedule (not FSRS), local progress, light/dark themes, 19 original practice items across economics, mathematics and English.
- Complete content-release downloads, SHA-256 checks, compatibility validation, last-known-good cache and session snapshots. Updating a published study set does not require an APK update.
- Firebase email/password authentication over REST, also usable from Linux/Windows without native FlutterFire dependencies. Guest and account progress are isolated; account sessions remain in memory only.
- Manual cloud progress merge with per-item last-write-wins and optimistic concurrency retry. No automatic uploads of guest progress.
- MCP draft editing, validation, atomic publishing, immutable releases and rollback, with separate editor/publisher credentials.
- CI for Worker tests, Flutter analysis/tests, Web/Android builds, Linux/Windows/macOS builds and an unsigned iOS IPA artifact.

The initial UI is English. Study content is Unicode and can be Traditional Chinese; full UI localisation, rich media, LaTeX rendering and a visual authoring screen are not implemented yet.

## Run locally (no cloud account required)

Install Flutter (CI uses **3.44.0**) and Node.js 22+, then:

```sh
git clone https://github.com/darrenintr/acatrain.git
cd acatrain
node tool/bootstrap.mjs
flutter pub get
flutter run -d chrome --web-port 8080
# Or: flutter run -d linux / windows / macos / an attached Android device
```

`bootstrap` creates platform runners from the installed Flutter SDK in a temporary directory and copies only missing runners. It never replaces `lib`, tests or `pubspec.yaml`. Android internet permission and macOS outgoing-network entitlements are added. Existing runners are preserved. Generated runners are ignored initially; commit them explicitly before adding native integrations. Platform SDKs/toolchains are still required. iOS device distribution requires Apple signing: CI packages an unsigned IPA, which only becomes installable after you re-sign it.

```sh
npm test --prefix backend/worker
node tool/check-content.mjs
flutter analyze --no-fatal-infos
flutter test
```

Native apps retain bundled and downloaded study data for offline use. Web caches study data locally, but offline page reload is not guaranteed: this MVP does not add a custom PWA service worker.

## Cloud deployment

Start with **Firebase Spark: Authentication + Firestore Standard + classic Hosting** and **Cloudflare Workers Free**. No Firebase Cloud Functions, App Hosting, Firebase Storage, R2 or model API is required by this MVP. Free-tier quotas are finite; this is not an unlimited free service. Firebase Storage now requires Blaze, so it is deliberately excluded. See `docs/architecture.md` for official references and limits.

### Phone-only deployment with GitHub Actions

If you do not have a computer available, the repository includes **Actions > Deploy Cloud**. Once the values below are configured, the complete deployment can be started from GitHub in a mobile browser.

In **GitHub > acatrain > Settings > Secrets and variables > Actions**, create these **Variables**:

| Variable | Value |
| --- | --- |
| `FIREBASE_PROJECT_ID` | Firebase project ID, for example `acatrain-12345` |
| `FIREBASE_WEB_API_KEY` | Firebase Web app API key |
| `CLOUDFLARE_ACCOUNT_ID` | Cloudflare Account ID |
| `ACATRAIN_API_URL` | Expected Worker URL, for example `https://acatrain-api.example.workers.dev` |
| `EXTRA_ALLOWED_ORIGINS` | Optional comma-separated extra Web origins; leave unset if unused |

Create these **Repository secrets**:

| Secret | Purpose |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token allowed to edit/deploy Workers |
| `FIREBASE_SERVICE_ACCOUNT` | Complete JSON for the Worker-only service account with `roles/datastore.user` |
| `FIREBASE_DEPLOY_SERVICE_ACCOUNT` | Complete JSON for the GitHub deployment service account |
| `MCP_EDIT_TOKEN` | Random 32+ character content-editor token |
| `MCP_PUBLISH_TOKEN` | A different random 32+ character publisher token |

The Firebase deployment service account is separate from the runtime Worker account. For the simplest setup, grant it **Firebase Develop Admin** (`roles/firebase.developAdmin`), which covers the Firebase development/deployment operations used here. The runtime Worker account should remain limited to **Cloud Datastore User** (`roles/datastore.user`). Do not put either service-account JSON or MCP token into repository files or Actions Variables.

Then open:

```text
GitHub repository
→ Actions
→ Deploy Cloud
→ Run workflow
```

An empty installation is initialized with `assets/seed.json` automatically. Turn on **Replace existing live content** only when you intentionally want the bundled seed file to replace the current live study content. You can also deploy by pushing a commit to `main` whose message contains `[deploy]`; other pushes run CI without deploying. The workflow:

```text
validates configuration
→ tests the Worker/content schema
→ builds Flutter Web with the production API settings
→ deploys the Cloudflare Worker
→ installs Worker secrets
→ verifies /health and a real Firestore content read, including Hosting CORS
→ publishes seed content if empty or explicitly requested
→ verifies the published release and its SHA-256 checksum
→ deploys Firestore rules/indexes and Firebase Hosting
```

The final GitHub Actions summary displays the Worker and Firebase Hosting URLs. This workflow deliberately does not put cloud credentials into the Flutter build.

### 1. Firebase

Create a Firebase project, create a **Firestore Standard** database `(default)`, enable Authentication > Email/Password, and register a Web app to obtain its API key. The Web API key is public client configuration, not an admin credential. Do not enable billing just to run this MVP.

Create a dedicated Google service account with `roles/datastore.user` in this project. Download its JSON key to a safe location **outside this repository**. The Worker uses it only for content administration. User-progress calls use the user's Firebase ID token and remain subject to Security Rules.

```sh
npx firebase-tools login
npx firebase-tools deploy --project YOUR_PROJECT_ID --only firestore:rules,firestore:indexes
```

All direct client access to content collections is denied; published content is exposed by the Worker. Only the owner can read/write their progress document. Payload indexing is disabled to avoid indexing entire release bundles.

### 2. Cloudflare Worker

Edit `backend/worker/wrangler.toml` with the Firebase project ID, Web API key and allowed origins. Include your Firebase Hosting origin and local development origin (exact scheme, hostname and port; no wildcard). Native apps do not send an Origin header.

```sh
cd backend/worker
npx wrangler@4 login
npx wrangler@4 secret put FIREBASE_SERVICE_ACCOUNT < /safe/path/service-account.json
npx wrangler@4 secret put MCP_EDIT_TOKEN
npx wrangler@4 secret put MCP_PUBLISH_TOKEN
npx wrangler@4 deploy
cd ../..
```

Generate two independent random tokens of at least 32 characters. Give AI clients only the EDIT token. Keep the PUBLISH token with the human reviewer. Do not place either token, or the service account, in Flutter assets, GitHub variables or client configuration.

### 3. Publish the first bundle

```sh
export ACATRAIN_API_URL=https://acatrain-api.YOUR-SUBDOMAIN.workers.dev
# Set MCP_EDIT_TOKEN securely in your shell, then create a draft only:
node tool/publish.mjs assets/seed.json
# After reviewing the file, set MCP_PUBLISH_TOKEN securely and explicitly publish:
node tool/publish.mjs --publish assets/seed.json
```

The second command creates a fresh reviewed-file draft and publishes it. To publish a particular AI-edited draft, use `get_draft` and `publish_draft` with its exact `version` and the active release ID; see `docs/mcp.md`.

### 4. Connect the app and host Web

Copy `config.example.json` to ignored `app-config.json`, then fill in the Worker URL and Firebase Web API key.

```sh
flutter run -d chrome --web-port 8080 --dart-define-from-file=app-config.json
flutter build web --release --dart-define-from-file=app-config.json
npx firebase-tools deploy --project YOUR_PROJECT_ID --only hosting
```

Set the repository **Actions variables** `ACATRAIN_API_URL` and `FIREBASE_WEB_API_KEY` before running CI for cloud-connected Web/APK artifacts. Without them, those builds intentionally run the offline demo. Desktop CI artifacts are also offline demos. APK artifacts are **debug-signed**, not Play Store releases. The iOS IPA artifact is unsigned, so it only becomes installable after you re-sign it with your own certificate and provisioning profile. CI itself does not deploy infrastructure; the separate Deploy Cloud workflow runs manually or for a `[deploy]` commit on `main`.

## Content workflow

```text
AI editor -> save_draft -> validate_content -> human review
                                      -> publisher publish_draft
                                      -> immutable release + active manifest
Flutter -> check manifest -> verify full bundle -> save -> switch content
```

Each set has stable IDs. Increment an item's `revision` when its meaning or correct answer changes so old review progress does not mark changed material as learned. `assets/seed.json` is the schema-v1 example; `node tool/check-content.mjs path/to/bundle.json` validates a bundle locally.

Current limits: **30 sets, 200 items, 128 KiB per complete content bundle**. This intentionally keeps the MVP within one Firestore document and modest Worker CPU/memory usage. Publication is a single atomic Firestore commit with preconditions, including an audit record. Concurrent editing/publishing fails instead of silently overwriting. Rollback only changes the manifest pointer and creates an audit record.

The public manifest has a 30-second cache. Apps check at startup, on resume after five minutes, and on manual refresh. This is pull-based content sync, not an always-on push channel. Active study sessions use a snapshot; new content applies to subsequent sessions.

## What is not claimed yet

Cloud credentials and a live deployment are not supplied. Unit tests are not an end-to-end test against your Firebase account. Shared preferences provide an MVP small-data cache, not an encrypted or guaranteed-durable database. Full-text search, PDF import, media uploads, OAuth for remote MCP clients, automatic AI inference, collaborative editing, FSRS, accessibility auditing, production rate limiting and app-store distribution need further work. See `docs/architecture.md` before opening registration to a large public audience.
