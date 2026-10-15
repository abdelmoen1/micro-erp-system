# Sprint 1 — Progress report

Branch `sprint-1` (from `main @ 71c9d17`). **Nothing is committed or pushed yet**: all work is in the working tree, so CI has never run. Plan: [14-sprint-1-execution-plan.md](proposed/14-sprint-1-execution-plan.md).
Last updated: 2026-10-13.

## Status by story

Legend: **Done** = deliverable exists and its tests pass locally · **Review** = waiting for a TL design review · **Blocked** = needs an external input · **Partial** = some acceptance criteria still open.

### A — Backend (+ React)

| Story | Status | Evidence |
|---|---|---|
| US-0106 API v1 + envelope + contract freeze | Done | `ApiConventionsTest` (old prefix 404, envelope, 500 logged with correlation id); contract [docs/api/auth.http](../api/auth.http) + [error-codes.md](../api/error-codes.md), guarded by `ErrorCodeContractTest` (fails if a thrown code is undocumented or a documented code is gone; mutation-checked) |
| T-0106-5 React → `/api/v1`, DEF-12 | Done locally | TC-0106-04: `oxlint` exit 0 (2 DEF-17 warnings allowed until S3), `vite build` OK. TC-0106-05: `frontend/scripts/smoke-login.mjs` drives headless Chrome → `/api/v1/login` → `/dashboard`, token stored: **PASS**. CI job written, not yet run. |
| US-0108 MySQL parity, CI, isolation sweep | Partial | `phpunit.mysql.xml`, `.env.testing`, `_test` DB guard (`TestDatabaseGuardTest`), `StoreIsolationSweepTest`. Parity run on local **MariaDB 10.4** (XAMPP), not MySQL 8; MySQL 8 runs only in CI. `.github/workflows/ci.yml` (sqlite, MySQL 8, web, mobile jobs) — **unverified until pushed** (TL to confirm GitHub Actions). |
| US-0101 Idempotency | Done | `IdempotencyTest` (replay = one record + identical response over every financial endpoint; 428 / 409 / 422) |
| US-0102 Exact money | Done | `MoneyTest`, `MoneyHandlingTest` (bcmath, string money, `meta.currency = ILS`) |
| US-0103 Audit log | Done | `AuditLogTest` |
| US-0104 Auth hardening | Done | `AuthHardeningTest` (6th attempt → 429 + Retry-After, 30-day expiry → 401, production debug guard) |
| US-0105 Role matrix + deactivation | Done | `RoleMatrixTest` (full matrix incl. D-12 employee pay-all, DEF-05 containment), deactivation replaces DELETE |
| US-0107 Store timezone | Done | `StoreTimezoneTest`, `BusinessClock`; default `Asia/Gaza` (D-23) |
| US-0109 SRS verification | **Blocked** | D-28: SRS v1.1 PDF is not in the repo (`documemtation/SRS.pdf` is the older version). A PDF text tool **is** available (`pdftotext`). Traceability is **not** verified. |

**Backend suites (2026-10-13, after restoring the files lost in the rewind — see Incidents):** sqlite **130 / 130** (586 assertions), MariaDB 10.4 **130 / 130** (587 assertions).

### B — Flutter (`mobile/`, `com.hisbah.smartshop`)

| Story | Status | Evidence |
|---|---|---|
| US-1302 Environment + devices | Partial | Flutter 3.47.7, JDK 17, Android SDK 36/37 installed ([environment.md](../mobile/environment.md)). `flutter doctor`: Android toolchain OK. **APK not built yet:** the build needs Android NDK 28.2.13676358, which AGP cannot auto-install (deprecated `sdkmanager`); the NDK (748 MB) is downloading at ~40 KB/s, after which the debug and release builds run automatically. **No phones connected** → TC-1302-01–03 not run. |
| US-1303 Project foundation | Done (nav order pending DR-1) | Feature-first structure, Arabic + RTL via `gen-l10n`, go_router 5-tab shell, Riverpod scope, neutral theme. TC-1303-01 boot, TC-1303-02 RTL pass; TC-1303-03 `flutter analyze`: **No issues found** |
| US-1304 API client | Done | TC-1304-01: every envelope code → typed failure (23 cases); TC-1304-02: idempotency key survives restart |
| US-0205 Mobile session | Done (functional; styling waits for DR-2) | TC-0205-01 restore / 401 / logout + widget tests for every login state (validation, invalid credentials, throttled countdown, deactivated, network, server error, offline banner) |
| US-1305 Barcode spike | **Blocked** | Needs the two phones and ~20 real barcodes. G-FL cannot be assessed without it. |
| US-1306 Integration + Flutter CI | Partial | The six scenarios (TC-1306-01–06) **pass on the host against the real local API** (`test/live`); the **phone run** (`integration_test/`) is pending hardware. CI job written, not run. |

**Flutter suite:** `flutter test` **59 / 59**; live scenarios **6 / 6** (host).

### C — Mobile UI/UX ([docs/design](../design/README.md))

| Story | Status | Evidence |
|---|---|---|
| US-1505 IA + state matrix | Review (DR-1) | [ia.md](../design/ia.md): every real auth response mapped to a screen state |
| US-1502 POS flow low-fi | Review (DR-1) | Frames 12–21 in [lowfi-s1.html](../design/wireframes/lowfi-s1.html). Prototype + staff test (P4) not started; needs 2–3 shop staff |
| US-1507 Auth + shell | Low-fi in review (DR-1); hi-fi after the DR-2 direction pick | Frames 01–11 |
| US-1501 Design-system foundation | Draft for DR-2 | [tokens.json](../design/tokens.json), [design-system.md](../design/design-system.md), contrast report generated from tokens: **58 / 58 pairs pass** (the checker caught and forced fixes for 3 failing pairs) |
| US-1506 Two visual directions | Review (DR-2 part 1) | [directions.html](../design/mockups/directions.html): A · Ledger, B · Counter, built with the real wordmark and app icon |

**Visual styling in Flutter is paused until DR-2 sign-off**, as instructed.

## Defects assigned to Sprint 1

Fix and regression test exist on the branch. None is **Closed**: rule 09 §12.1 needs a merge and a CI run link.

| Defect | Regression test |
|---|---|
| DEF-02 duplicate payments | `IdempotencyTest` |
| DEF-03 float money | `MoneyHandlingTest`, `MoneyTest` |
| DEF-04, DEF-09 roles / hard delete | `RoleMatrixTest` |
| DEF-05 (containment only; full fix US-0503) | `RoleMatrixTest` |
| DEF-07 UTC dashboard | `StoreTimezoneTest` |
| DEF-08 throttling / expiry | `AuthHardeningTest` |
| DEF-12 React login | `smoke-login.mjs` + `oxlint -D no-undef` |
| DEF-14 swallowed exception | `ApiConventionsTest` |
| DEF-15 debug in production | `AuthHardeningTest` (guard). The local `backend/.env` itself still has `APP_ENV=production` + `APP_DEBUG=true`; it was not edited (secrets file). |
| DEF-16 sqlite-only tests | MariaDB run via `phpunit.mysql.xml`; MySQL 8 in CI (unverified) |

**New:** DEF-19 (P2) — Laravel validation messages are English (`APP_LOCALE=en`, no Arabic translations). Found during the contract freeze; mitigated on mobile by local Arabic validation; proposed for S3.

## Waiting for the TL

1. **DR-1** — [reviews/DR-1.md](../design/reviews/DR-1.md), including Q1: POS as the centre tab (differs from 06).
2. **DR-2 part 1** — [reviews/DR-2.md](../design/reviews/DR-2.md): direction A or B, typeface (UI-D2), digits (UI-D1).
3. **External inputs:** two Android phones + cables (US-1302, US-1305, US-1306); ~20 real barcodes (US-1305); 2–3 shop staff for 15 minutes (US-1502 test); SRS v1.1 PDF committed (US-0109); GitHub Actions enabled, and permission to commit and push so CI can run.

## Effort and pace (k)

The pace factor k (G-FL) needs **developer** hours. AI-assisted session time is not comparable, so k is **not computed**. Please record the TL / developer hours spent reviewing and running device steps; G-FL stays **not assessed** until US-1305 and the phone runs exist.

## Incidents

- **2026-10-13 — checkpoint rewind.** A conversation rewind silently reverted the 26 files written with the editor tools (new tests, CI workflow, smoke script, auth and dashboard services), while shell-made edits survived. The app was half-reverted. All 26 files were rebuilt exactly from the session transcript, the v0.4 documentation sync was re-applied, and both backend suites were re-run (results above).
