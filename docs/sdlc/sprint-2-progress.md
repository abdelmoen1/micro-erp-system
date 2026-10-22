# Sprint 2 — Progress report

Scope: [07 §S2](proposed/07-milestones-and-sprints.md) (M2 Catalog & Sales Core). Stories: [08](proposed/08-user-stories-and-technical-tasks.md).
Last updated: 2026-10-22 (S2 close work on branch `feat/s2-sales-core`). Requirements baseline: SRS v1.1 is still **not in the repository** (D-28; `documemtation/SRS.pdf`
is the older version), so traceability stays provisional, as in Sprint 1.

Legend: **Done (PR)** means the code and tests exist and pass locally and in CI, and are waiting for review and merge.
**Blocked** means it needs a TL decision or an external input.

## Status by story

| Story | Status | Evidence |
|---|---|---|
| US-0401 Product catalog + barcode lookup | Done (PR #5) | `ProductCatalogTest` TC-0401-01…06; isolation sweep covers `{product}` |
| US-0402 Stock movements + adjustments | Done (PR #6, stacked on #5) | `StockAdjustmentTest` TC-0402-01…04, invariant over a sequence, `hisbah:verify-stock`; idempotency replay matrix includes `POST /stock-adjustments` |
| US-0403 Low-stock detection | Done (PR #6) | `LowStockTest` TC-0403-01…03 |
| US-1301 remainder T-1301-7 (scan → lookup) | Done (branch `feat/t-1301-7-scanner`), pending device test and design approval | Data layer (PR #6) plus S2 hi-fi states A–H ([docs/design/s2-scanner](../design/s2-scanner/README.md)) on mobile_scanner + permission_handler behind `BarcodeCamera`; `test/features/scanner_test.dart` (D, E, F, G, H, 130% text). Needs a full release (native plugins, version 1.0.0+2). Open: U-1…U-10, camera tokens pending approval, US-1305 spike |
| US-0305 Customer credit limit | Done (PR #7): storage and role gate only | `CustomerCreditLimitTest` TC-0305-01/02; role matrix row. Enforcement is US-0502 |
| CR-13 (modified) weighed goods | Done (branch `feat/s2-sales-core`, not yet a PR) | `products.unit` piece/kg, DECIMAL(12,3) quantities, quantity strings in the API; `WeighedProductTest`; Flutter `Product` parses both the new strings and the old integers |
| US-0701 Debt schema extension | Done (branch `feat/s2-sales-core`) | `customer_id` backfilled from the invoice (the migration stops and names any debt it cannot resolve), `due_date`, `return_credit`; `DebtSchemaExtensionTest` (backfill 3/3, refusal, rollback, fields); `php artisan hisbah:verify-debts` reports coverage on real data |
| US-0501 Cash sale with stock deduction | Done (branch `feat/s2-sales-core`) | `POST /sales`, `SaleService`; D-27 as approved: shortfall sold with `NEGATIVE_STOCK` (AC2 of the story is superseded); `SaleTest` TC-0501-01…06 |
| US-0502 Credit / partial sale | Done (branch `feat/s2-sales-core`) | D-26 as approved: employee 422 `CREDIT_LIMIT_EXCEEDED`; owner/manager 422 `CREDIT_LIMIT_CONFIRMATION_REQUIRED`, then `confirm_over_limit` (audited); `SaleTest` TC-0502-01…06 |
| US-0503 Invoice immutability and void | Done (branch `feat/s2-sales-core`) | Notes-only PATCH (`INVOICE_IMMUTABLE`), no DELETE route, `POST /sales/{id}/void` (alias `/invoices/{id}/void`), exact stock restore, debt `cancelled`, audit, 409 on a second void; `SaleTest` TC-0503-01…06; old invoice tests rewritten |
| US-0505 Cart state (start) | Partly done (branch `feat/s2-sales-core`) | Non-visual only: exact money/quantity types, `Cart`, `RepeatScanGuard` (1.5 s from the last sighting), `CartController`, `SaleRepository` with persisted key; `test/features/cart_test.dart`. Screens M-02/M-04/M-05/M-06 wait for approved designs; device timing not run (no phone attached) |
| US-1201 start (web) | Partly done (branch `feat/s2-sales-core`) | `apiClient.js` (envelope, `ApiError`, 401 handling, `Idempotency-Key` with same-key retries), TanStack Query provider + query keys. RTL shell (W-04) waits for the approved design |
| DEF-13 register wiring | Fixed (branch `feat/s2-sales-core`) | `Register.jsx` calls `POST /register`, maps field errors; Playwright `e2e/auth.spec.js` (fails on the old code, passes on the fix) |
| D-32 Playwright proof | Done locally; CI step added | 3 tests (login + 2 DEF-13) pass locally with installed Chrome; CI installs bundled Chromium |
| US-1502 POS / checkout wireframes | In S1 review (DR-1) | |

Verification on 2026-10-22: backend 204 tests pass on sqlite and on MariaDB 10.4 (local stand-in for the CI MySQL 8 job, which has not run on this branch yet);
the four new migrations go down and up cleanly on MariaDB; `flutter analyze` clean, `flutter test` 110 passed / 6 skipped; web oxlint 0 errors and `vite build` OK.

**Deployment order:** the API now sends quantities as strings, which the installed app (release 1.0.0+1) cannot parse in barcode lookup.
The 1.0.0+2 full release has not been run yet (last Mobile release run: 2026-10-16, 1.0.0+1). Build 1.0.0+2 from a `main` that already
contains this branch's Flutter `Product` change, install it, and only then deploy the backend. The new app also accepts the old integers.

## CI (GitHub Actions, `CI` workflow)

| Job | State on feature branches | Cause |
|---|---|---|
| Mobile analyze and test | Pass | — |
| Backend tests (sqlite) | Pass | — |
| Backend tests (MySQL 8) | 2 failures, both `AuditLogTest` | Baseline on `main`: the JSON metadata assertions depend on key order. Fixed in PR #3 |
| Web lint and build | Fail | Baseline on `main`: Footer asset import has the wrong filename case. Fixed in PR #3 |

Merging PR #3 first makes every job green. New stories add no failures. On MySQL 8, PR #6 runs 156 tests: 154 pass and the 2 failures are the baseline ones.

## Decisions needed (TL)

- **D-06, D-07, D-08, D-10, D-26, D-27** (doc 03, Part 3): every S2 sale story waits for these.
- **CR-13** (integer quantities): implemented as integers, following the story ACs and doc 05. Fractional or weighted goods would need a migration.
- **US-0402 open point:** adjusting an *inactive* product is currently allowed, because the story sets no rule.
- **D-28:** commit the SRS v1.1 PDF so the traceability can be verified (US-0109).

## External inputs still needed

- Phone install of the Shorebird baseline 1.0.0+1 (see [ota-updates.md](../mobile/ota-updates.md) §2.5). The OTA patch acceptance test waits for it.
- The first owner account on the live API (`backend/tool/deploy/register_owner.ps1`).
- About 20 real barcodes and the phones for the US-1305 scanner spike.
