# Appendix A — Phase 0 Audit Report (verbatim copy)

> **Status: REFERENCE — produced 2026-10-12 in read-only mode.** Copied verbatim from `C:\Users\hp\.claude\plans\pasted-content-id-3524-hisbah-snazzy-wilkes.md` so that the audit lives with the planning package.
>
> **Superseded statements** (see [00-project-baseline.md](00-project-baseline.md)):
> - "Test status is unknown / 7 of 15 failing": **superseded**. The suite was run safely on 2026-10-12: **15/15 pass, 155 assertions**.
> - Suspected defects (invoice delete 500, 3-decimal payment, owner promotion, duplicate payment, employee cash-invoice edit) are now **confirmed by probe tests**.
> - "Implemented but unverified" labels for features covered by passing tests are upgraded in [01-requirements-gap-analysis.md](01-requirements-gap-analysis.md).

---


**Audit date:** 2026-10-12 · **Repo:** `micro-erp-system` @ `71c9d17` (branch `main`, clean) · **Mode:** read-only

**Method and limits.** I read every backend source file in `app/`, `routes/`, `database/migrations/`, `tests/`, plus all React sources under `frontend/src/`. I did **not** run the test suite. The session was in read-only mode, and PHPUnit/Laravel write cache and log files. All test statuses below therefore come from source reading and from the stale `backend/.phpunit.result.cache` file. No secret values were read or reproduced.

---

## 1. Executive Summary

- **What exists:** A Laravel 12 + Sanctum backend covering the **financial core** (store registration, invitations, roles, customers, free-text invoices, debts, payments, reversals, dashboard). Store isolation is applied consistently. A React 19 app has a **landing page and login/register screens only**.
- **What does not exist:**
  - Any **Flutter** code.
  - Any **product/inventory/barcode** model.
  - **Returns**, **OTP**, **AI**, **offline/sync/idempotency**, **secure debt links**, **due dates**, and **audit logging**.
- **Coverage:** Of the 70 FRs, about **14 are implemented but unverified**, about **17 partial**, and about **39 missing**. The existing code mainly covers SRS chapters 3–4 for customers, debts, and payments. Products, inventory, sales returns, AI, offline mode, and mobile — the core of the v1.1 product — are absent.
- **Test status is unknown.** There are 15 tests (13 meaningful feature tests). The last recorded run (cache mtime 2026-08-23 00:42) marked **7 as Failure**. That run predates the final backend commit (`68b6d58`, 02:14 the same day), so the cache may be stale. Running the suite is the first verification step.
- **Most serious findings:**
  - (P0) No idempotency on any financial write.
  - (P0) Employees can silently edit cash-invoice amounts, and cash invoices can be hard-deleted with no trace.
  - (P0) Invoices are not linked to products, which blocks inventory, barcode, returns, and AI data integrity.
  - (P0 delivery) No Flutter app exists for a "mobile-first" MVP.
- **Feasibility:** The 20-day target is **not realistic** for the full v1.1 scope with one developer who has limited Flutter experience. Section 11 gives an evidence-based estimate (~35–50 dev-days).

---

## 2. Repository & Architecture Inventory

| Component | Present? | Evidence |
|---|---|---|
| Laravel backend | **Yes** | `backend/` — PHP ^8.2 (local CLI 8.2.12), `laravel/framework ^12.0`, `laravel/sanctum ^4.0`, PHPUnit ^11.5 |
| React web | **Yes (early)** | `frontend/` — React ^19.2.8, react-router-dom ^7.18.3, Vite ^8.2, oxlint. No state/data library, no HTTP client lib (raw `fetch`) |
| Flutter mobile | **Not in this workspace** | No `pubspec.yaml`, no `lib/*.dart` anywhere in repo. *May exist elsewhere — please confirm.* |
| AI implementation | **No** | No provider SDK, config key, controller, or table (grep for openai/anthropic/gemini/AI: none) |
| Automated tests | **Yes (backend only)** | `tests/Feature/BackendFeatureTest.php` (9 tests), `DashboardFeatureTest.php` (4), 2 example tests. sqlite `:memory:` per `phpunit.xml`. No frontend tests |
| Deployment / CI config | **No** | No Dockerfile, CI workflow, deploy scripts, or hosting docs |
| Offline / sync | **No** | No client transaction IDs, queue tables, or sync endpoints |
| Postman | **Empty** | `postman/` and `backend/postman/` contain only empty scaffold folders, so no API collection exists |
| SRS in repo | **Stale** | `documemtation/SRS.pdf` committed 2026-08-02, before v1.1 (prepared 2026-09-23). Folder name is misspelled |

**Environment/config hygiene:**
- `backend/.env` is git-ignored and untracked (good).
- The local `.env` contains `APP_ENV=production` together with `APP_DEBUG=true`. Copying that to a server would leak stack traces.
- `config/app.php:68` sets the timezone to `UTC`.
- `config/sanctum.php:53` sets `expiration => null`, so tokens never expire.
- No rate limiting is configured on any route.

**Backend architecture:**
- Thin service layer: only `AuthService` and `DashboardService`. Business logic for invoices, debts, and payments sits **in controllers**.
- Store isolation uses two traits:
  - `App\Traits\BelongsToStore`: store-scoped route-model binding plus a `forStore()` scope.
  - `App\Traits\ScopedThroughDebtStore`: payments are scoped through `debt.store_id`, because `payments` has no `store_id`.
- `EnsureUserHasStore` middleware (alias `store`) is applied to all protected routes.
- Authorization:
  - `UserPolicy` is the only policy.
  - Other role checks are inline `abort_unless(hasRole(...))` calls or `FormRequest::authorize()`.

**Schema (8 domain migrations, `2026_08_10_*`):**

| Table | Columns |
|---|---|
| stores | name, phone, address |
| users | email-unique, role string, store_id |
| store_invitations | token_hash, expires_at, accepted_at |
| customers | store_id+phone unique, soft deletes |
| invoices | customer_id **required**, total_amount, has_debt, source `sale\|opening_debt`, payment_method |
| invoice_items | **free-text `item_name`**, quantity, unit_price, total — **no product_id** |
| debts | invoice_id **unique + restrict**, amount, remaining_amount, status string, soft deletes — **no customer_id, no due_date** |
| payments | debt_id, amount, method, payment_group_id (uuid), paid_at, created_by (**nullOnDelete**), is_reversed, reversed_at, reversal_reason — **no store_id, no reversed_by** |

**React architecture:**
- Routes `/`, `/register`, `/login`, and `/dashboard` (`/dashboard` sits behind `ProtectedRoute`, which only checks that a `localStorage` token exists).
- The API base URL is hard-coded to `http://127.0.0.1:8000/api` in [api.js:1](frontend/src/services/api.js#L1).
- Arabic/English landing-page translation exists in `src/data/translation.js`.

---

## 3. Verified Existing Backend Capability Matrix

"Unverified" means the code exists and a test exists, but the tests were not run in this audit (see §1).

| Capability | Status | Evidence | Gaps / defects |
|---|---|---|---|
| Store + owner registration | Implemented, unverified | `AuthService::registerStore` (transactional); `RegisterStoreRequest` | No OTP; Store has no `status`; phone nullable/max:10 |
| Login / Sanctum token | Implemented, unverified | `AuthController::login` | **No throttling**; tokens never expire; email-based only |
| Logout / `/me` | Implemented, unverified | `AuthController::logout`, `me` | — |
| Invitations | Partial | `AuthService::createInvitation/acceptInvitation` — sha256-hashed token, expiry, single-use with row lock | Owner-only (`CreateInvitationRequest`); raw token returned in API response (no delivery channel); no list/revoke endpoints |
| Roles owner/manager/employee | Partial | `App\Enums\UserRole`, `User::hasRole` | Checks scattered inline; [UpdateUserRoleRequest.php:21](backend/app/Http/Requests/UpdateUserRoleRequest.php#L21) accepts `owner`, so an owner can promote anyone to a second, irremovable owner |
| User management | Partial | `UserController` + `UserPolicy` | **Hard delete** (no deactivate); deleting a user nulls `payments.created_by` (audit loss) |
| Store isolation | Implemented, unverified | `BelongsToStore`, `ScopedThroughDebtStore`, `exists` rules scoped by store in FormRequests, isolation tests | Payments isolated only via join on debts; no structural guard (e.g., global scope) for new models |
| Customer CRUD | Implemented, unverified | `CustomerController`, soft delete blocked if invoices exist | Update request omits `min:10` on phone (create has it); no status/deactivate field |
| Customer debt summary | Partial | `CustomerDebtController::index` — count, total, payments, remaining | Ignores cash invoices; no chronological statement |
| Invoice create (cash / credit) | Partial | `InvoiceController::store`, transactional, server-calculated totals | Free-text items; **no partial payment at creation**; credit = 100% debt; cash creates **no Payment row**; `catch (\Exception)` swallows errors without logging (lines 106–110) |
| Invoice update | Implemented, **risky** | `InvoiceController::update` with row lock | Employees allowed ([UpdateInvoiceRequest.php:16](backend/app/Http/Requests/UpdateInvoiceRequest.php#L16)); **cash invoice items/totals freely editable** with no audit trail; customer can be reassigned |
| Invoice delete | Implemented, **risky** | `InvoiceController::destroy` (owner/manager) | **Hard delete**; see the FK bug in §7 |
| Opening (legacy) debt | Implemented, unverified | `DebtController::store/update/destroy` — synthetic invoice with `source=opening_debt` | No due date |
| Payments (partial/full) | Implemented, unverified | `PaymentController::store` — locks debt, rejects overpayment | No idempotency; amount accepts >2 decimals |
| Pay-all (grouped) | Implemented, unverified | `CustomerDebtController::payAll` — locks debts, shared `payment_group_id` | Owner/manager only, while single payment is open to employees (inconsistent) |
| Single / group reversal | Implemented, unverified | `PaymentController::is_reverse`, `reverseGroup` — recompute remaining from non-reversed payments | No `reversed_by`; a single payment inside a group can be reversed alone, leaving the group half-reversed |
| Dashboard + period filters | Implemented, unverified | `DashboardService`, `DashboardRequest` (today/this_week/this_month/this_year, `store_id` prohibited) | UTC day boundaries; no low-stock/overdue/insights; "collections" excludes cash sales |

---

## 4. React Frontend Status

| Area | Status | Evidence |
|---|---|---|
| Landing page (Hero, Features, Plans, FAQ, etc.) | Built | `src/components/*`, `src/pages/LandingPage.jsx` |
| Login | **Broken** | [api.js:21](frontend/src/services/api.js#L21) `json.stringify` → `ReferenceError` after a successful login. The token is saved first, then the error is thrown, so `navigate('/dashboard')` never runs ([Login.jsx:41-47](frontend/src/pages/Login.jsx#L41-L47)). Error is only `console.log`ged |
| Register | **Not wired** | `Register.jsx` has no API call; `setLoding` typo; footer "Log In" link points to `/register` |
| Dashboard | Placeholder | `Dashboard.jsx` is 4 lines: `<div>Dashboard</div>` |
| Customers / invoices / debts / payments / products / staff / AI / statement pages | **Missing** | — |
| Auth handling | Weak | Token in `localStorage`; no 401 handling, no logout, `/me` never used, no role-aware UI |
| Config | Hard-coded API URL; no `.env` / `VITE_API_URL` | `api.js:1` |
| RTL / i18n | Partial | `[dir="rtl"]` CSS exists; `index.html` is `lang="en"`; auth screens are mixed English/Arabic. The password error message says "6 characters" while the check is `< 8` |
| Tests | None | — |

**Summary:** For SRS purposes the React admin app is roughly 5% done. The landing page is not an SRS requirement.

---

## 5. Flutter Mobile Status

**Unavailable in this workspace.** No Flutter project was found anywhere in the repository. Every mobile-scoped requirement is therefore Missing or Blocked:
- FR-17/18 (barcode)
- FR-60 (voice)
- FR-64–69 (offline)
- NFR-02/03/05/12/13
- UC-08, UC-21, UC-22

If a Flutter repo exists elsewhere, it must be added to the workspace and audited before planning.

---

## 6. SRS-to-Code Traceability Matrix

Legend: **IV** = Implemented and verified · **IU** = Implemented but unverified · **P** = Partially implemented · **M** = Missing · **B** = Blocked / unclear.
**No item is IV**, because the tests were not executed in this audit.

### 6.1 Functional Requirements

| ID | Requirement | Status | Evidence / gap | Depends on | Next action |
|---|---|---|---|---|---|
| FR-01 | Owner registration | IU | `AuthService::registerStore`; test `test_authentication_register_login_logout_and_protected_access` (in last cache's failure list) | FR-02 | Run tests; wire React |
| FR-02 | OTP verification | M | No OTP table/provider/flow; Store lacks `status` | Provider decision | Decide provider (Q5) |
| FR-03 | Authentication | IU | `AuthController::login` | — | Add throttling, token expiry |
| FR-04 | Logout | IU | `AuthController::logout` | — | — |
| FR-05 | Current user | IU | `GET /me` returns user (with role) + store | — | — |
| FR-06 | RBAC | P | Inline checks + `UserPolicy`; owner-promotion gap | — | Centralize into policies |
| FR-07 | Store isolation | IU | Traits + scoped `exists` rules + isolation tests | — | Run tests; add `store_id` to payments (decision) |
| FR-08 | Staff invitations | P | Owner-only; no list/revoke; token returned raw | — | Decide whether managers may invite |
| FR-09 | Staff management | P | View/role change/hard delete; no deactivate | FR-70 | Add soft deactivate |
| FR-10 | Customer creation | IU | `CustomerController::store` | — | — |
| FR-11 | Customer management | IU | update/soft-delete with financial-history guard | — | — |
| FR-12 | Customer financial summary | P | Debt-only summary; no invoices/cash in summary | FR-13 | Extend endpoint |
| FR-13 | Customer statement | M | No chronological statement endpoint | Debt `customer_id` | Build |
| FR-14 | Customer debt view | IU | `GET /customers/{id}/debts` | — | — |
| FR-15 | Product creation | M | No `products` table | — | Build (foundation) |
| FR-16 | Product management | M | — | FR-15 | Build |
| FR-17 | Barcode scanning | M | No mobile app; no barcode column | FR-15, Flutter | Build |
| FR-18 | Repeated scan increment | M | — | FR-17 | Build (client) |
| FR-19 | Stock management | M | — | FR-15 | Build |
| FR-20 | Stock adjustment | M | — | FR-19 | Build |
| FR-21 | Stock history | M | No `stock_movements` | FR-19 | Build |
| FR-22 | Low stock detection | M | — | FR-19 | Build |
| FR-23 | Create invoice | P | Exists, but items are free text, not products | FR-15 | Add `product_id` to items |
| FR-24 | Cash sale | IU | `has_debt=false` path; no Payment row | — | Decide "collections" semantics (Q8) |
| FR-25 | Credit sale | P | Only fully unpaid credit | FR-26 | Extend |
| FR-26 | Partial payment at creation | M | `StoreInvoiceRequest` has no `paid_amount` | — | Build |
| FR-27 | Automatic debt | P | Created for full total only | FR-26 | Extend |
| FR-28 | Inventory update on sale | M | — | FR-19 | Build into the invoice transaction |
| FR-29 | Invoice viewing | IU | `index`/`show` | — | — |
| FR-30 | Invoice modification | P | Guards against paid debts; but cash invoices are freely editable by employees, no audit | BR-07, FR-70 | Restrict (decision Q7) |
| FR-31 | Invoice archive/delete | P | Blocks delete when payments exist; otherwise **hard delete**, no archive | — | Add archive/void |
| FR-32 | Sale return | M | — | FR-15, FR-19 | Build (rule decision Q3) |
| FR-33 | Return inventory/balance update | M | — | FR-32 | Build |
| FR-34 | Existing debt | IU | `DebtController::store` (opening_debt) | — | Add due date |
| FR-35 | Debt details | P | `DebtDetailsResource`: no due date, no created_at, customer only via invoice | FR-36 | Extend |
| FR-36 | Due date | M | No column | — | Build (new migration) |
| FR-37 | Overdue | M | — | FR-36 | Build |
| FR-38 | Payment recording | IU | `PaymentController::store` | — | Add idempotency |
| FR-39 | Payment reversal | IU | `is_reverse`, `reverseGroup` | FR-70 | Add `reversed_by` |
| FR-40 | Payment history | P | Shop-level list + per-debt; no per-customer/per-invoice list | — | Extend filters |
| FR-41 | Outstanding debt | IU | `DashboardService::debtMetrics.total_remaining` | — | — |
| FR-42 | Due/overdue/highest-balance lists | M | — | FR-36 | Build |
| FR-43 | Secure debt link | M | — | FR-13 | Build |
| FR-44 | WhatsApp share | M | — | FR-43 | Build (client `wa.me` / share sheet) |
| FR-45 | Unified NIS | P | Implicit single currency; no currency field/formatting in API or UI | — | Add formatting convention |
| FR-46 | Dashboard summary | P | Sales/invoices/collections/debt/customers present; no low stock; "new debt" ≈ credit_sales only | FR-22 | Extend |
| FR-47 | Dashboard time filters | IU | 4 periods; UTC boundaries | — | Set store timezone |
| FR-48 | Actionable insights | M | — | FR-22, FR-37 | Build |
| FR-49–FR-59 | AI conversation, read tools, summary, drafts, validation, preview, confirmation, AI invoice/payment | M | No AI code at all | Products, provider | Build |
| FR-60 | Voice input | M | — | Flutter, AI | Build |
| FR-61–FR-63 | AI scope, integrity, failure recovery | M | — | FR-49 | Build |
| FR-64 | Offline local transactions | M | — | Flutter, idempotency | Build |
| FR-65 | FIFO sync | M | — | FR-64 | Build |
| FR-66 | Idempotent sync | M | No client transaction ID anywhere | — | Build (backend first) |
| FR-67 | Sync indicator | M | — | FR-64 | Build |
| FR-68 | Queue limit 1000 | M | — | FR-64 | Build |
| FR-69 | Optional location/time | M | — | FR-64 | Defer candidate |
| FR-70 | Critical audit logging | P | `payments.created_by`, `reversed_at`, `reversal_reason` only; no `reversed_by`, no role-change log, no AuditLog | — | Build AuditLog |

### 6.2 Non-Functional Requirements

| ID | Status | Notes |
|---|---|---|
| NFR-01 API ≤3s | B | No performance tests. Queries look indexed enough for MVP. Dashboard runs ~12 queries; acceptable |
| NFR-02 Barcode ≤1.5s | B | No mobile app |
| NFR-03 Local search 10k ≤0.5s | B | No mobile app |
| NFR-04 Offline readiness | M | — |
| NFR-05 Local commit ≤200ms | B | No mobile app |
| NFR-06 Sync ≤60s | M | No sync endpoint. Needs a batch endpoint to be achievable (§8) |
| NFR-07 Statement ≤3s on 4G | M | No statement page |
| NFR-08 Security | P | Auth, validation, RBAC, isolation present. **No login rate limiting**, non-expiring tokens, `APP_DEBUG=true` in local env, no TLS/CORS deployment config |
| NFR-09 UUID link security | M | — |
| NFR-10 Atomic & retry-safe | P | Atomic: yes (`DB::transaction` + `lockForUpdate`). Retry-safe: **no** (no idempotency) |
| NFR-11 Data integrity | P | FKs present; amounts accept >2 decimals; status is a free string; debt↔customer only via invoice |
| NFR-12 Mobile usability | B | No mobile app |
| NFR-13 Flutter maintainability | B | No Flutter app. Note: the original `hive` package's maintenance status should be verified before committing to it (community fork `hive_ce` exists) |
| NFR-14 Web accessibility | M | No core web workflows exist yet |
| NFR-15 Privacy | P | Authorized-user scoping present; AI provider data sharing not yet addressed |
| NFR-16 Backup/recovery | B | No hosting selected or documented |

### 6.3 Business Rules

| ID | Status | Notes |
|---|---|---|
| BR-01 Credit limit | M | No `credit_limit` on customers |
| BR-02 AI confirmation | M | No AI |
| BR-03 NIS | P | Implicit |
| BR-04 Product history | M | No products |
| BR-05 FIFO | M | — |
| BR-06 Secure link | M | — |
| BR-07 Closed invoice | P | Credit invoices with payments are locked. **Cash invoices are never locked**, and there is no "finalized" state. A test (`test_invoices_totals_debts_update_delete_and_isolation`, lines 141–144) *asserts* that a cash invoice can be edited and hard-deleted |
| BR-08 Time/location | M | — |
| BR-09 OTP | M | — |
| BR-10 Conflict handling | M | — |
| BR-11 Low stock | M | — |
| BR-12 Queue limit | M | — |
| BR-13 AI authorization | M | — |
| BR-14 AI source of truth | M | — |

### 6.4 Use Cases

| UC | Status | Notes |
|---|---|---|
| UC-01 Register | P | Backend without OTP; React form not wired |
| UC-02 OTP | M | — |
| UC-03 Login/Logout | P | Backend IU; React login broken |
| UC-04 Staff & roles | P | Backend only, no UI |
| UC-05 Customers | P | Backend only, no UI |
| UC-06 Statement | M | — |
| UC-07 Products | M | — |
| UC-08 Barcode | M | — |
| UC-09 Inventory | M | — |
| UC-10 Cash sale | P | No products/stock/UI |
| UC-11 Credit/partial sale | P | No partial, no credit limit, no UI |
| UC-12 Return | M | — |
| UC-13 Record payment | P | Backend IU, no UI |
| UC-14 Reverse payment | P | Backend IU, no UI |
| UC-15 Manage debts | P | No due dates/overdue, no UI |
| UC-16 Secure link | M | — |
| UC-17 Dashboard & alerts | P | Metrics only; no alerts; no UI |
| UC-18 AI question | M | — |
| UC-19 AI invoice | M | — |
| UC-20 AI payment | M | — |
| UC-21 Voice | M | — |
| UC-22 Sync | M | — |

---

## 7. Critical Financial, Security & Synchronization Risks

### P0 — Critical

1. **No idempotency on any financial write.**
   - Affected endpoints: `InvoiceController::store`, `PaymentController::store`, `CustomerDebtController::payAll`, `DebtController::store`. None accepts a client key.
   - A double-tap or network retry creates **duplicate invoices/payments**.
   - This also hard-blocks FR-66 and AC-06/07.
   - *Evidence:* request rules in `StoreInvoiceRequest` and `StorePaymentRequest`; there is no unique client-ID column in any migration.
2. **Cash-sale amounts can be silently altered or erased.**
   - `UpdateInvoiceRequest::authorize` allows **employees** ([line 16](backend/app/Http/Requests/UpdateInvoiceRequest.php#L16)).
   - `InvoiceController::update` lets anyone rewrite items and totals of any cash invoice ([lines 217–268](backend/app/Http/Controllers/Api/InvoiceController.php#L217-L268)), with no audit trail.
   - Owners/managers can **hard-delete** cash invoices ([line 321](backend/app/Http/Controllers/Api/InvoiceController.php#L321)).
   - Result: cash revenue can be reduced after the fact with no trace. This conflicts with FR-30, FR-31, BR-07, and FR-70.
3. **Invoices are not linked to products.**
   - `invoice_items.item_name` is free text and there is no `products` table.
   - Inventory (FR-19–22, 28), barcode (FR-17/18), returns (FR-32/33), BR-04, and AI data integrity (FR-62: "AI shall not invent products/prices") are all impossible until a product model exists and invoice items reference it.
4. **Mobile-first MVP has no mobile codebase** (delivery blocker, not a code defect). All offline, barcode, and voice requirements depend on it.

### P1 — High

5. **Invoice delete crashes after a debt→cash conversion (from code reading; not yet confirmed by a test).**
   - `update` soft-deletes the debt ([line 177](backend/app/Http/Controllers/Api/InvoiceController.php#L177)).
   - `destroy` reads `$lockedInvoice->debt`, which excludes trashed rows, so the soft-deleted debt is not removed.
   - `invoice->delete()` then violates `debts.invoice_id restrictOnDelete` ([debts migration line 23](backend/database/migrations/2026_08_10_000007_create_debts_table.php#L23)) and returns an **HTTP 500**. sqlite FKs are enabled (`config/database.php:39`), so a test can reproduce it.
6. **Login has no rate limiting**, and **Sanctum tokens never expire** (`config/sanctum.php:53`). This allows credential brute-forcing, and a stolen token is valid forever.
7. **Deleting a user destroys financial attribution.** Users are hard-deleted (`UserController::destroy`), and `payments.created_by` is `nullOnDelete` ([payments migration line 22](backend/database/migrations/2026_08_10_000008_create_payments_table.php#L22)). Reversals record no actor at all. Together these violate FR-70 and weaken financial accountability.
8. **The SRS's flagship flow is not supported.** The scenario "3 cartons at 15, paid 20, rest is debt" needs **partial payment at invoice creation** (FR-26), which does not exist. A credit invoice is always 100% debt.
9. **Debt/Payment schema diverges from the SRS ERD:**
   - `debts` has no `customer_id` or `due_date`.
   - `payments` has no `store_id` or `customer_id`.
   - Overdue lists, statements, secure links, and AI customer-balance tools all need these. Payment isolation depends entirely on a join through debts.
10. **React login is broken** ([api.js:21](frontend/src/services/api.js#L21)), **register is not wired**, and the **dashboard is a placeholder**.
11. **Test health is unknown.** The last cached run shows 7/15 failures, including auth, invitations, customer isolation, payments, invoice conversion, and both dashboard metric tests. That cache predates the final backend commit and needs a fresh run.

### P2 — Medium

12. **Monetary inputs accept more than 2 decimals.** Rules are `numeric|min:0.01` with no `decimal:0,2` ([StorePaymentRequest.php:28](backend/app/Http/Requests/StorePaymentRequest.php#L28), [StoreInvoiceRequest.php:73](backend/app/Http/Requests/StoreInvoiceRequest.php#L73)).
    - Example: paying `59.999` against `60.00` passes validation. In-memory `remaining_amount = 0.001` sets status `partially_paid`, but the DB then stores `0.00` remaining.
    - Result: status and amount disagree. Arithmetic is float-based (`$debt->remaining_amount -= ...`).
13. **Dashboard uses UTC day boundaries** (`config/app.php:68`). Sales made between 00:00 and 02:00/03:00 local time fall into the previous day.
14. **"Collections" semantics.** Cash sales create no Payment rows, so `total_collected_payments` counts only debt repayments. FR-46 is ambiguous on this point.
15. **Owner promotion.** `UpdateUserRoleRequest` accepts `owner`. A promoted second owner cannot be demoted or deleted afterwards (`UserPolicy` forbids acting on owners).
16. **Partial group reversal.** A single payment inside a pay-all group can be reversed via `/payments/{id}/reverse`, leaving the group half-reversed. The operation list then reports `is_reversed=false` for it.
17. **Local `.env` sets `APP_ENV=production` with `APP_DEBUG=true`**, which is dangerous if used as a deployment template.
18. **Invoice customer reassignment.** `UpdateInvoiceRequest` lets the customer be changed on a credit invoice, silently moving the debt to another customer.

### P3 — Low

19. `InvoiceController::store` swallows all exceptions without logging (lines 106–110).
20. Unused or duplicate code:
    - `ReservePaymentRequest` (typo duplicate of the reverse-payment request)
    - `StoreUserRequest` and `UpdateUserRequest` (no routes use them)
    - Empty stub methods in `CustomerDebtController`
    - Method name `is_reverse`
21. Permission inconsistencies:
    - pay-all is owner/manager only, while a single payment is open to all roles.
    - `UpdateCustomerRequest` omits `min:10` on phone.
22. The in-repo `documemtation/SRS.pdf` is outdated, so there are two divergent requirement baselines.

---

## 8. Architectural Conflicts & Unresolved Product Decisions

### A. SRS-internal contradictions / ambiguities

1. **Return rule undefined.** FR-33 says balances update "according to return rules", but no rule is defined anywhere. For a partially paid credit invoice: reduce the debt first, or refund cash? What if the return exceeds the remaining debt?
2. **"Finalized" invoice is undefined.** BR-07 locks invoices once "finalized and synchronized". For online-created invoices there is no sync step and no explicit finalize state.
3. **Walk-in cash customers.** UC-10 (cash sale) does not require a customer, but the schema requires `invoices.customer_id`. POS cash sales normally have no customer.
4. **OTP vs identity.**
   - FR-02/BR-09 require phone OTP for store creation.
   - Login is email + password, the ERD User has `email`, and `stores.phone` is nullable.
   - Open questions: Is phone the login identifier? Which SMS provider (Palestine/Israel coverage, cost)?
5. **Offline vs server validation.**
   - FR-64 allows offline sales, returns, and payments.
   - BR-01 (credit limit) and the UC-10 "Insufficient stock → reject" rule require **server state**, which is unavailable offline.
   - The SRS does not say whether offline sales may oversell, or whether credit limits are checked locally against stale data.
6. **FIFO is not consistency.**
   - FIFO preserves order but does not resolve, for example, an offline payment against a debt that another device already paid. The server would then reject it as an overpayment.
   - BR-10's "recoverable conflict state" needs a defined resolution UI and owner (who resolves it, and how).
7. **NFR-06 vs FR-68.** Draining up to 1000 queued items within 60s is not plausible with one HTTP request per item, each carrying a locking transaction. A **batch sync endpoint** that returns per-item acknowledgements is needed.
8. **Role permissions are underspecified.** The SRS says "Manager … unless explicitly authorized" and "Employee … approved payment actions". This implies per-user permission flags that the ERD doesn't model. FR-08 says "authorized users" invite, while the code allows owners only.
9. **UUID token.**
   - FR-43 specifies a "UUID". Only UUIDv4 (random) is acceptable; v1/v7 contain time components.
   - Revocation is not specified.
   - Storing a hash of the token at rest is recommended, matching the existing invitation pattern.
10. **AI provider and privacy.** The provider is unspecified. Sending customer names and balances to a third-party API affects NFR-15 and needs an explicit decision.
11. **Voice STT.** The provider and Arabic-dialect accuracy are unspecified. On-device platform STT vs. cloud STT changes the cost, offline behavior, and quality.

### B. SRS vs current implementation

- ERD `Debt.customer_id/due_date/paid_amount`, `Payment.store_id/customer_id`, `Invoice.paid_amount/remaining_amount/status/created_by`, `Store.status`, `User.status`: **none exist**. These need **new additive migrations**; existing migrations must not be edited.
- ERD treats "existing debt" as a Debt without an invoice (`Invoice 0..1 : 1 Debt`). The code models it as a synthetic `opening_debt` invoice with item "دين قديم". The code's approach is workable and should be **kept**, with the SRS ERD note updated through change control.
- FR-31/BR-07 (archive, lock) contradict the current hard-delete and edit behavior, and the existing tests assert that behavior.

---

## 9. Reuse / Extend / Build

### Reuse (keep as-is)
- `BelongsToStore` / `ScopedThroughDebtStore` route-binding isolation pattern, and the store-scoped `Rule::exists` usage in FormRequests.
- `AuthService` registration and invitation flow (hashed single-use tokens, expiry, row lock). This is also the template for secure debt links.
- Pessimistic locking pattern (`DB::transaction` + `lockForUpdate`) in payments, pay-all, and reversals.
- Reversal design: flag rows rather than delete them, then recompute `remaining_amount` from non-reversed payments.
- Opening-debt-as-synthetic-invoice approach (`InvoiceSource::OPENING_DEBT`).
- `DashboardService` period/bucket logic.
- Existing feature tests, after re-running them and fixing the failures.

### Extend / Fix
| Item | Why | Depends on |
|---|---|---|
| Invoice create: `paid_amount` (partial), `product_id` on items, stock deduction, client transaction ID | FR-23–28, FR-66 | Products |
| Invoice update/delete → void/archive + lock policy + audit | P0 #2, BR-07, FR-31 | Decision Q7 |
| Debts: add `customer_id`, `due_date`; overdue scope | FR-35–37, 42 | Migration + backfill |
| Payments: add `store_id`, `reversed_by`, idempotency key | FR-39, 66, 70 | Migration |
| Money validation `decimal:0,2` + integer-cents or bcmath arithmetic | P2 #12 | — |
| Login throttle, token expiry, owner-role guard, user deactivate instead of delete | P1 #6/#7, P2 #15 | — |
| Dashboard: store timezone, low stock, overdue, insights | FR-46–48 | Products, due dates |
| Customer summary → full statement | FR-12/13 | Debt `customer_id` |
| React: fix login, wire register, auth context/401 handling, env-based API URL | P1 #10 | — |

### Build (genuinely missing)
- Products + barcode + stock movements + low stock (FR-15–22, 28)
- Sale returns + return items (FR-32/33)
- OTP verification (FR-02, BR-09)
- AuditLog (FR-70)
- Secure debt link + public statement page + WhatsApp share (FR-43/44)
- Idempotency layer + batch sync endpoint + conflict state (FR-64–68)
- AI layer: provider client, read tools, action drafts, preview/confirm, conversation log (FR-49–63)
- React admin screens for all modules
- **Entire Flutter app:** POS, barcode, Hive store, sync queue, voice, AI chat

---

## 10. Dependency-Aware Missing Capabilities (by module)

1. **Foundation (backend):** idempotency key infrastructure → money/decimal hardening → AuditLog → new schema columns (debt `customer_id`/`due_date`, payment `store_id`/`reversed_by`).
2. **Catalog:** products → stock movements → low stock → barcode lookup endpoint.
3. **Sales:** invoice items with `product_id` + stock deduction + partial payment (needs 1, 2) → invoice void/lock → returns (needs product-linked items).
4. **Debts:** due dates → overdue/due lists → statement → secure link → WhatsApp share.
5. **Accounts:** OTP (needs provider) → store activation status.
6. **Dashboard:** low stock (needs 2), overdue/insights (needs 4), timezone fix.
7. **Sync (backend):** batch sync endpoint using the idempotency keys from 1 → conflict state model.
8. **AI:** provider client → read tools (sales, total debt, customer balance, low stock; need 2 and 4) → payment draft → invoice draft (needs 3) → confirm/execute through existing services → voice (client side).
9. **React:** auth fix → customers/debts/payments (existing APIs, quickest win) → products → invoices/returns → staff → AI chat → public statement page.
10. **Flutter:** project setup + auth → online POS + barcode → customers/payments → Hive cache + queue + sync indicator (needs 7) → AI + voice.

---

## 11. Preliminary Feasibility — 20-Day Objective

**Verdict: not feasible for the full v1.1 scope.** AI coding tools speed up code generation but do not remove integration, debugging, device testing, or the Flutter learning curve.

| Workstream | Rough effort (single dev, AI-assisted) |
|---|---|
| Backend extensions (products, stock, partial pay, returns, due dates, audit, idempotency, secure link, OTP, sync batch endpoint, tests) | 9–12 days |
| AI layer (tools, drafts, confirm, safety tests) | 4–6 days |
| React admin from ~zero (8–10 screens + public statement) | 6–9 days |
| Flutter from zero with limited experience (POS, barcode, Hive, sync queue, conflict UI, voice, AI chat, device testing) | 14–20 days |
| Integration, E2E acceptance (AC-01–10), deployment | 3–5 days |
| **Total** | **~36–52 dev-days** |

**Highest-risk items for a solo developer:**
- Offline-first financial sync with conflict handling (the hardest part of the SRS).
- Flutter learning curve combined with Hive and camera/voice plugins.
- AI invoice drafts with Arabic dialect entity resolution (e.g., "البو محمد" → which customer?).
- OTP provider procurement.

**Performance targets — how to test them and whether they're achievable:**
- NFR-01 (≤3s): Postman/k6 against seeded MySQL. Achievable with the current design.
- NFR-02 (barcode ≤1.5s) and NFR-05 (local commit ≤200ms): stopwatch/integration test on a named Android device, measured from local cache. Achievable only if lookup is **local** (Hive), not via an API call.
- NFR-03 (10k items ≤0.5s): seed 10k items in Hive and time an in-memory filter.
- NFR-06 (60s sync): scripted 100- and 1000-item queues under 1 Mbps throttling. Needs the batch endpoint.
- NFR-07 (statement ≤3s on 4G): Lighthouse with 4G throttling.
- **None of these can be tested today**, because the client code does not exist.

**Scope options for discussion (not a sprint plan):**
1. Flutter online-first with an offline queue limited to cash/credit sales and payments only.
2. Defer offline returns, FR-69 location, and voice on web.
3. Limit AI to the read tools + payment draft first, with invoice draft second.
4. OTP behind a provider interface with a dev/test driver.
5. Alternatively, extend the timeline to ~6–8 weeks.

---

## 12. Questions & Decisions Required Before Implementation

1. **Flutter:** Does a Flutter repository exist elsewhere? If yes, add it to the workspace for audit.
2. **Test run:** May I run `php artisan test` in the next step? It uses in-memory sqlite and touches no real data.
3. **Return rule:** For a partially paid credit invoice, does a return reduce the debt first and then refund cash, or something else?
4. **Offline scope:** Which operations must work offline (sales? payments? returns? opening debts?)? Is offline overselling allowed, with a flag on sync? Are credit limits enforced offline against cached balances?
5. **OTP:** Which SMS provider? Does phone become the login identifier, or does email stay?
6. **Walk-in customers:** Should `customer_id` become nullable for cash sales, or should there be a default "walk-in" customer per store?
7. **Invoice mutability:** Who may edit or void invoices, and when does an invoice become locked? Should cash invoices be voidable only, never editable?
8. **Collections:** Should cash sales count as collections, either by creating Payment rows or by changing the dashboard formula?
9. **Production data:** Is there any production/live data? This determines the migration and backfill strategy for the new `debts.customer_id` and `payments.store_id` columns.
10. **AI:** Which provider? Is sending customer names and balances to it acceptable (privacy)? Which voice STT?
11. **Timezone:** Confirm store timezone (e.g., `Asia/Hebron` / `Asia/Jerusalem`), and whether it is per store or global.
12. **Scope vs. time:** Cut scope to fit 20 days, or extend the timeline? Which items move from Must to Should?
13. **Change control:** Should the in-repo `documemtation/SRS.pdf` be replaced with v1.1 so there is one baseline? This would be your action; I won't modify the SRS.

---

**Audit complete. No application code was changed. Waiting for the developer to review the findings and agree on the implementation scope before planning or coding.**
