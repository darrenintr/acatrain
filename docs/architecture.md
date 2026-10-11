# Architecture and operational boundaries

## Responsibilities

- Flutter: precompiled flashcard/MCQ renderers, responsive UI, review schedule, local small-data cache and Firebase Auth REST client.
- Worker: authenticated MCP control plane, validation, Google OAuth service-account exchange, Firestore REST adapter, public read API, verified user identity, progress and profile APIs, data export and account-document cleanup.
- Firebase Auth: authoritative user identity. Firestore Standard: drafts, immutable releases, manifest, audit records, per-user progress and presentation profiles. Classic Hosting: compiled Flutter Web assets.

Firestore documents store one `payload` JSON string. The content bundle is bounded to 128 KiB, below the Firestore document limit. Index exemptions are included. This is a minimal full-bundle design, not the future scalable question-per-document/delta-sync design.

## Security

Editor and publisher secrets are independent. Origin allowlisting is enforced before MCP execution. No client may supply a Firestore document path. IDs are validated. Only public manifest/release responses enter edge cache. User data and MCP responses are `no-store`. Anonymous users cannot read cloud progress. The progress UID comes from verified Firebase account lookup, not request JSON. The exact user ID token is passed to Firestore so Security Rules still apply; content administration uses the service account and bypasses Rules, so protect and rotate that key.

Progress is a revision-keyed map. The most recent review timestamp wins; an equal-timestamp deterministic tie-break ensures convergence. Firestore update-time preconditions prevent concurrent snapshot overwrites. This is not a review-event log or a mergeable attempt counter. Device clocks can be wrong. Tokens are kept only in memory; no password or refresh token is written to shared preferences. Local study/progress cache is not encrypted by this app. Guest progress is never silently uploaded or combined with another account.

The JSON string in a user's own progress/profile documents cannot be semantically validated by Firestore Rules. The Worker validates their structures; Rules enforce ownership, exact top-level fields and size. A user bypassing the Worker can corrupt only their own progress payload. The app reports malformed sync data without replacing local state. Add structured progress documents and emulator coverage before relying on complex per-field rules.

Cloudflare native rate-limiting bindings now protect verified account traffic and authenticated MCP calls; a separate generous per-edge-IP limit can reduce unauthenticated Firebase lookups. These limits are approximate/eventually consistent and are not billing-grade. Cloudflare WAF/bot controls, quota monitoring, service-account least privilege/key recovery and production load tests remain necessary. Account data may be exported through GET /v1/account/data or the existing local JSON export. On account deletion, the Worker atomically deletes the user's progress and profile documents in one Firestore commit, before the client removes the Firebase Auth identity and local progress. Cross-service deletion is **not atomic**: if Auth deletion fails, cloud data was already erased, and retry is needed. Deploy Firestore rules **before** Worker code to avoid rejecting the profile deletion of older clients. Authentication and CORS alone cannot prevent quota-exhaustion attacks. Do not treat this backend as a completed security audit.

## Free-tier boundaries

As checked on 2026-09-22, Firebase Storage requires Blaze, including continued access to existing buckets. The MVP therefore does not use it. Firebase Cloud Functions are also not a deployment dependency. Workers Free has a per-request CPU budget, so we do not run model inference, parse PDFs or generate audio in a request. Generation happens in the connected AI client; any model subscription or API charges are separate from app hosting.

Official references:

- https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024
- https://firebase.google.com/docs/firestore/quotas
- https://firebase.google.com/docs/firestore/use-rest-api
- https://firebase.google.com/docs/reference/rest/auth
- https://firebase.google.com/docs/firestore/security/rules-fields
- https://developers.cloudflare.com/workers/platform/limits/
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports

## Verification scope

The dependency-free Node suite covers content validation, atomic release behavior, conflicts, rollback, MCP negotiation, permissions, public paths, request size, progress ownership routing and Firestore commit construction. Flutter tests cover bundled content, review scheduling, deterministic merges, content integrity/fallback, session snapshots, offline progress, account separation, retry and basic widget flows. GitHub Actions runs these and platform builds. These tests use mocks for external services; deployment, real credentials, IAM, real-device rendering and SDK-level interoperability still require an integration smoke test.

Generated platform runners use the pinned Flutter SDK in CI. Desktop artifacts initially use demo configuration. No signed iOS package or production Android signing key is supplied. A resolved pubspec.lock is uploaded as a CI artifact; check it into the repository after the first successful dependency resolution to make later builds reproducible.

## Optional verified-email enforcement

Set the Worker environment variable `REQUIRE_VERIFIED_EMAIL = "true"` to reject progress POST and profile PUT requests from accounts whose email has not been verified by Firebase Authentication. The Worker obtains verification status through server-side `accounts:lookup`; the client cannot assert it. Existing progress reads and deletion remain available, so unverified users can access or remove their own data. This is an opt-in rollout flag; after enabling it, update onboarding and verification messaging and ensure federated-account behavior is covered by live tests. Registration, login and local offline progress remain available. This policy does not replace rate limiting or account deletion recovery.

## Account endpoints (v1)

All endpoints in this section require a Firebase ID token in `Authorization: Bearer <id-token>` and use `Cache-Control: no-store`. The UID is obtained from Firebase, never from client JSON.

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/v1/me` | Safe identity summary (UID, email, verified flag, display name, provider IDs); excludes credentials |
| GET | `/v1/progress` | Current progress map and update-time version |
| POST | `/v1/progress` | Validate progress and create/update with optimistic concurrency |
| GET | `/v1/profile` | Learner-controlled profile and update-time version |
| PUT | `/v1/profile` | Create/update profile with optimistic concurrency |
| GET | `/v1/account/data` | JSON export of the user's own progress and profile |
| DELETE | `/v1/account/data` | Atomically delete the two Firestore account documents; does not delete Firebase Auth identity |
| DELETE | `/v1/progress` | Backward-compatible account-data deletion for older clients (both progress and profile) |

`PUT /v1/profile` accepts `{"profile":{"displayName":"Learner","languageCode":"zh","appearance":"system"},"version":null}` on first creation. For later updates, obtain the `version` from GET and pass it back; stale versions return HTTP 409. Only these three presentation fields are persisted; **never** put roles, subscriptions, privileges or payment state into user-writable profile documents. The profile's display name is separate from Firebase Authentication's authoritative display name until the client explicitly integrates them.

`GET /v1/account/data` includes only the authenticated user's email, progress, profile and document versions. The existing Flutter client still uses Firebase Authentication APIs for registration, sign-in and identity deletion. The Worker is a data/authentication proxy, **not** a replacement identity provider.

## Rate limiting and rollout

The Worker config defines three Cloudflare `[[ratelimits]]` bindings. `AUTH_LOOKUP_RATE_LIMITER` is keyed by the Cloudflare-provided edge IP (600/minute) before Firebase account lookup, if available; `USER_RATE_LIMITER` is keyed by server-resolved UID (120/minute); and `MCP_RATE_LIMITER` is keyed by the authenticated editor/publisher role (60/minute). HTTP 429 responses include `Retry-After: 60`. For campuses or shared NAT networks, watch false positives on the ingress limit and adjust it. No in-memory rate counter is used for security, and a missing binding means the limiter is not active. Namespace IDs in `wrangler.toml` must not overlap unrelated bindings in the same Cloudflare account.

`REQUIRE_VERIFIED_EMAIL` defaults to false so existing accounts remain compatible. Turn it on using the GitHub Actions variable `REQUIRE_VERIFIED_EMAIL=true` once onboarding, resend-email verification and live integrations are checked. The worker verifies identity through Firebase Authentication `accounts:lookup`, not a client-provided email flag. **Important:** owner-authorized direct Firestore REST writes are still possible under the current security rules, so the optional verification policy governs **Worker API writes** and is not a blanket Firestore-wide policy. Changing this would require an explicit Firestore Rules rollout. The actual deletion of Firebase Auth identities remains a separate client operation.

Before deploying the Worker, deploy the updated `firebase/firestore.rules` and indexes. The Deploy Cloud workflow enforces this order automatically. Local mock tests do not replace Firebase Rules emulator or live multi-user deletion tests.
