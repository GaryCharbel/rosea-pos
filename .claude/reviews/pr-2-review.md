# PR Review: #2 — POS 2.2 (1/2): supabase_flutter + actionable AppError

**Reviewed**: 2026-11-05
**Author**: GaryCharbel
**Branch**: feat/pos-login → develop (head 43d6213)
**Decision**: APPROVE (posted as a comment review — GitHub blocks self-approval)

## Summary
Small, clean foundation slice: the Supabase dependency, a sealed actionable `AppError` with `mapAuthError()`, and config-independent unit tests. CI is green on all three jobs. One LOW note.

## Findings

### CRITICAL / HIGH / MEDIUM
None. No secrets (anon key + user JWT via env, no service_role), no hardcoded config, actionable messages per Golden Rule #7, tests don't require real config.

### LOW
- `mapAuthError` maps every non-`AuthException` to a connectivity message ("Could not reach Rosea. Check your internet connection…"), lines 41–43. For the sign-in path that's the most likely cause and it's actionable, but a genuine non-network bug during sign-in would be mislabeled as connectivity. Acceptable for now; if the pay-path mapper (4.6) or a shared mapper later needs to distinguish, split out a `NetworkError` vs a true-unexpected branch. Optional.

## Validation Results

| Check | Result |
|---|---|
| analyze (`flutter analyze`) | Pass (CI) |
| test (`flutter test`) | Pass (CI) |
| build apk | Pass (CI) — Supabase dep builds on Android, no Gradle/minSdk bump needed |
| build windows | Pass (CI) |

(Flutter can't run on the dev box — the TLS large-download issue — so validation is the rosea-pos CI, which is green.)

## Files Reviewed
- `pubspec.yaml` — Modified (add supabase_flutter ^2.5.0)
- `lib/core/errors/app_error.dart` — Added
- `test/app_error_test.dart` — Added
