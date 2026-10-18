# Sprint 2 — Progress report

Scope: [07 §S2](proposed/07-milestones-and-sprints.md) (M2 Catalog & Sales Core). Stories: [08](proposed/08-user-stories-and-technical-tasks.md).
Last updated: 2026-10-17. Requirements baseline: SRS v1.1 is still **not in the repository** (D-28; `documemtation/SRS.pdf`
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
| US-0701 Debt schema extension | **Blocked**: D-10 open | It changes and backfills the production schema, so it waits for approval |
| US-0501 Cash sale with stock deduction | **Blocked**: D-06, D-07, D-27 open | Needs immutability (D-06), walk-in (D-07) and stock policy (D-27) decisions |
| US-0502 Credit / partial sale | **Blocked**: D-08, D-26, D-27 open, plus US-0701 | |
| US-0503 Invoice immutability and void | **Blocked**: D-06 open | |
| US-1502 POS / checkout wireframes | In S1 review (DR-1) | |

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
