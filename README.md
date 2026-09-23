# Acatrain

An offline-first Flutter study app with Firebase-backed content and a Cloudflare Workers MCP publishing API. This is an MVP foundation, not a complete Quizlet clone.

## Included

- Adaptive Material 3 home for phone, tablet and desktop, shared-element study-set transitions, searchable subject library, flashcards, multiple-choice tests, explanations and mistake practice.
- A simple five-box review schedule (not FSRS), local progress, light/dark themes, 19 original practice items across economics, mathematics and English.
- Complete content-release downloads, SHA-256 checks, compatibility validation, last-known-good cache and session snapshots. Updating a published study set does not require an APK update.
- Firebase Authentication over REST with email/password, account creation, password reset and passwordless email-link sign-in. Google sign-in is available on Android, iOS, Web, Linux, macOS and Windows with platform OAuth configuration. When an email already has a password account, sign in with that password and connect Google from Personal info; both methods then use the same account and progress. Guest and account progress are isolated; account sessions remain in memory only.
- Manual cloud progress merge with per-item last-write-wins and optimistic concurrency retry. No automatic uploads of guest progress.
- MCP draft editing, validation, atomic publishing, immutable releases and rollback, with separate editor/publisher credentials.
- One app icon on every platform (Android adaptive + themed icon, iOS, Web/PWA, macOS, Windows, Linux) and an animated launch screen that plays while the app loads; native splash colours match so the hand-off is seamless.
- Demo plans (Free, Starter, Pro, Max 20x) that re-theme the app. Checkout is simulated end to end but behaves like the real thing: Google Play (payment-method picker, fingerprint prompt), App Store (double-click side button, Face ID, confirmation alert) and Stripe (card entry with brand detection and validation, Stripe's test-card outcomes including declines and 3-D Secure). Monthly or yearly billing, proration credit on upgrades, renewals and receipts while you are away, cancel and resume, and a tilting membership card. Nothing is ever contacted or charged, and no card number is stored.
- High-refresh motion: Android requests the highest available display mode; iOS runners enable ProMotion; Web/desktop animations follow system vsync. CI validates every platform and packages APK, DEB, RPM, AppImage, Flatpak, DMG and unsigned IPA installers.

The display language can be switched between English and Cantonese (Traditional Chinese) in Settings. Study content retains its original language.

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

`android/` and `ios/` are committed native runners so native integrations remain stable across local builds and CI. `bootstrap` only creates platform directories that are missing and never replaces an existing runner, application code, tests or `pubspec.yaml`; Web/Linux/Windows/macOS remain generated on demand; freshly generated runners get the Acatrain icons and names from `packaging/icons` (pass `--icons` to re-apply them to an existing runner). Icons are rendered by `python3 tool/generate_icons.py` (needs `pillow` and `cairosvg`). When Firebase native configuration is ready, place `google-services.json` at `android/app/google-services.json` and `GoogleService-Info.plist` at `ios/Runner/GoogleService-Info.plist`. Platform SDKs/toolchains are still required. CI produces an unsigned IPA for inspection/sideload-signing workflows and an unsigned/unnotarized DMG; normal iPhone/iPad distribution still requires Apple signing, and public macOS distribution should be signed and notarized.

```sh
npm test --prefix backend/worker
node tool/check-content.mjs
flutter analyze --no-fatal-infos
flutter test
```

Native apps retain bundled and downloaded study data for offline use. Web caches study data locally, but offline page reload is not guaranteed: this MVP does not add a custom PWA service worker.

## CI packages

Every CI run builds real installer/package files instead of uploading raw Flutter output directories:

- Android: `.apk`
- Linux x86_64: `.deb`, `.rpm`, `.AppImage`, `.flatpak`
- macOS: `.dmg`
- iOS: unsigned `.ipa`
- Windows and Web are still compiled as compatibility checks, but no raw directory ZIP artifact is published.

GitHub's Actions artifact service always wraps downloads in a ZIP container. To provide the package files directly, pushes of tags matching `v*` create/update a GitHub Release and attach the APK/DEB/RPM/AppImage/Flatpak/DMG/IPA files as direct release assets.

The Android release APK uses the committed runner's current debug-key release signing configuration until a production Android keystore is configured. The IPA is intentionally unsigned and the DMG is not notarized.

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

Copy `config.example.json` to ignored `app-config.json`, then fill in the Worker URL, Firebase Web API key and `ACATRAIN_AUTH_CONTINUE_URL` (an authorized HTTPS Firebase Hosting page used by passwordless email-link sign-in). For Google sign-in on Web, also set the Firebase Web app ID, project ID and messaging sender ID, enable Google in Firebase Authentication, and authorize the Web origin. For Linux, macOS and Windows, create a Google Desktop OAuth client with loopback redirect support and set `GOOGLE_DESKTOP_CLIENT_ID`. Android and iOS use their native Google configuration files. Set the matching GitHub Actions variables for release builds.

```sh
flutter run -d chrome --web-port 8080 --dart-define-from-file=app-config.json
flutter build web --release --dart-define-from-file=app-config.json
npx -y firebase-tools@latest deploy --project YOUR_PROJECT_ID --only hosting
```

Pushing to `main` runs the native/Web CI build and publishes the same commit to Firebase Hosting. The Hosting workflow reads the project's public Web configuration from Firebase, builds with the configured Worker URL, and verifies the live `release.json` commit. Commits marked `[deploy]` use the full cloud deployment workflow instead.

Set the repository **Actions variables** `ACATRAIN_API_URL`, `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_PROJECT_ID` for cloud-connected CI package builds. Set `GOOGLE_DESKTOP_CLIENT_ID` for Google login in desktop packages. The Hosting workflow can resolve its public Firebase Web settings and uses the current production Worker address if `ACATRAIN_API_URL` is absent. It requires the `FIREBASE_DEPLOY_SERVICE_ACCOUNT` secret. APK artifacts are **debug-signed**, not Play Store releases. The full Deploy Cloud workflow runs manually or for a `[deploy]` commit on `main`.

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
