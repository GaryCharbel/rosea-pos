# Rosea POS — Project Rules & Regulations for Claude

> **This is the `rosea-pos` repo — the Flutter desktop POS.** The Supabase backend + web apps live in the sibling **`rosea`** repo.
>
> The **backend/DB/RLS/security-at-the-database conventions, the full data model, the `pay_ticket` contract, and the design spec + implementation plan all live in `rosea` (`rosea/docs/`)** — read them before touching anything that crosses the backend contract. This file keeps only the shared golden rules + the POS-specific conventions.

Rosea is a beauty-salon platform (booking website + desktop POS + backoffice) on one Supabase backend. Owner & author: **Gary Charbel El Hadchity** (write his name in full — never abbreviate).

---

## 🔒 Golden rules (non-negotiable — shared across both repos, keep in sync with `rosea/CLAUDE.md`)

1. **RULE #1 — Nothing gets merged before a thorough review** (read the diff for correctness/security/conventions *and* runtime-test it).
2. **Never commit to `main`.** `main` is protected; branch + reviewed PR only (same for the integration branch).
3. **No AI/Claude attribution in git** (commits, branches, PRs). **Gary pushes & opens PRs himself.**
4. **Never force-push** a pushed branch; integrate by merge, not rebase+force.
5. **Review AND runtime-test every commit** — observe correct behavior, not just a green build.
6. **Pair backend + frontend per feature** and test the pair end-to-end before the next feature.
7. **Every error message is actionable** — what happened + what to do. Never a generic "unexpected error."
8. **Anything that can be automated, should be automated** (tests/lint/builds/releases/contract-sync via scripts/hooks/CI, not manual steps).
9. **CI on every PR + every push to a PR:** build the app + run the full test suite; **red build/tests block the merge.** Write unit tests for all logic; never skip/disable tests.
10. **Security & data confidentiality are first-class** (see POS security notes below; DB-side rules live in `rosea`).
11. **Speed, reliability, and data correctness come first** — priority stack **correctness → reliability → speed → features**.

---

## POS-specific conventions

**Stack & structure**
- Flutter, Dart. **Targets Windows (desktop) AND Android (APK)** from one codebase. State management and folder structure per the spec in `rosea/docs/`. Keep platform-specific code behind abstractions (e.g. receipt printing) so both targets build cleanly.
- `supabase_flutter` for data/auth. The app uses the **anon key + the signed-in user's JWT** — gated by RLS. **The `service_role` key NEVER ships in this app** (Golden Rule #10).

**Backend contract**
- All money-affecting writes go through the **`pay_ticket` Postgres function via `supabase.rpc('pay_ticket', …)`** — never ad-hoc multi-row writes from the client. The function is atomic + idempotent (defined in `rosea`); the client just calls it and handles the result/retry.
- Dart models mirror the Supabase schema (the **single source of truth in `rosea`**). When the schema changes there, **regenerate these models and PR them** — automate the generation so the contract never drifts (Rule #8).

**Reliability at the counter (light resilience — NOT full offline)**
- Cache the catalog + staff locally so a WiFi blip doesn't blank the screen.
- Queue the `pay_ticket` call and retry with backoff if briefly offline. Surface clear state ("saved / syncing / retrying") — **never silently lose a sale.** A sale finalizes once reconnected; there is no offline selling engine.
- Validate before sending so bad data can't be submitted.

**Performance**
- Checkout and catalog must feel instant (target: add-line / pay feel sub-100ms on the UI).
- **Zero N+1** — fetch sets in one round-trip (joins / `in (…)` / embedded selects), never a query per row in a loop. Always check the **big-O** of hot paths and pick the best achievable. Checked on every PR review.

**UI**
- **Never look light or flat.** Bold figures, elevated cards, strong hierarchy, high contrast (the KPI-card style). No washed-out gradients that band on screens.

**Errors**
- Actionable messages for the real POS failure modes: network/offline, RLS denial (permission), validation, and a failed/duplicate payment. Tell the user what to do (e.g., "Offline — the sale is queued and will finish when you're back online.").

## Testing & CI (this repo)

- **`flutter test`** — widget + unit tests for ring-up, per-line performer, split payment + tips, and the offline/retry (outbox) path. Write tests as you build each feature (Rule #9).
- **Integration tests** for the checkout → `pay_ticket` flow against a **local Supabase** (started from the `rosea` repo).
- **PR CI** (`.github/workflows/`): on every PR/push — `flutter analyze` + `flutter test` + verify **both** targets build (`flutter build windows` and `flutter build apk`). Red = no merge.
- End-to-end commission check before "done": ring up a multi-line ticket with two different performers + a discount, pay split, and confirm the backend recorded the right `commission_entry` rows.

## Release & distribution (automated — Rule #8)

- On each **release** (tag / merge to the release line — never on `main` directly), CI builds the two artifacts:
  - **Android APK** (`flutter build apk --release`)
  - **Windows build** (`flutter build windows --release`, zipped)
- CI then **uploads both artifacts to the designated MEGA folder** (via MEGAcmd / `megatools`). This is the distribution step — fully automated; no manual uploading.
- **MEGA credentials live in CI secrets only** — never in git or the app (Golden Rule #10). Name the artifacts with the version/build so the MEGA folder stays sortable (e.g. `rosea-pos-<version>-windows.zip`, `rosea-pos-<version>.apk`).
- Keep the PR build (above, just "does it build") separate from this release job (actually produces + ships artifacts) so PRs stay fast and artifacts aren't uploaded on every push.
