# PR Review: #12 — feat(checkout): redesign to match the reference (responsive 3-pane)

**Reviewed**: 2026-11-28
**Author**: GaryCharbel
**Branch**: feat/checkout-redesign → develop
**Decision**: APPROVE (with comments)

## Summary
Checkout redesign to the delivered mockups: responsive category selector (vertical icon rail ≥560px / horizontal chip strip on phones), tinted item grid with pink prices + "Title · N items" header, amber offline banner moved to the bottom, and the pop-up `PaymentSheet` replaced by an inline payment composer in `ticket_panel.dart`. `CatalogSection` gains an `id` (category id or `__services`/`__products` catch-all key) to drive rail selection + tint. Also carries the repo-wide CI-drift fixes (`analyze --no-fatal-infos`, AGP 9.1.0→9.1.1). Clean, well-tested, no correctness or security issues.

## Findings

### CRITICAL / HIGH
None. `payment_sheet.dart` + its test are fully removed with no dangling references (confirmed: `build apk` + `build windows` green on the branch).

### MEDIUM
- **Maintainability — `ticket_panel.dart` responsibility creep.** Folding the payment composer, tender rows, tip picker, amount dialog, and pay-state handling into the ticket file makes it the largest file in the feature (~660 lines) with several responsibilities. Not a blocker (PRs #14/#15 later extract the tender/discount dialogs), but worth keeping an eye on; the inline composer could be its own widget file.

### LOW
- `selectedSectionIdProvider` is a non-autoDispose global `StateProvider<String?>` — the selected category persists across tickets and sign-outs. Harmless (and arguably intended), but it never resets.
- `sections.indexWhere(...).clamp(-1, sections.length - 1)` — the clamp is redundant; `indexWhere` already returns a value in `[-1, length-1]`. The `-1 → current=0` fallback correctly handles a selected id that no longer exists after a catalog refresh.
- `--no-fatal-infos` relaxes `flutter analyze`. Acceptable — warnings and errors still gate the merge, and test failures still block — but pinning the Flutter version in CI (noted as a deferred follow-up) is the cleaner long-term fix than an unpinned `channel: stable`.

### Positive notes
- Receipt/finish path now uses `onClose?.call()` instead of the old unconditional `Navigator.maybePop()` — safer on the inline desktop layout (won't pop the checkout route).
- Empty / offline-stale / error states and `Semantics(button, label)` on tiles all preserved; new narrow-chip test + updated inline-tender flow test keep coverage honest.
- Money stays integer cents throughout; no PII, no secrets, no RLS surface touched (FE-only).

## Validation Results
| Check | Result |
|---|---|
| analyze · test (CI) | Pass |
| build apk (CI) | Pass |
| build windows (CI) | Pass |
| Dangling `PaymentSheet` refs | None (tree + build verified) |

## Files Reviewed
- `.github/workflows/pos-ci.yml` — Modified (analyze flag)
- `android/settings.gradle.kts` — Modified (AGP bump)
- `lib/features/catalog/domain/catalog.dart` — Modified (`CatalogSection.id`)
- `lib/features/catalog/ui/catalog_grid_view.dart` — Rewritten (rail/chips/grid)
- `lib/features/checkout/ui/checkout_screen.dart` — Modified (overflow menu, owner gate)
- `lib/features/checkout/ui/payment_sheet.dart` — Deleted
- `lib/features/checkout/ui/ticket_panel.dart` — Modified (inline payment composer)
- `lib/router.dart` — Modified (land on /checkout)
- `test/catalog_grid_test.dart` — Modified (+ narrow-chip test)
- `test/checkout_flow_test.dart` — Modified (inline-tender flow)
- `test/payment_sheet_test.dart` — Deleted
