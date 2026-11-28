# PR Review: #4 — POS 2.3: performer selector from staff_public (no PIN)

**Reviewed**: 2026-11-05
**Author**: GaryCharbel
**Branch**: feat/pos-performer → develop
**Decision**: APPROVE with comments (posted as a comment review — GitHub blocks self-approval)

## Summary
Adds the performer selector: a rates-free `StaffMember` model from `staff_public`, an active-only
`staffPublicProvider`, `ActiveStaffController` for the default performer, and a picker screen wired
into the home shell. No PIN (Stage 1.5 deferred). Clean, small, well-paired with a model + widget test.

## Findings

### CRITICAL
None

### HIGH
None

### MEDIUM
None

### LOW
1. **Stale active performer after deactivation** — `ActiveStaffController` isn't reconciled against the
   active list; a performer deactivated mid-shift stays selected and could be credited on new lines.
   Reconcile on refresh (defer to Phase 4 ticket wiring).
2. **`/performer` + home not role-gated** — reachable by any authenticated session; RLS mitigates
   (client reads `staff_public` → zero rows → empty state). Acceptable for Stage 1.
3. **Error state has no retry button** — copy says "try again" but offers no control; add a
   `ref.invalidate(staffPublicProvider)` button (Rule #7: errors actionable).

## Validation Results

| Check | Result |
|---|---|
| Analyze | Pass (local) |
| Lint | Pass (analyze) |
| Tests | Pass — 10 (local) |
| Build | CI (windows + apk) |

## Files Reviewed
- lib/features/staff/staff_member.dart — Added
- lib/features/staff/staff_repo.dart — Added
- lib/features/staff/ui/staff_switch_screen.dart — Added
- lib/features/shell/ui/home_screen.dart — Modified
- lib/router.dart — Modified
- test/staff_member_test.dart — Added
- test/staff_switch_test.dart — Added
