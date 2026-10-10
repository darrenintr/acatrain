# ACATRAIN 2.0 — Incremental architecture roadmap

Branch: `2.0`. Base: main at `81b891cc9057f3b43a90ff8e1b0d26238b1ec122` (2026-10-10).

## Scope of the first implementation

- Keep `lib/main.dart` as the tiny Flutter entry point and a backward-compatible export surface for existing tests.
- Move app startup into `lib/app/bootstrap.dart`, app configuration into `lib/app/acatrain_app.dart`, and reusable theme/font definitions into `lib/core/design_system/acatrain_theme.dart`.
- Move the current app shell into `lib/features/shell/presentation/home_shell.dart` without changing its interaction logic yet.
- Separate the sign-in sheet into `lib/features/auth/presentation/auth_sheet.dart` without altering authentication behavior or token storage.
- Add a regression test for the new public entry point and theme tokens.

These are **structural changes, not a complete UI redesign**. The large HomeShell is an intentional transitional module; split Today, Library, Review, Settings, responsive navigation, and shared widgets one feature at a time in follow-up PRs.

## Architecture target

```text
App / Bootstrap
  -> Feature presentation + small controllers
  -> Domain services (review scheduler, session handling, sync coordinator)
  -> Repositories (auth, content, progress, settings)
  -> Local cache and authenticated remote adapters
```

## Non-negotiable compatibility rules

1. Do not change the content schema, review scheduling, account identity logic, offline cache keys, or progress serialization as part of UI extraction.
2. Do not overwrite or silently merge guest progress into a signed-in account.
3. Keep current UI behavior, supported locales, haptics, high-refresh display setup, reduced-motion semantics, and cross-platform entry points.
4. New data migrations must support old local caches and provide rollback/recovery coverage.
5. Account deletion hardening in [PR #13](https://github.com/darrenintr/acatrain/pull/13) is still separate until its Firestore rules, Worker, and real-device checks are validated. Do not mark the account-security work complete merely because a new UI exists.
6. Keep simulated checkout clearly labeled as a demo. Do not create real billing entitlements from local demo preferences.

## Subsequent milestones

1. **Navigation + design system:** extract destinations, dedicated responsive navigation, shared loading/empty/error/offline components, and golden tests.
2. **Learning features:** separate Today, Library, Set, Flashcards, Quiz, Match, Review, and Settings screens while preserving study-state semantics.
3. **State/repositories:** gradually split `AppStore` through adapters and feature-level state; avoid a simultaneous storage or auth rewrite.
4. **Offline engine:** add durable pending operations, conflict tests, scoped account data migrations, and content-set incremental release planning.
5. **Release hardening:** integration tests with Firebase Emulator, platform accessibility, deep links, CI checks, and performance baselines.

## Validation for this first implementation

- `flutter analyze --no-fatal-infos`
- `flutter test`
- `npm test --prefix backend/worker`
- Phone/tablet/desktop widget smoke tests, account sign-in, sync, and deletion checks before any production deployment.

The structural extraction itself should not require backend changes. Production deployment is intentionally out of scope for the first branch commit.
