# Architecture and operational boundaries

## Responsibilities

- Flutter: precompiled flashcard/MCQ renderers, responsive UI, review schedule, local small-data cache and Firebase Auth REST client.
- Worker: authenticated MCP control plane, validation, Google OAuth service-account exchange, Firestore REST adapter, public read API and user-token progress proxy.
- Firebase Auth: user identity. Firestore Standard: drafts, immutable releases, manifest, audit records and per-user progress. Classic Hosting: compiled Flutter Web assets.

Firestore documents store one `payload` JSON string. The content bundle is bounded to 128 KiB, below the Firestore document limit. Index exemptions are included. This is a minimal full-bundle design, not the future scalable question-per-document/delta-sync design.

## Security

Editor and publisher secrets are independent. Origin allowlisting is enforced before MCP execution. No client may supply a Firestore document path. IDs are validated. Only public manifest/release responses enter edge cache. User data and MCP responses are `no-store`. Anonymous users cannot read cloud progress. The progress UID comes from verified Firebase account lookup, not request JSON. The exact user ID token is passed to Firestore so Security Rules still apply; content administration uses the service account and bypasses Rules, so protect and rotate that key.

Progress is a revision-keyed map. The most recent review timestamp wins; an equal-timestamp deterministic tie-break ensures convergence. Firestore update-time preconditions prevent concurrent snapshot overwrites. This is not a review-event log or a mergeable attempt counter. Device clocks can be wrong. Tokens are kept only in memory; no password or refresh token is written to shared preferences. Local study/progress cache is not encrypted by this app. Guest progress is never silently uploaded or combined with another account.

The JSON string in a user's own progress document cannot be semantically validated by Firestore Rules. The Worker validates its structure; Rules enforce ownership, exact top-level fields and size. A user bypassing the Worker can corrupt only their own progress payload. The app reports malformed sync data without replacing local state. Add structured progress documents and emulator coverage before relying on complex per-field rules.

For a public service, add tested distributed rate limits/abuse controls and registration verification, monitor quotas, review service-account least privilege and recovery, implement account deletion/export, and benchmark worst-case Worker CPU. Authentication and CORS alone do not stop quota-exhaustion attacks. Do not treat this initial backend as a completed security audit.

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
