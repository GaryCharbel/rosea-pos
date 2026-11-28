# PR Review: #3 — POS 2.2 (2/2): Supabase init + session + login + router

**Reviewed**: 2026-11-05
**Author**: GaryCharbel
**Branch**: feat/pos-login-session → develop (head c4d3a5f)
**Decision**: APPROVE WITH COMMENTS (posted as a comment — GitHub blocks self-approval)

## Summary
Clean, idiomatic login slice: Riverpod sealed `SessionState`, go_router session redirect, actionable error copy, no secrets. One MEDIUM: an async race in `_resolve` that can leave a stale `Authenticated` state. A few LOWs.

## Findings

### CRITICAL / HIGH
None. (No secrets — publishable key via env, no service_role; profile read is RLS-gated; `SessionState` correctly avoids the `supabase_flutter` `AuthState` name clash.)

### MEDIUM
- **Stale-resolve race in `SessionController._resolve` (session_controller.dart ~64–75).** After the `await` on the profiles fetch it sets `Authenticated` unconditionally. If auth changes during that await (e.g. sign-in immediately followed by sign-out, or rapid token events), a slow in-flight `_resolve(session)` can complete *after* a newer `_resolve(null)` and overwrite `Unauthenticated` back to `Authenticated` — UI shows signed-in while actually signed out. Guard it: after the await, bail if the session is no longer current, e.g. `if (_client.auth.currentSession?.user.id != session.user.id) return;` (or a generation counter).

### LOW
- `_resolve` runs on **every** `onAuthStateChange` event (including `tokenRefreshed`) *and* once directly in `build()` plus again via the `initialSession` event — so startup does the profiles query twice and every token refresh re-queries. Fine functionally; consider resolving only on signed-in / signed-out / initial-session.
- A returning (persisted-session) user briefly sees the **login screen** during `SessionLoading` (the redirect returns null, so it stays at `/login`). A tiny splash/loading route for `SessionLoading` avoids the flash.
- The inline sign-in error `Text` isn't exposed as an a11y live region; wrapping it so screen readers announce it would be a nice touch.

## Validation Results

| Check | Result |
|---|---|
| analyze | Pass (local `flutter analyze` — no issues) |
| test | Pass (local `flutter test` — 6 tests) |
| build apk | CI pending (pure-Dart deps added; expected green as in increment 1) |
| build windows | CI pending (expected green) |

## Files Reviewed
- `lib/core/supabase/supabase_init.dart`, `lib/features/auth/session_controller.dart`, `lib/features/auth/ui/login_screen.dart`, `lib/features/shell/ui/home_screen.dart`, `lib/router.dart` — Added
- `lib/main.dart`, `test/widget_test.dart`, `pubspec.yaml` — Modified
