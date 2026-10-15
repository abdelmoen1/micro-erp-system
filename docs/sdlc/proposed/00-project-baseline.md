# 00 — Project Baseline

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL**
> Package version **0.2** (2026-10-13; v0.1 prepared 2026-10-12) · Code baseline: `main @ 71c9d17` (working tree clean) · Requirements baseline: Hisbah Smart Shop SRS v1.1, **not yet pinned in the repository** (A-09, D-28)
> v0.2 changes in this file: defect register status and closure columns, closure rule, assumptions A-05 and A-07 – A-09, corrected S1 blockers. See [CHANGELOG](CHANGELOG.md).

This document records **what is true today**. It is the starting point for every other document in this package. Each statement is labelled as one of the following:

- **Verified:** checked by running something or by direct code evidence in this session.
- **Unverified:** a claim that could not be checked.
- **Defect:** confirmed incorrect behaviour.
- **Missing:** no implementation found.

---

## 1. Source Documents

| Document | Location | Status |
|---|---|---|
| **SRS v1.1** (approved baseline, prepared 23 Sep 2026, 29 pages) | **Not in the workspace.** Provided to the planning session as an attached PDF (`Hisbah_Smart_Shop_SRS_v1.1.pdf`). | Used as the requirements baseline. **Decision D-28:** the Team Leader should commit it to the repo. |
| Older SRS | [documemtation/SRS.pdf](../../../documemtation/SRS.pdf) (committed 2026-08-02; folder name misspelled) | **Superseded**: it predates v1.1. Not used for planning. |
| Phase 0 audit report | Originally written outside the repo at `C:\Users\hp\.claude\plans\pasted-content-id-3524-hisbah-snazzy-wilkes.md`. Copied into this package as [appendix-a-phase0-audit-report.md](appendix-a-phase0-audit-report.md). | Partially superseded by this baseline (test status, confirmed defects). |

---

## 2. Repositories and Toolchain

| Item | Finding | Evidence |
|---|---|---|
| Laravel backend | **Verified present**: `backend/`. Laravel ^12, Sanctum ^4, PHP 8.2.12 (XAMPP), PHPUnit 11.5.56 | `backend/composer.json`, `php -v`, test run |
| React web | **Verified present**: `frontend/`. React ^19.2.8, react-router-dom ^7.18.3, Vite ^8.2, oxlint. `node_modules` installed | `frontend/package.json`, build run |
| Flutter mobile | **Missing** in the workspace and in sibling folders under `C:\Users\hp\Documents` (searched for `pubspec.yaml`). **Flutter/Dart SDK not on PATH.** | `find`, `which flutter` |
| MySQL | XAMPP MySQL binary present at `C:\xampp\mysql\bin\mysqld.exe`. Whether the server runs and its version are **unverified**. | `ls` |
| PHP extensions | `pdo_sqlite`, `pdo_mysql`, **`bcmath`**, `mbstring` available | `php -m` |
| Git | Branch `main`, remote `origin/main`. Extra worktree `micro-erp-system.worktrees/backend-features-testing` (branch `agents/backend-features-testing` @ `505fb3f`) has **no commits beyond `main`** but has **uncommitted** edits (`User.php`, `UserFactory.php`, an older `BackendFeatureTest.php`). | `git worktree list`, `git log main..agents/…` |
| CI / deployment | **Missing**: no workflow files, Dockerfile, or deploy scripts | repo listing |
| Postman | Empty scaffold folders only (`postman/`, `backend/postman/`) | repo listing |

> The stale worktree is left untouched. The Team Leader should decide whether to discard it (risk R-17).

---

## 3. Verified Test Baseline

### 3.1 Safety verification performed before running tests

1. `backend/phpunit.xml` sets `DB_CONNECTION=sqlite` and `DB_DATABASE=:memory:`. The lines are active, not commented out.
2. `backend/bootstrap/cache/config.php` does **not** exist, so no cached config can redirect tests to MySQL.
3. `backend/.env.testing` does **not** exist.
4. No `DB_*` or `APP_ENV` variables were set in the shell environment.
5. For extra safety, the database variables were also set explicitly on the command line.

### 3.2 Backend suite: **PASS**

```
Command : APP_ENV=testing DB_CONNECTION=sqlite DB_DATABASE=:memory: php vendor/bin/phpunit --do-not-cache-result --testdox
Result  : OK (15 tests, 155 assertions) — 0 failed, 0 skipped — 31.7 s
```

The "7 failures" recorded in the old `.phpunit.result.cache` were **stale**. All 13 feature tests pass:

- **Backend feature tests:** auth, roles/invitations, customers, invoices, debts/payments/reversal/pay-all, user policy, role matrix, invoice conversion, opening debt.
- **Dashboard feature tests:** 4 tests.

> **Caveat:** some passing tests **assert behaviour that the SRS forbids**. For example, `test_invoices_totals_debts_update_delete_and_isolation` asserts that a cash invoice can be edited and then hard-deleted (contrary to BR-07 and FR-31). These assertions must change under US-0503 (decision D-06).

### 3.3 Defect probes (scratch tests outside the repo; no repository file was changed)

A temporary test file was run from the session scratchpad against the same in-memory database. Its source is reproduced in [Appendix 1](#appendix-1--probe-test-source) so the probes can become regression tests in Sprint S1.

| Probe | Observed result | Defect |
|---|---|---|
| Convert a credit invoice to cash, then `DELETE /api/invoices/{id}` | **HTTP 500** | DEF-01 confirmed |
| Submit the same payment twice | **201, 201 → 2 payments recorded** | DEF-02 confirmed |
| Pay `59.999` against a debt of `60.00` | **201**; `remaining_amount = 0.00099999999999767`, status `partially_paid` | DEF-03 confirmed (sqlite; MySQL behaviour unverified, see DEF-16) |
| Owner calls `PATCH /api/users/{employee}/role` with `role=owner` | **200**; the employee becomes an owner | DEF-04 confirmed |
| Employee changes a 500.00 cash invoice to 1 × 1.00 | **200**; total is now 1.00, with no audit trail | DEF-05 confirmed |

### 3.4 React checks

| Check | Result |
|---|---|
| `vite build` (output to the scratchpad, not the repo) | **PASS** (271 KB JS, 86 KB gzip) |
| `oxlint src` (default rules) | 0 errors, 6 warnings (missing `key` props, duplicate key `desc` in `FeatCards.jsx`, ref cleanup in `LandingPage.jsx`) |
| `oxlint -D no-undef src` | **1 error:** `src/services/api.js:21 'json' is not defined` → DEF-12 confirmed |

---

## 4. Capability Baseline (Reconciled)

| Capability | Status | Evidence |
|---|---|---|
| Owner + store registration (API) | **Implemented and verified** | `AuthService::registerStore`; test passes |
| Login / logout / token (API) | **Implemented and verified** | `AuthController`; test passes |
| `/me` (current user, role, store) | Implemented, unverified | No test asserts it |
| Invitations (owner-only) | **Implemented and verified** (owner-only scope) | `test_roles_and_invitations` |
| Role checks owner/manager/employee | **Partially implemented**: owner promotion possible | DEF-04 |
| Store isolation for customers, invoices, debts, payments, users, dashboard | **Implemented and verified** for existing modules | Isolation assertions in 5 tests |
| Customer CRUD | **Implemented and verified** | test passes |
| Customer debt summary | Implemented, unverified | Endpoint exists; only its 404 isolation is asserted |
| Invoices: cash/credit creation (free-text items) | **Implemented and verified** | test passes |
| Invoice edit / delete | **Implemented but unsafe** | DEF-01, DEF-05, DEF-06 |
| Opening (legacy) debt | **Implemented and verified** | `test_opening_debt_lifecycle…` |
| Payments partial/full; overpayment rejected | **Implemented and verified** | test passes |
| Single payment reversal | **Implemented and verified** | test passes |
| Group (pay-all) payment and reversal | Pay-all verified; **group reversal unverified** (no test) | — |
| Dashboard with 4 period filters | **Implemented and verified** (UTC boundaries) | 4 dashboard tests; DEF-07 |
| React login | **Defect** | DEF-12 |
| React register | **Missing** (form not wired) | DEF-13 |
| React dashboard / admin screens | **Missing** (placeholder) | `Dashboard.jsx` is 4 lines |
| Products, stock, barcode, returns, due dates, overdue, statement, secure link, WhatsApp, OTP, AI, voice, offline/sync, audit log, idempotency | **Missing** | grep across backend and frontend |
| Flutter app | **Missing** | §2 |

---

## 5. Defect Register (Baseline)

Priority definitions:

- **P0:** financial corruption, unauthorized access, or data loss.
- **P1:** core MVP behaviour broken or unreliable.
- **P2:** important gap.
- **P3:** polish.

**Closure rule (v0.2):** a defect is **Closed** only when:

1. its fix is merged;
2. its listed regression test exists in the repository and passes on sqlite **and** MySQL (or the CI lint job, for front-end defects);
3. the test name and CI run link are recorded in "Closure evidence".

The out-of-repo probe tests in §3.3 and Appendix 1 **do not close any defect**. As of 2026-10-13: **18 open, 0 closed.**

| ID | Pri | Defect | Evidence | Fixed by | Regression test (in repo) | Status | Closure evidence |
|---|---|---|---|---|---|---|---|
| DEF-01 | P1 | Deleting an invoice after a credit→cash conversion returns HTTP 500. The soft-deleted debt still holds the restricted FK. | Probe §3.3; `InvoiceController::update` line 177 / `destroy` line 321 | US-0503 | TC-0503-05 | **Open** | — |
| DEF-02 | **P0** | No idempotency on financial writes; duplicate submissions create duplicate records | Probe §3.3; `PaymentController::store`, `InvoiceController::store`, `CustomerDebtController::payAll`, `DebtController::store` | US-0101 | TC-0101-01, TC-0101-07 | **Open** | — |
| DEF-03 | P1 | Money inputs accept >2 decimals; float arithmetic produces status/amount drift | Probe §3.3; `StorePaymentRequest.php:28`, `StoreInvoiceRequest.php:73` | US-0102 | TC-0102-01/03/04, TC-0703-06 | **Open** | — |
| DEF-04 | P2 | Owner can promote a user to `owner`; that second owner can then never be changed or removed | Probe §3.3; `UpdateUserRoleRequest.php:21` | US-0105 | TC-0105-02 | **Open** | — |
| DEF-05 | **P0** | Employees can rewrite items and totals of cash invoices with no audit trail | Probe §3.3; `UpdateInvoiceRequest.php:16`, `InvoiceController::update` lines 217–268 | US-0503 | TC-0105-01 (S1 containment), TC-0503-01 | **Open** | — |
| DEF-06 | P1 | Cash invoices are hard-deleted (owner/manager), leaving no trace | `InvoiceController::destroy`; asserted by an existing test | US-0503 | TC-0503-04, TC-0503-05 | **Open** | — |
| DEF-07 | P2 | Dashboard "today/week/month" boundaries use UTC, not shop local time | `config/app.php:68`; `DashboardService::periodBounds` | US-0107 | TC-0107-01 | **Open** | — |
| DEF-08 | P1 | No login throttling; Sanctum tokens never expire | `routes/api.php` (no throttle); `config/sanctum.php:53` | US-0104 | TC-0104-01, TC-0104-02 | **Open** | — |
| DEF-09 | P1 | Users are hard-deleted, and `payments.created_by` is `nullOnDelete`, so actor attribution is lost | `UserController::destroy`; payments migration line 22 | US-0105, US-0103 | TC-0105-03, TC-0105-04 | **Open** | — |
| DEF-10 | P2 | A single payment inside a pay-all group can be reversed alone, leaving the group half-reversed | `PaymentController::is_reverse` | US-0703 | TC-0703-02 | **Open** | — |
| DEF-11 | P2 | An invoice's customer can be reassigned, silently moving its debt to another customer | `UpdateInvoiceRequest` `customer_id` | US-0503 | TC-0503-06 | **Open** | — |
| DEF-12 | P1 | React login throws `ReferenceError` (`json.stringify`) after a successful login | `frontend/src/services/api.js:21`; oxlint `no-undef` | US-0202 | TC-1201-01 (lint `no-undef`), TC-0202-01 | **Open** | — |
| DEF-13 | P1 | React register form never calls the API | `frontend/src/pages/Register.jsx` | US-0201 | TC-0201-02 (needs D-32) or TL-signed exception | **Open** | — |
| DEF-14 | P3 | `InvoiceController::store` swallows exceptions without logging | lines 106–110 | US-0106 | TC-0106-03 | **Open** | — |
| DEF-15 | P2 | Local `.env` has `APP_ENV=production` with `APP_DEBUG=true` (unsafe deployment template) | `.env` keys only (values not exposed) | US-1401 | TC-0104-03, TC-1401-01 | **Open** | — |
| DEF-16 | P2 | Tests run only on sqlite, whose decimal semantics differ from MySQL (DEF-03 probe stored 0.000999…) | `phpunit.xml` | US-0108 | TC-0108-01 | **Open** | — |
| DEF-17 | P3 | React lint warnings (missing keys, duplicate object key) | oxlint output | US-1201 | TC-1201-01 (zero warnings) | **Open** | — |
| DEF-18 | P3 | The SRS in the repo is stale (pre-v1.1) | §1 | D-28 (TL action) | TC-0109-01, TC-0109-02 | **Open** | — |
| DEF-19 | P2 | Framework validation messages (`VALIDATION_FAILED`) are returned in English: `APP_LOCALE=en` and no Arabic validation translations. Found 2026-10-13 during the US-0106 contract freeze | `config/app.php` locale; live `POST /api/v1/login` with an empty body | Unassigned (proposed: S3 with US-0202) | — | **Open** | Mitigated in S1: clients validate locally in Arabic ([docs/api/error-codes.md](../../api/error-codes.md)) |

---

## 6. Integration Points Available Today

- **REST API:** `/api/*` with Sanctum bearer tokens. Pagination uses Laravel's paginator JSON. Error messages are in Arabic with Laravel's standard 422 shape.
- **Isolation pattern reusable for new models:**
  - `App\Traits\BelongsToStore`: store-scoped route binding plus a `forStore()` scope.
  - Store-scoped `Rule::exists` validation in FormRequests.
- **Locking pattern reusable for new financial services:** `DB::transaction` + `lockForUpdate` in the payment, pay-all, and reversal code.
- **Hashed single-use token pattern reusable for secure debt links:** `AuthService::createInvitation` / `acceptInvitation`.
- **No API contract file exists:** no OpenAPI spec and no Postman collection.

---

## 7. Assumptions Used by This Package

| ID | Assumption | If wrong |
|---|---|---|
| A-01 | One primary developer, ~6 productive hours/day, AI-assisted | All estimates scale |
| A-02 | No production data exists yet, so schema changes can include backfill without live-traffic constraints | Migration plan (doc 12) needs a maintenance window |
| A-03 | Shops are in Palestine (NIS; payment methods Jawwal Pay / PalPay / Bank of Palestine; developer TZ +02:00) | Timezone default (D-23), OTP provider coverage (D-14) |
| A-04 | Android is the first mobile target (SRS 1.7) | iOS adds signing/test effort |
| A-05 | The Flutter SDK and two Android phones (reference + low-end) are available in **S1**, where US-1302 proves them *(v0.2: was "before S2"; setup is now planned work)* | Flutter spikes and gate G-FL slip; S5 estimate stays unverified |
| A-06 | No Figma integration is connected in this session; designs are delivered as specifications | Doc 06 Figma workflow is manual |
| A-07 *(v0.2)* | The developer works full-time: 5 days/week, ≈ 6 productive hours/day. **To be confirmed (D-34).** | Calendar dates scale (half-time ≈ ×2) |
| A-08 *(v0.2)* | Pilot shops have reliable internet during trading hours. **To be confirmed (D-35).** | R1 (online-only) is not launchable for them; offline sales and payments move into R1 (≈ +9.5 dd) |
| A-09 *(v0.2)* | The SRS used for planning is the v1.1 PDF provided in the planning session. It is **not yet pinned in the repository** (D-28, US-0109). | The traceability matrix (01) may not match the approved baseline |

---

## 8. Decisions Needed from the Team Leader (Summary)

See [03-decision-log-and-change-requests.md](03-decision-log-and-change-requests.md) for the full analysis and [13 §6](13-final-review-and-decision-pack.md) for the classified approval list. The items that **block Sprint S1** (corrected in v0.2) are:

| Decision | Topic |
|---|---|
| D-04 | Idempotency mechanism |
| D-09 | Money representation |
| D-12 / CR-10 | Role matrix |
| D-13 | User deactivation |
| D-22 | API versioning |
| D-23 / CR-14 | Store timezone (value) |
| D-24 | CI / MySQL parity |
| D-28 | Commit SRS v1.1 to the repository (TL action) |

> **v0.2 corrections:** D-01 and D-06 were removed from this list, because S1 does not depend on them. D-06 blocks S2; employee containment happens in S1 through D-12.

---

## Appendix 1 — Probe Test Source

Run from the scratchpad with:

```
php vendor/bin/phpunit --do-not-cache-result <path>/AuditProbeTest.php
```

It is proposed to be converted into permanent regression tests in US-0101, US-0102, US-0105 and US-0503.

```php
<?php

namespace Tests\Probe;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditProbeTest extends TestCase
{
    use RefreshDatabase;

    private function setupStore(): array
    {
        $store = Store::create(['name' => 'S']);
        $owner = User::factory()->create(['store_id' => $store->id, 'role' => 'owner']);
        $customer = Customer::create(['store_id' => $store->id, 'name' => 'C', 'phone' => '0590000001']);
        return [$store, $owner, $customer];
    }

    public function test_probe_delete_after_debt_to_cash_conversion(): void
    {
        [$store, $owner, $customer] = $this->setupStore();
        $api = $this->actingAs($owner, 'sanctum');
        $id = $api->postJson('/api/invoices', ['customer_id' => $customer->id, 'has_debt' => true, 'items' => [['item_name' => 'x', 'quantity' => 1, 'unit_price' => 10]]])->json('data.id');
        $api->putJson("/api/invoices/{$id}", ['has_debt' => false, 'payment_method' => 'cash'])->assertOk();
        $res = $api->deleteJson("/api/invoices/{$id}");
        fwrite(STDERR, "\nPROBE delete-after-conversion status=" . $res->status() . "\n");
    }

    public function test_probe_three_decimal_payment(): void
    {
        [$store, $owner, $customer] = $this->setupStore();
        $api = $this->actingAs($owner, 'sanctum');
        $debtId = $api->postJson('/api/invoices', ['customer_id' => $customer->id, 'has_debt' => true, 'items' => [['item_name' => 'x', 'quantity' => 1, 'unit_price' => 60]]])->json('data.debt.id');
        $res = $api->postJson('/api/payments', ['debt_id' => $debtId, 'amount' => 59.999, 'method' => 'cash']);
        $debt = Debt::find($debtId);
        fwrite(STDERR, "PROBE 3dp payment status=" . $res->status() . " debt.remaining=" . $debt->remaining_amount . " debt.status=" . $debt->status . "\n");
    }

    public function test_probe_promote_to_owner(): void
    {
        [$store, $owner] = $this->setupStore();
        $emp = User::factory()->create(['store_id' => $store->id, 'role' => 'employee']);
        $res = $this->actingAs($owner, 'sanctum')->patchJson("/api/users/{$emp->id}/role", ['role' => 'owner']);
        fwrite(STDERR, "PROBE promote-to-owner status=" . $res->status() . " role=" . $emp->fresh()->role->value . "\n");
    }

    public function test_probe_duplicate_payment_submission(): void
    {
        [$store, $owner, $customer] = $this->setupStore();
        $api = $this->actingAs($owner, 'sanctum');
        $debtId = $api->postJson('/api/invoices', ['customer_id' => $customer->id, 'has_debt' => true, 'items' => [['item_name' => 'x', 'quantity' => 1, 'unit_price' => 100]]])->json('data.debt.id');
        $payload = ['debt_id' => $debtId, 'amount' => 10, 'method' => 'cash'];
        $a = $api->postJson('/api/payments', $payload)->status();
        $b = $api->postJson('/api/payments', $payload)->status();
        fwrite(STDERR, "PROBE duplicate-payment statuses={$a},{$b} payments=" . Debt::find($debtId)->payments()->count() . "\n");
    }

    public function test_probe_employee_edits_cash_invoice(): void
    {
        [$store, $owner, $customer] = $this->setupStore();
        $emp = User::factory()->create(['store_id' => $store->id, 'role' => 'employee']);
        $id = $this->actingAs($owner, 'sanctum')->postJson('/api/invoices', ['customer_id' => $customer->id, 'has_debt' => false, 'payment_method' => 'cash', 'items' => [['item_name' => 'x', 'quantity' => 10, 'unit_price' => 50]]])->json('data.id');
        $res = $this->actingAs($emp, 'sanctum')->putJson("/api/invoices/{$id}", ['items' => [['item_name' => 'x', 'quantity' => 1, 'unit_price' => 1]]]);
        fwrite(STDERR, "PROBE employee-edit-cash status=" . $res->status() . " total_now=" . Invoice::find($id)->total_amount . "\n");
    }
}
```

> This is the exact source executed in the session (results in §3.3). It is documentation only; it has not been added to `backend/tests/`.
