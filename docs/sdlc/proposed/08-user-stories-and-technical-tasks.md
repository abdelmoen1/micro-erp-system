# 08 — User Stories and Technical Tasks

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL**
> **v0.2 (2026-10-13):**
> - **New stories:** US-0109, US-1302.
> - **Changed stories:** US-0101, US-1301, US-0301, US-0703, US-0801, US-0503, US-0201.
> - **Every story that fixes a defect now has a "Regression for" line.**
>
> See [CHANGELOG](CHANGELOG.md).
>
> This document is the **single source of truth** for story IDs, acceptance criteria, estimates and test-case IDs (`TC-<story>-NN`). Documents [01](01-requirements-gap-analysis.md), [07](07-milestones-and-sprints.md) and [09](09-testing-and-definition-of-done.md) reference these IDs.

## How to read a story

| Field | Meaning |
|---|---|
| **Role / Story** | "As a … I want … so that …" |
| **Value** | Why the business cares |
| **Trace** | SRS IDs, decisions and defects |
| **Pre** | Preconditions |
| **AC** | Acceptance criteria in Given/When/Then form; every AC is testable |
| **BE / RE / FL / UX / AI** | Impact on the backend (Laravel), React, Flutter, UI/UX design and AI. "—" means no impact. |
| **Tasks** | Technical subtasks (`T-<story>-n`), separated from functional outcomes |
| **Tests** | `TC-<story>-NN`. Each AC has at least one test. |
| **Deps** | Stories or decisions that must be done first |
| **Pri** | SRS MoSCoW, plus urgency **P0/P1** if it fixes a defect |
| **Est** | Developer-days, including tests and verification. Complexity: S ≤ 0.5, M ≤ 1, L > 1. |
| **DoD** | The standard DoD ([09 §8](09-testing-and-definition-of-done.md#8-definition-of-done)) plus any story-specific additions |

## Epic index

| Epic | Name | Stories |
|---|---|---|
| E01 | Foundations and integrity | US-0101 – US-0109 |
| E02 | Accounts, roles and OTP | US-0201 – US-0205 |
| E03 | Customers and statements | US-0301 – US-0305 |
| E04 | Products and inventory | US-0401 – US-0407 |
| E05 | Sales and invoices | US-0501 – US-0506 |
| E06 | Returns | US-0601 – US-0603 |
| E07 | Debts and payments | US-0701 – US-0705 |
| E08 | Dashboard and insights | US-0801 – US-0803 |
| E09 | Secure debt link and sharing | US-0901 – US-0903 |
| E10 | AI assistant | US-1001 – US-1008 |
| E11 | Offline and synchronization (R2) | US-1101 – US-1107 |
| E12 | Web application shell | US-1201 |
| E13 | Mobile application shell and readiness | US-1301 – US-1306 |
| E14 | Release and operations | US-1401 – US-1405 |
| E15 | UX and design system | US-1501 – US-1508 |

---

# E01 — Foundations and Integrity (Sprint S1)

### US-0101 · Duplicate-safe financial writes

- **Role / Story:** As a shop owner, I want a repeated or retried financial submission to take effect only once, so that customers are never double-charged and records are never duplicated.
- **Value:** Prevents financial corruption (P0). Prerequisite for safe mobile retries and offline sync.
- **Trace:** FR-66 (server), NFR-10, AC-06 (server part), D-04, **DEF-02**.
- **Pre:** D-04 approved; US-0106 route group exists.
- **AC:**
  1. Given a payment request with `Idempotency-Key` K, when the identical request is sent again, then exactly one payment exists and the second response equals the first, with the header `Idempotent-Replay: true`.
  2. Given K was used, when a request with K but a different body is sent, then the response is 409 `IDEMPOTENCY_KEY_REUSED` and nothing is written.
  3. Given a financial endpoint, when no key is sent, then the response is 428 `IDEMPOTENCY_KEY_REQUIRED`.
  4. Given two concurrent requests with the same K, then one record is created and both responses describe the same record.
  5. Given the business transaction fails, then K is not persisted, and a retry with K executes normally.
  6. Given the same K used by two different stores, then each store gets its own result.
  7. Given **every** financial endpoint that exists at the time (data-provider), when the identical request is replayed with the same K, then exactly one business effect exists. Each financial endpoint added by a later story (sales, void, returns, stock adjustments, AI confirm, sync) must be added to this provider; this is part of that story's DoD.
- **BE:** `idempotency_keys` table; `EnsureIdempotency` middleware applied to the endpoints listed in [05 §2](05-data-model-and-api-contracts.md#2-api-conventions-apiv1); the key insert happens inside the service transaction.
- **RE:** — (consumed in US-1201) · **FL:** — (consumed in US-1301/US-0506) · **UX:** — · **AI:** — (used by US-1003/1004)
- **Tasks:**
  - T-0101-1 Migration and model.
  - T-0101-2 Middleware: hash, lookup, replay, 409/428.
  - T-0101-3 `IdempotencyService::runOnce(store, key, hash, callable)` wrapping the DB transaction.
  - T-0101-4 Apply to the existing endpoints: payments, pay-all, opening debt, reversals, and the legacy invoice create until US-0501 replaces it.
  - T-0101-5 Pruning command (> 30 days).
  - T-0101-6 Convert probe DEF-02 into a test.
  - T-0101-7 Data-provider replay test across all financial endpoints (v0.2).
- **Tests:**
  - TC-0101-01 replay → one record.
  - TC-0101-02 mismatch → 409.
  - TC-0101-03 missing key → 428.
  - TC-0101-04 concurrent duplicate (simulated unique violation) → one record.
  - TC-0101-05 failure → key not stored, retry OK.
  - TC-0101-06 per-store scope.
  - TC-0101-07 replay on every financial endpoint (data-provider) → one effect each.
- **Regression for:** DEF-02 → TC-0101-01, TC-0101-07.
- **Deps:** US-0106 · **Pri:** Must · P0 · **Est:** 1.5 dd (L)
- **DoD:** Standard. Additionally, all financial endpoints are listed in a test that asserts they reject a missing key, and appear in the TC-0101-07 provider.

### US-0102 · Exact money handling (2 decimals, NIS)

- **Role / Story:** As an owner, I want all amounts handled exactly to the agora (0.01), so that balances never drift.
- **Value:** Fixes status/amount inconsistencies (DEF-03); a single currency.
- **Trace:** FR-45, BR-03, NFR-11, D-09, **DEF-03**.
- **Pre:** D-09 approved.
- **AC:**
  1. Given a payment of `59.999`, when submitted, then the response is 422 and nothing is written.
  2. Given any API response with money, then the values are strings with 2 decimals and `meta.currency = "ILS"`.
  3. Given a sequence of payments 0.10 + 0.20 on a 0.30 debt, then the remaining amount is exactly `0.00` and the status is `paid`.
  4. Given the MySQL test run, then stored values equal the inputs exactly.
- **BE:** `App\Support\Money` (bcmath); `decimal:0,2` on all money inputs; resources serialize money as strings; existing reversal/payment arithmetic switched to `Money`.
- **RE / FL:** Consume string money (US-1201, US-1301) · **UX:** `MoneyText` spec (US-1501) · **AI:** —
- **Tasks:** T-0102-1 `Money` helper with unit tests · T-0102-2 FormRequest rules · T-0102-3 Resources · T-0102-4 Refactor arithmetic in `PaymentController`/`CustomerDebtController` · T-0102-5 Update the existing test assertions (floats → strings).
- **Tests:** TC-0102-01 3-dp rejected · TC-0102-02 string money and currency meta · TC-0102-03 exact remaining · TC-0102-04 MySQL exactness.
- **Regression for:** DEF-03 → TC-0102-01, TC-0102-03, TC-0102-04; balance invariants across all operations → TC-0703-06 (S3).
- **Deps:** US-0106 · **Pri:** Must · P1 · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0103 · Critical audit log

- **Role / Story:** As an owner, I want every critical action recorded with who did it and when, so that I can investigate disputes and staff errors.
- **Value:** Accountability (FR-70); supports void, reversal, AI and role changes.
- **Trace:** FR-70, FR-39, FR-09, DEF-09.
- **Pre:** —
- **AC:**
  1. Given a payment reversal, then an `audit_logs` row exists with actor, timestamp, action `payment.reversed`, entity and reason.
  2. Given a role change, then `user.role_changed` is logged with the old and new role.
  3. Given an action whose transaction rolls back, then no audit row exists.
  4. Given the API, then no endpoint can update or delete audit rows.
- **BE:** Migration; `AuditService::record()` called inside service transactions; added to reversal, group reversal, role change, invitation and opening-debt create/update. Later stories add their own actions (see [04 §3.7](04-system-architecture.md#37-audit-trail--us-0103)).
- **RE / FL / UX / AI:** — (an audit viewer is not in the MVP)
- **Tasks:** T-0103-1 Migration and model (no update/delete methods) · T-0103-2 Service · T-0103-3 Wire into the existing actions · T-0103-4 Tests.
- **Tests:** TC-0103-01 reversal logged · TC-0103-02 role change logged · TC-0103-03 rollback → no audit row · TC-0103-04 no mutation route exists (route list assertion).
- **Deps:** — · **Pri:** Must · P1 · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0104 · Authentication hardening

- **Role / Story:** As an owner, I want login protected against password guessing and stolen tokens to expire, so that the shop data stays safe.
- **Value:** Security baseline (NFR-08).
- **Trace:** FR-03, NFR-08, **DEF-08**.
- **Pre:** —
- **AC:**
  1. Given 5 failed logins for the same email and IP within a minute, when a 6th is attempted, then the response is 429.
  2. Given a token older than the configured lifetime (30 days), then requests return 401.
  3. Given the production environment checklist, then `APP_DEBUG=false` is enforced. A boot-time check logs a critical warning if production runs with debug enabled.
- **BE:** Rate limiter on `/login` and `/register`; Sanctum `expiration`; environment guard.
- **RE / FL:** Handle 429/401 (US-1201, US-0205) · **UX / AI:** —
- **Tasks:** T-0104-1 Rate limiter · T-0104-2 Expiry configuration · T-0104-3 Debug guard · T-0104-4 Tests.
- **Tests:** TC-0104-01 throttle · TC-0104-02 token expiry · TC-0104-03 debug guard.
- **Regression for:** DEF-08 → TC-0104-01, TC-0104-02; DEF-15 → TC-0104-03.
- **Deps:** — · **Pri:** Must · P1 · **Est:** 0.25 dd (S)
- **DoD:** Standard.

### US-0105 · Role matrix and staff deactivation

- **Role / Story:** As an owner, I want each role limited to its permitted actions and departing staff deactivated rather than deleted, so that permissions are predictable and history is preserved.
- **Value:** Correct RBAC (FR-06); no lost attribution.
- **Trace:** FR-06, FR-07, FR-09, BR-13 basis, NFR-15, D-12, D-13, CR-10, **DEF-04**, **DEF-09**.
- **Pre:** D-12, D-13 approved.
- **AC:**
  1. Given the matrix in [05 §6](05-data-model-and-api-contracts.md#6-authorization-matrix), when each role calls each protected action, then the allowed/denied outcome matches every cell.
  2. Given an owner, when they assign role `owner` to a user, then the request is rejected (422) and the role is unchanged.
  3. Given an owner deactivates an employee, then the employee's tokens are revoked, login returns 403 `USER_INACTIVE`, and the employee's past `payments.created_by` remains intact.
  4. Given a user from another store, when targeted by any staff action, then the response is 404.
- **BE:** Policies: `CustomerPolicy`, `ProductPolicy`, `SalePolicy`, `DebtPolicy`, `PaymentPolicy`, `UserPolicy` (updated); `users.status`; `POST /users/{id}/deactivate` replaces `DELETE`; an `active-user` middleware.
- **RE:** Role-aware navigation (US-1201) · **FL:** Hide forbidden actions (S5) · **UX:** — · **AI:** Tools reuse these policies (US-1002)
- **Tasks:** T-0105-1 Policies · T-0105-2 Remove inline role checks (replaced by policies) · T-0105-3 Deactivation · T-0105-4 Matrix test (data-provider driven) · T-0105-5 Convert probe DEF-04.
- **Tests:** TC-0105-01 full matrix (includes "employee cannot update or void a sale") · TC-0105-02 owner promotion rejected · TC-0105-03 deactivated user blocked and tokens revoked · TC-0105-04 attribution preserved · TC-0105-05 cross-store 404.
- **Regression for:** DEF-04 → TC-0105-02; DEF-09 → TC-0105-03, TC-0105-04; **DEF-05 containment** (employees can no longer edit invoices from S1; full fix in US-0503) → TC-0105-01.
- **Deps:** US-0103 (logging role changes) · **Pri:** Must · P1 · **Est:** 0.75 dd (M)
- **DoD:** Standard. The matrix test covers 100% of the matrix rows.

### US-0106 · API v1 conventions and error envelope

- **Role / Story:** As a client developer (web or mobile), I want one stable, versioned API with predictable errors, so that clients do not break and errors are actionable.
- **Value:** Contract stability for React and Flutter.
- **Trace:** NFR-08, FR-45, D-22, **DEF-14**.
- **Pre:** D-22 approved.
- **AC:**
  1. Given any existing endpoint, then it is served under `/api/v1/...` and the existing feature tests pass against the new paths.
  2. Given a validation or business error, then the response follows the envelope `{message, code, errors, correlation_id}`.
  3. Given an unexpected exception, then the response is 500 with a generic message and a `correlation_id`, and the details are logged (not swallowed).
- **BE:** Route group prefix; exception handler rendering; remove `catch (\Exception)` swallowing in `InvoiceController::store`; `correlation_id` middleware.
- **RE / FL:** Base URL `/api/v1` · **UX / AI:** —
- **Tasks:** T-0106-1 Prefix routes and update tests · T-0106-2 Exception renderer and codes · T-0106-3 Correlation ID · T-0106-4 HTTP request examples (`docs/api/*.http`) for manual checks · **T-0106-5 (v0.4, +0.25 dd)** React base URL → `VITE_API_URL` (default `/api/v1`), DEF-12 fix (`JSON.stringify`), React lint/build CI job.
- **Tests:** TC-0106-01 v1 routes serve; old prefix returns 404 · TC-0106-02 envelope shape · TC-0106-03 500 handling and logging · **TC-0106-04** React CI lint (`no-undef`) + build · **TC-0106-05** browser login smoke against `/api/v1` → `/dashboard`.
- **Regression for:** DEF-14 → TC-0106-03; **DEF-12 → TC-0106-04, TC-0106-05** (v0.4).
- **Deps:** — · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0107 · Store timezone for business dates

- **Role / Story:** As an owner, I want "today", "this week" and due dates computed in my shop's local time, so that late-evening sales count on the correct day.
- **Value:** Correct reports and overdue status.
- **Trace:** FR-37, FR-47, D-23, CR-14, **DEF-07**.
- **Pre:** D-23 value confirmed.
- **AC:**
  1. Given store timezone `Asia/Hebron` and a sale at 23:30 local time, when the "today" dashboard is requested, then the sale is included.
  2. Given week, month and year periods, then the boundaries are computed in the store timezone and returned in `period.timezone`.
- **BE:** `stores.timezone`; `DashboardService::periodBounds` uses the store timezone; shared `BusinessClock` helper.
- **RE / FL:** Display the store timezone · **UX / AI:** —
- **Tasks:** T-0107-1 Migration (default `Asia/Hebron`) · T-0107-2 `BusinessClock` · T-0107-3 Tests with frozen time.
- **Tests:** TC-0107-01 late-evening sale counted today · TC-0107-02 week/month boundaries.
- **Regression for:** DEF-07 → TC-0107-01.
- **Deps:** — · **Pri:** Must · **Est:** 0.25 dd (S)
- **DoD:** Standard.

### US-0108 · MySQL-parity testing and baseline update

- **Role / Story:** As the developer, I want the suite to run on MySQL as well as sqlite and to sweep every route for store isolation, so that green tests mean green production.
- **Value:** Catches decimal and FK differences (DEF-16); proves FR-07 systematically.
- **Trace:** FR-07, NFR-11, D-24, **DEF-16**.
- **Pre:** D-24 approved; a disposable MySQL `hisbah_test` database (local XAMPP or CI service).
- **AC:**
  1. Given the CI workflow, when a push occurs, then PHPUnit runs on sqlite and on MySQL 8, and both must pass.
  2. Given every `/api/v1` route containing a `{model}` parameter, when called with another store's ID, then the response is 404. This is an automated route sweep.
  3. Given `.env.testing`, then it points only at the disposable `hisbah_test` DB. A guard aborts if the DB name lacks `_test`.
- **BE:** `.env.testing` (no secrets committed); `phpunit.mysql.xml`; DB-name guard in `TestCase`; route sweep test.
- **RE / FL:** CI jobs added later (US-1201, US-1301) · **UX / AI:** —
- **Tasks:** T-0108-1 MySQL test configuration and guard · T-0108-2 GitHub Actions workflow · T-0108-3 Route isolation sweep · T-0108-4 README test instructions.
- **Tests:** TC-0108-01 MySQL suite green · TC-0108-02 isolation sweep · TC-0108-03 DB-name guard aborts on a non-test DB.
- **Regression for:** DEF-16 → TC-0108-01.
- **Deps:** — · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard. CI badge or status recorded in the sprint report.

### US-0109 · SRS baseline verification (S1) — *added in v0.2*

- **Role / Story:** As the TL, I want the traceability matrix checked against the SRS file committed in the repository, so that we never build against an unpinned or wrong version.
- **Value:** Closes DEF-18; turns [01](01-requirements-gap-analysis.md) from PROVISIONAL into a verified matrix.
- **Trace:** SRS Change Rule, §12 traceability; D-28; **DEF-18**.
- **Pre:** The TL has committed `docs/srs/Hisbah_Smart_Shop_SRS_v1.1.pdf` and recorded its SHA-256 in `docs/srs/README.md` (see [13 §5](13-final-review-and-decision-pack.md)).
- **AC:**
  1. Given the committed file, then its SHA-256 equals the value in `docs/srs/README.md`.
  2. Given the extracted text, then every ID (FR-01–70, NFR-01–16, BR-01–14, UC-01–22, AC-01–10) exists in both the SRS and the 01 matrix, with no extras and no omissions. Any wording difference that changes meaning is logged.
  3. Given the check passes, then the 01 header changes from PROVISIONAL to VERIFIED, recording the checksum and date.
- **BE / RE / FL / UX / AI:** — (documentation)
- **Tasks:** T-0109-1 Extract the PDF text (needs a PDF text tool such as poppler `pdftotext`, installed as a developer tool and not a project dependency, or a documented manual comparison) · T-0109-2 ID diff · T-0109-3 Update the 01 header and the CHANGELOG.
- **Tests:** TC-0109-01 checksum match · TC-0109-02 ID diff report with zero unexplained differences.
- **Regression for:** DEF-18 → TC-0109-01, TC-0109-02.
- **Deps:** D-28 (TL action) · **Pri:** Must · **Est:** 0.25 dd (S)
- **DoD:** The diff report is committed under `docs/srs/`, and the TL acknowledges it.

---

# E02 — Accounts, Roles and OTP

### US-0201 · Web owner registration (S3)

- **Role / Story:** As a new shop owner, I want to register my shop from the website, so that I can start using Hisbah.
- **Trace:** FR-01, UC-01, **DEF-13**.
- **Pre:** US-1201.
- **AC:**
  1. Given valid owner and shop data, when submitted, then the owner is created, a session is stored, and the dashboard opens.
  2. Given API validation errors, then each error is shown next to its field.
  3. (After US-0203) Given an unverified phone, then registration cannot complete.
- **BE:** — (existing) · **RE:** Wire `Register.jsx` to the `apiClient`; fix the footer link · **FL:** — · **UX:** SCR-W-02 · **AI:** —
- **Tasks:** T-0201-1 Form submission and error mapping · T-0201-2 Session storage via the auth context.
- **Tests:** TC-0201-01 register success and field errors (manual script + build) · TC-0201-02 automated UI regression for registration submit (**conditional on D-32**).
- **Regression for:** DEF-13 → TC-0201-02 if D-32 is approved. Otherwise TC-0201-01 plus a **TL-signed exception**; until then, DEF-13 cannot be marked Closed.
- **Deps:** US-1201 · **Pri:** Must · P1 · **Est:** 0.25 dd (S)
- **DoD:** Standard.

### US-0202 · Web login, logout, current user (S3)

- **Role / Story:** As staff, I want to log in and out on the web and see my store and role, so that I work in the right shop.
- **Trace:** FR-03, FR-04, FR-05, UC-03, **DEF-12**.
- **AC:**
  1. Given valid credentials, when I log in, then I land on the dashboard. The `json.stringify` defect is fixed.
  2. Given I log out, then the token is revoked server-side and the local session is cleared.
  3. Given I am logged in, then the header shows the store name and role from `/me`.
  4. Given a 401 or 429 response, then I see the correct message and am redirected to login (401).
- **BE:** — · **RE:** Auth context; login page; logout; `/me` · **FL / UX / AI:** — (UX: SCR-W-01, SCR-W-04)
- **Tasks:** ~~T-0202-1 Fix `api.js`~~ (done in S1 by T-0106-5, v0.4) · T-0202-2 Auth context · T-0202-3 Logout · T-0202-4 Header.
- **Tests:** TC-0202-01 login → dashboard · TC-0202-02 logout revokes token · TC-0202-03 `/me` header (also the API contract test for FR-05).
- **Regression for:** DEF-12 → TC-1201-01 (automated `oxlint -D no-undef` in CI, which detects this defect) + TC-0202-01.
- **Deps:** US-1201 · **Pri:** Must · P1 · **Est:** 0.25 dd (S)
- **DoD:** Standard.

### US-0203 · Phone OTP at store registration (S6)

- **Role / Story:** As the system owner, I want new stores activated only after phone verification, so that fake or mistyped registrations do not create active shops.
- **Trace:** FR-02, BR-09, UC-01, UC-02, D-14, CR-08.
- **Pre:** D-14 (driver interface now; production provider by S6).
- **AC:**
  1. Given a phone, when an OTP is requested, then a 6-digit code is sent through the configured driver and stored hashed, with a 5-minute expiry.
  2. Given 5 wrong attempts, then the OTP is invalidated and a new request is required.
  3. Given a second request within 60 s, then the response is 429.
  4. Given registration without a valid verification token, then it is rejected.
  5. Given registration with a valid verification token, then the store becomes `active` and `phone_verified_at` is set.
  6. Given an existing pre-OTP store, then it remains `active` (backfill).
- **BE:** `otp_verifications`; `OtpService`; `OtpSender` interface with `LogOtpSender` and a provider driver; `stores.status`; `EnsureStoreActive` middleware.
- **RE:** SCR-W-03 OTP step in registration · **FL:** — · **UX:** SCR-W-03 · **AI:** —
- **Tasks:** T-0203-1 Migration and model · T-0203-2 Service and drivers · T-0203-3 Endpoints and throttles · T-0203-4 Registration integration · T-0203-5 UI step · T-0203-6 Provider configuration (TL credentials).
- **Tests:** TC-0203-01 request and throttle · TC-0203-02 attempt limit · TC-0203-03 expiry · TC-0203-04 store activation gate · TC-0203-05 code hashed at rest.
- **Deps:** US-0201 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard. Provider credentials stored only in the environment.

### US-0204 · Staff management UI (S4)

- **Role / Story:** As an owner, I want to invite staff, change their roles and deactivate them from the web, so that I control who works in my shop.
- **Trace:** FR-08, FR-09, UC-04.
- **AC:**
  1. Given I invite with an email and role, then I receive an invitation link or token to share, with its expiry shown.
  2. Given a staff member, when I change their role between manager and employee, then it is saved and audited.
  3. Given I deactivate a user, then they disappear from the active list and cannot log in.
  4. Given I am a manager, then the Staff menu is hidden and direct navigation shows "not allowed".
- **BE:** — (US-0105) · **RE:** SCR-W-15 · **FL / UX / AI:** — (UX via US-1503)
- **Tasks:** T-0204-1 List · T-0204-2 Invite dialog · T-0204-3 Role change and deactivate with `ConfirmSummary`.
- **Tests:** TC-0204-01 invite · TC-0204-02 role change · TC-0204-03 deactivate · TC-0204-04 manager hidden or blocked.
- **Deps:** US-0105, US-1201 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0205 · Mobile session handling (S1 — moved from S5 in v0.4)

> **v0.4:** moved to S1; estimate 0.5 → 0.75 dd. Adds the screen states invalid credentials, field validation, throttled (countdown from `Retry-After`), inactive account, session expired and network error. Visual styling only after DR-2. Depends on US-1304 (not US-1301). See [14 §4.2](14-sprint-1-execution-plan.md).

- **Role / Story:** As staff, I want to stay logged in securely on my phone and be logged out safely, so that the till is fast but protected.
- **Trace:** FR-03, FR-04, UC-03.
- **AC:**
  1. Given login, then the token is stored in secure storage.
  2. Given app restart, then the session resumes.
  3. Given a 401, then the user returns to login with a message.
  4. Given logout, then the token is revoked and secure storage is cleared.
- **BE:** — · **RE:** — · **FL:** Session controller; router guard · **UX:** SCR-M-01 · **AI:** —
- **Tasks:** T-0205-1 Secure storage · T-0205-2 Router guard · T-0205-3 401 interceptor.
- **Tests:** TC-0205-01 resume, 401 and logout (widget/integration test).
- **Deps:** US-1301 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

---

# E03 — Customers and Statements

### US-0301 · Customer management UI (web, S4)

- **Role / Story:** As staff, I want to search, create, edit and remove customers on the web, so that customer records stay accurate.
- **Trace:** FR-10, FR-11, UC-05.
- **AC:**
  1. Given the list, when I type part of a name or phone, then matching customers appear with their balance badge.
  2. Given a new customer with a 10-digit phone, then it is created; a duplicate phone in my store shows an inline error.
  3. Given a customer with financial history, when an owner or manager deletes them, then a clear "cannot delete" message is shown, and **Deactivate** is offered instead. Employees see neither action.
  4. *(v0.2, FR-11 gap)* Given an owner or manager deactivates a customer, then the customer is hidden from the POS customer picker and from new-sale selection. Their history, statement and outstanding debt remain visible and payable. They can be reactivated, and both actions are audited.
- **BE:** Add a search parameter to `GET /customers` (name/phone) and include `balance` in the resource; align `UpdateCustomerRequest` phone `min:10`; additive `customers.status` (`active`/`inactive`) with `POST /customers/{id}/deactivate` and `/reactivate`; `POST /sales` rejects inactive customers.
- **RE:** SCR-W-06 + form · **FL / AI:** — · **UX:** via US-1503
- **Tasks:** T-0301-1 Search parameter and balance · T-0301-2 List and form · T-0301-3 Delete guard UI · T-0301-4 Customer deactivation (migration, endpoints, audit, UI).
- **Tests:** TC-0301-01 CRUD flows · TC-0301-02 delete blocked with history · TC-0301-03 deactivate/reactivate: hidden from new sales, payments still accepted, audit entries.
- **Deps:** US-1201 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-0302 · Customer summary and chronological statement API (S3)

- **Role / Story:** As an owner, I want a customer's full financial history in date order, with a running balance, so that I can explain any balance.
- **Trace:** FR-12, FR-13, FR-14, UC-06, D-10.
- **Pre:** US-0701, US-0703, US-0601.
- **AC:**
  1. Given a customer with sales, payments, a reversal and a return, then the statement lists every event in chronological order with a running balance.
  2. Given the summary endpoint, then total debt, paid, returned and remaining equal the sums of the statement.
  3. Given another store's customer ID, then the response is 404.
  4. Given voided invoices, then they appear as voided lines with a zero balance effect.
- **BE:** `StatementService`; `GET /customers/{id}/summary`, `GET /customers/{id}/statement?from&to`.
- **RE / FL:** Consumed in US-0303 / US-0705 · **UX / AI:** — (AI uses it via `get_customer_balance`)
- **Tasks:** T-0302-1 Event union query · T-0302-2 Running balance in `Money` · T-0302-3 Endpoints and resources.
- **Tests:** TC-0302-01 chronological order and running balance · TC-0302-02 summary = Σ statement · TC-0302-03 isolation · TC-0302-04 returns, reversals and voids represented.
- **Deps:** US-0601, US-0703 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0303 · Customer detail and statement UI (web, S4)

- **Role / Story:** As a manager, I want one page showing a customer's balance, statement, debts and payments, so that I can answer questions quickly.
- **Trace:** FR-12, FR-13, FR-14, UC-06, BR-01.
- **AC:**
  1. Given a customer, then the KPI row shows total, paid, returned, remaining and overdue.
  2. The Statement tab shows a running balance.
  3. Given I am an owner or manager, then I can edit the credit limit. Employees see it read-only.
- **RE:** SCR-W-07 · **BE / FL / AI:** — · **UX:** via US-1503
- **Tasks:** T-0303-1 Page and tabs · T-0303-2 Credit-limit edit.
- **Tests:** TC-0303-01 statement display · TC-0303-02 credit-limit role gate.
- **Deps:** US-0302, US-0305 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0304 · Customer lookup and quick-create (mobile, S5)

- **Role / Story:** As a cashier, I want to find or create a customer in seconds during checkout, so that credit sales are fast.
- **Trace:** FR-10, UC-05, UC-11.
- **AC:**
  1. Given I type 2 or more characters, then matching customers appear with their balances.
  2. Given there is no match, then "إضافة زبون" creates one with a name and phone, and selects it.
- **FL:** SCR-M-05, SCR-M-07 · **BE:** search parameter (US-0301) · **RE / AI:** — · **UX:** via US-1502
- **Tasks:** T-0304-1 Picker widget · T-0304-2 Quick-create form.
- **Tests:** TC-0304-01 search and quick-create.
- **Deps:** US-0301 (API parameter), US-1301 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0305 · Customer credit limit (S2)

- **Role / Story:** As an owner, I want to set an optional credit limit per customer, so that risky customers cannot accumulate unlimited debt.
- **Trace:** BR-01, UC-11, D-26.
- **AC:**
  1. Given an owner or manager, when they set `credit_limit`, then it is saved. An employee receives 403.
  2. Given `credit_limit` is null, then no limit applies.
  3. (Enforcement is tested in US-0502.)
- **BE:** Migration; validation; policy · **RE:** In US-0303 · **FL / UX / AI:** —
- **Tasks:** T-0305-1 Migration and rules.
- **Tests:** TC-0305-01 set and role gate · TC-0305-02 null = unlimited.
- **Deps:** US-0105 · **Pri:** Must · **Est:** 0.25 dd (S)
- **DoD:** Standard.

---

# E04 — Products and Inventory

### US-0401 · Product catalog API with barcode lookup (S2)

- **Role / Story:** As an owner, I want to register products with a price, stock threshold and optional barcode, so that sales use correct prices and can be scanned.
- **Trace:** FR-15, FR-16, FR-17 (lookup), BR-04, UC-07, CR-13.
- **AC:**
  1. Given valid data (name, price > 0, integer stock ≥ 0, threshold default 5, optional barcode), then the product is created along with an `opening` stock movement.
  2. Given a barcode already used in my store, then the response is 422. The same barcode is allowed in another store.
  3. Given `GET /products/lookup?barcode=X`, then the active product is returned, or 404.
  4. Given a product referenced by sales, when deletion is attempted, then it is refused. Deactivation succeeds and hides the product from POS search.
  5. Given an employee, when they create or update a product, then the response is 403.
  6. Given another store's product ID, then the response is 404.
- **BE:** Migration, model (`BelongsToStore`), `ProductPolicy`, controller, resource, lookup endpoint.
- **RE:** US-0405 · **FL:** US-1301 (lookup), US-0505 · **UX / AI:** — (AI uses `search_products`)
- **Tasks:** T-0401-1 Migration and model · T-0401-2 CRUD, deactivate and lookup · T-0401-3 Tests.
- **Tests:** TC-0401-01 validation · TC-0401-02 barcode uniqueness per store · TC-0401-03 lookup · TC-0401-04 no hard delete when used · TC-0401-05 role gate · TC-0401-06 isolation.
- **Deps:** US-0102, US-0105 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0402 · Stock movements and controlled adjustments (S2)

- **Role / Story:** As a manager, I want every stock change recorded with its reason and source, and to adjust stock when I count shelves, so that stock is accurate and explainable.
- **Trace:** FR-19, FR-20, FR-21, UC-09.
- **AC:**
  1. Given an adjustment (+/−, reason required), then a movement and an audit entry are created, and `current_stock` is updated atomically.
  2. Given an adjustment that would make stock negative, then the response is 422.
  3. Given any sequence of sales, voids, returns and adjustments, then `current_stock = Σ movements`. This is the invariant.
  4. Given an employee, when they adjust stock, then the response is 403.
- **BE:** Migration; `StockService::move()` (lock product row); `POST /stock-adjustments` (idempotent); `GET /products/{id}/movements`; `hisbah:verify-stock` command.
- **RE:** US-0405 · **FL:** US-0407 (R2) · **UX / AI:** —
- **Tasks:** T-0402-1 Migration and model · T-0402-2 `StockService` · T-0402-3 Endpoints · T-0402-4 Verify command.
- **Tests:** TC-0402-01 adjustment with reason and audit · TC-0402-02 no negative stock · TC-0402-03 invariant · TC-0402-04 role gate.
- **Deps:** US-0401, US-0101, US-0103 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0403 · Low-stock detection (S2)

- **Role / Story:** As an owner, I want to see which products are at or below their safety threshold, so that I reorder in time.
- **Trace:** FR-22, BR-11.
- **AC:**
  1. Given no configured threshold, then 5 applies.
  2. Given a custom threshold, then it is used.
  3. Given `GET /products/low-stock`, then it lists active products where `current_stock ≤ minimum_stock`, lowest first.
- **BE:** Scope and endpoint · **RE / FL:** US-0405, US-0406, US-0801 · **UX / AI:** — (AI tool `get_low_stock_products`)
- **Tasks:** T-0403-1 Scope, endpoint and tests.
- **Tests:** TC-0403-01 default 5 · TC-0403-02 custom threshold · TC-0403-03 listing and order.
- **Deps:** US-0401 · **Pri:** Must · **Est:** 0.25 dd (S)
- **DoD:** Standard.

### US-0405 · Products and stock UI (web, S4)

- **Role / Story:** As a manager, I want to manage products and stock in the browser, so that the catalog is ready for the till.
- **Trace:** FR-15, FR-16, FR-20, FR-21, FR-22, UC-07, UC-09.
- **AC:**
  1. Given the products list, then I can search by name or barcode and filter to low stock.
  2. Given the product form, then validation errors show inline and the barcode duplicate error is clear.
  3. Given the product detail, then the movement history is listed and "Adjust stock" requires a reason.
- **RE:** SCR-W-08, SCR-W-09 · **BE / FL / AI:** — · **UX:** via US-1503
- **Tasks:** T-0405-1 List · T-0405-2 Form · T-0405-3 Detail, movements and adjust dialog.
- **Tests:** TC-0405-01 create/edit · TC-0405-02 adjust with reason · TC-0405-03 movement history.
- **Deps:** US-0401–US-0403, US-1201 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0406 · Mobile product search and low-stock view (S5)

- **Role / Story:** As a cashier, I want to search products and see low-stock warnings on my phone, so that I can sell items without barcodes and warn the owner.
- **Trace:** FR-19, FR-22, §9.2 inventory overview.
- **AC:**
  1. Given a search term, then results show name, price and stock.
  2. Given a low-stock product, then a `low_stock` badge is shown, and a filter shows only low-stock items.
- **FL:** SCR-M-11 · **BE / RE / AI:** — · **UX:** via US-1502
- **Tasks:** T-0406-1 List and search · T-0406-2 Badge and filter.
- **Tests:** TC-0406-01 search and low-stock badge.
- **Deps:** US-0403, US-1301 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0407 · Mobile stock adjustment (R2, S10)

- **Role / Story:** As a manager, I want to adjust stock from my phone while counting shelves, so that I do not need a computer.
- **Trace:** FR-20.
- **AC:** Given a manager on mobile, when they adjust with a reason, then the same rules as US-0402 apply. The adjustment is online-only, even in R2 (CR-02).
- **FL:** SCR-M-17 · **BE / RE / AI:** — · **UX:** R2 design
- **Tasks:** T-0407-1 Screen.
- **Tests:** TC-0407-01 mobile adjustment.
- **Deps:** US-0402 · **Pri:** Must (mobile part deferred) · **Est:** 0.5 dd (S)
- **DoD:** Standard.

---

# E05 — Sales and Invoices

### US-0501 · Product-linked cash sale with stock deduction (S2)

- **Role / Story:** As a cashier, I want a sale of scanned products to record the invoice, take the money and reduce stock in one step, so that sales and stock always agree.
- **Trace:** FR-23, FR-24, FR-28, NFR-10, UC-10, D-07, D-08, D-27, CR-04.
- **Pre:** US-0401, US-0402, US-0101, US-0102.
- **AC:**
  1. Given products in stock, when `POST /sales` is sent with items `{product_id, quantity}` and `paid_amount = total`:
     - line prices come from `products.selling_price` (any client price is ignored);
     - stock is reduced with `sale` movements;
     - `paid_amount = total`;
     - no debt is created.
  2. Given a quantity greater than stock, then the response is 422 `INSUFFICIENT_STOCK` and **no** invoice, items or movements exist.
  3. Given a failure injected after the items are inserted, then nothing persists (atomicity).
  4. Given no `customer_id` and full payment, then the sale succeeds as a walk-in sale.
  5. Given a product from another store, then the response is 422 and nothing is written.
  6. Given the same Idempotency-Key, then the original sale is replayed and stock is reduced only once.
- **BE:** Migrations (`invoices` additions, nullable `customer_id`, `invoice_items.product_id`); `SaleService::create`; `POST /sales`; `GET /sales` (rename of invoices list); legacy `POST /invoices` removed.
- **RE:** — (D-30) · **FL:** US-0506 · **UX / AI:** — (AI: US-1004 reuses `SaleService`)
- **Tasks:** T-0501-1 Migrations with backfill (`paid_amount`) · T-0501-2 `SaleService` (lock order) · T-0501-3 Request and resource · T-0501-4 Remove the legacy create path and update tests.
- **Tests:** TC-0501-01 cash sale happy path (DB prices, stock, movement) · TC-0501-02 insufficient stock → nothing written · TC-0501-03 fault injection atomicity · TC-0501-04 walk-in · TC-0501-05 foreign product · TC-0501-06 idempotent replay.
- **Deps:** US-0401, US-0402, US-0101, US-0102 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-0502 · Credit and partial-payment sale with automatic debt (S2)

- **Role / Story:** As a cashier, I want to record "3 cartons at 15 ₪, paid 20, the rest on credit" in one sale, so that the debt is created correctly without extra steps.
- **Trace:** FR-25, FR-26, FR-27, FR-36, BR-01, UC-11, AC-03, D-26.
- **Pre:** US-0501, US-0701, US-0305.
- **AC:**
  1. Given `paid_amount = 0` and a customer, then one debt equal to the total is created.
  2. Given total 45.00 and paid 20.00, then `invoice.paid_amount = 20.00` and a debt of 25.00 (remaining 25.00, status `unpaid`) is created, linked to the customer.
  3. Given the sale commits, then the invoice total, paid amount, debt and stock are all consistent (AC-03).
  4. Given a credit limit of 100 with an outstanding 90, when a sale would add 25 of debt, then the response is 422 `CREDIT_LIMIT_EXCEEDED` and nothing is written.
  5. Given `paid_amount < total` with no customer, then the response is 422.
  6. Given `due_date`, then it is stored on the debt and must not be in the past (store timezone).
- **BE:** `SaleService` debt branch; credit-limit check under a customer row lock.
- **RE:** — · **FL:** US-0506 · **UX:** US-1502 · **AI:** US-1004
- **Tasks:** T-0502-1 Debt creation · T-0502-2 Credit-limit check · T-0502-3 Due-date validation · T-0502-4 Tests.
- **Tests:** TC-0502-01 full credit · TC-0502-02 partial (SRS example) · TC-0502-03 cross-record consistency · TC-0502-04 credit limit · TC-0502-05 customer required · TC-0502-06 due date.
- **Deps:** US-0501, US-0701, US-0305 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0503 · Invoice immutability and void (S2)

- **Role / Story:** As an owner, I want sales to be unchangeable after they are recorded and corrected only by a controlled void, so that nobody can silently alter takings.
- **Trace:** FR-30, FR-31, BR-07, FR-70, D-06, CR-03, **DEF-01**, **DEF-05**, **DEF-06**, **DEF-11**.
- **AC:**
  1. Given `PATCH /sales/{id}` with items, totals, customer or payment fields, then the response is 422. Notes remain editable by owner and manager.
  2. Given an employee, when they void, then the response is 403.
  3. Given a sale whose debt has non-reversed payments, or which has returns, when voided, then the response is 409 with a clear reason.
  4. Given a valid void with a reason:
     - status becomes `voided`;
     - stock is restored through `sale_void` movements;
     - the debt becomes `cancelled` with remaining 0;
     - an audit entry is written;
     - nothing is hard-deleted.
  5. Given the old DEF-01 scenario, then no HTTP 500 is possible. The conversion path and delete endpoint no longer exist, which is verified by a test.
  6. Given any request that reassigns the customer, then it is rejected.
- **BE:** `SaleService::void`; remove the destroy and update-financial-fields logic; update the tests that asserted the old behaviour.
- **RE:** Void in US-0504 · **FL:** — · **UX:** `ReasonDialog` · **AI:** —
- **Tasks:** T-0503-1 Void service · T-0503-2 Restrict PATCH · T-0503-3 Remove DELETE · T-0503-4 Rewrite affected existing tests · T-0503-5 Convert probes DEF-01 and DEF-05.
- **Tests:**
  - TC-0503-01 financial edit rejected **for each of owner, manager and employee**; notes allowed for owner and manager.
  - TC-0503-02 employee void 403.
  - TC-0503-03 void blocked by payments or returns.
  - TC-0503-04 void effects: stock, debt, audit; the invoice row still exists.
  - TC-0503-05 no 500 (DEF-01 regression), and **no `DELETE` route exists** for sales or invoices (route-list assertion).
  - TC-0503-06 no customer reassignment.
- **Regression for:** DEF-01 → TC-0503-05; DEF-05 → TC-0503-01; DEF-06 → TC-0503-04, TC-0503-05; DEF-11 → TC-0503-06.
- **Deps:** US-0501, US-0103 · **Pri:** Must · P0 · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0504 · Sales list and detail with void (web, S4)

- **Role / Story:** As a manager, I want to review sales and void mistaken ones on the web, so that I can correct errors properly.
- **Trace:** FR-29, FR-30, FR-31.
- **AC:**
  1. Given the list, then I can filter by date range, type (cash/credit/partial) and status.
  2. Given a sale with payments, then the Void button is disabled and a tooltip explains why.
  3. Given a void, then the reason is mandatory, the summary is shown first, and the detail updates to "voided".
- **RE:** SCR-W-10, SCR-W-11 · **BE / FL / AI:** — · **UX:** via US-1503
- **Tasks:** T-0504-1 List with filters · T-0504-2 Detail · T-0504-3 Void dialog.
- **Tests:** TC-0504-01 filters · TC-0504-02 void dialog and disabled state.
- **Deps:** US-0503, US-1201 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0505 · Mobile POS cart with barcode scanning (S5)

- **Role / Story:** As a cashier, I want to scan products with the phone camera and have repeat scans increase the quantity, so that checkout is fast.
- **Trace:** FR-17, FR-18, NFR-02, AC-01, AC-02, UC-08.
- **AC:**
  1. Given a known barcode under normal light on the reference device, then the product is in the cart within 1.5 s.
  2. Given the same barcode scanned again, then the existing line's quantity increases by 1. No duplicate line is created.
  3. Given an unknown barcode, then a clear message is shown and a manual search is offered.
  4. Given the camera permission is denied, then manual search remains fully usable.
  5. Given a quantity above available stock, then the stepper caps it and shows a warning. The server remains the authority.
- **FL:** SCR-M-02, SCR-M-03; cart state (Riverpod) · **BE:** — (lookup exists) · **RE / AI:** — · **UX:** US-1502
- **Tasks:** T-0505-1 Scanner overlay · T-0505-2 Cart model and repeat-scan rule · T-0505-3 Manual search · T-0505-4 Device timing run.
- **Tests:** TC-0505-01 scan-to-cart timing (device) · TC-0505-02 repeat scan increments (widget test) · TC-0505-03 unknown barcode · TC-0505-04 camera denied fallback.
- **Deps:** US-1301, US-0401 · **Pri:** Must · **Est:** 1.5 dd (L)
- **DoD:** Standard. Timing evidence is recorded.

### US-0506 · Mobile checkout: cash, credit or partial (S5)

- **Role / Story:** As a cashier, I want to finish a sale as cash, credit or partial with a clear summary, so that I never record the wrong amount.
- **Trace:** FR-23–27, UC-10, UC-11, FR-66 (client), UI-AC-02, UI-AC-03.
- **AC:**
  1. Given a full cash payment, then the sale completes in ≤ 4 taps after the last scan.
  2. Given a partial or credit sale, then customer selection is required, the debt amount is previewed, and a due date is optional.
  3. Given a network timeout after confirm, when I retry, then the same Idempotency-Key is used and only one sale exists.
  4. Given a 422 error (stock or credit limit), then the message is shown and the cart is preserved.
  5. Given success, then a receipt screen shows the sale number, total, paid amount and debt.
- **FL:** SCR-M-04, SCR-M-06; persisted pending-request key · **BE:** — · **RE / AI:** — · **UX:** US-1502
- **Tasks:** T-0506-1 Checkout form · T-0506-2 `ConfirmSummary` · T-0506-3 Idempotent submit with persisted key · T-0506-4 Error mapping · T-0506-5 Receipt.
- **Tests:** TC-0506-01 cash flow · TC-0506-02 partial requires customer · TC-0506-03 retry produces no duplicate (integration test against the local API) · TC-0506-04 422 keeps the cart.
- **Deps:** US-0505, US-0304, US-0502 · **Pri:** Must · **Est:** 1.25 dd (L)
- **DoD:** Standard.

---

# E06 — Returns

### US-0601 · Sale return API (S3)

- **Role / Story:** As a manager, I want to return specific items from a sale, so that stock is restored and the customer's balance or refund is correct.
- **Trace:** FR-32, FR-33, AC-04, UC-12, D-05, CR-05.
- **Pre:** D-05 approved.
- **AC:**
  1. Given a cash sale, when 1 unit is returned, then stock +1, the refund equals 1 × the original unit price, and an audit entry exists.
  2. Given an unpaid credit sale, when items are returned, then the debt `return_credit` increases by the return value and the refund is 0.
  3. Given a partially paid sale with remaining 5.00, when a return worth 15.00 is processed, then the debt is reduced by 5.00 (remaining 0, status `paid`) and the refund is 10.00.
  4. Given a returned quantity greater than sold minus already returned, then the response is 422 and nothing is written.
  5. Given a voided sale, then the response is 422.
  6. Given an employee, then the response is 403.
  7. Given the same Idempotency-Key, then the return is processed once.
- **BE:** Migrations (`sale_returns`, `sale_return_items`, `invoice_items.returned_quantity`, `debts.return_credit` from US-0701); `ReturnService`; endpoints.
- **RE:** US-0602 · **FL:** US-0603 (R1.1) · **UX / AI:** —
- **Tasks:** T-0601-1 Migrations · T-0601-2 `ReturnService` (lock order, debt-first) · T-0601-3 Endpoints and resources · T-0601-4 Tests.
- **Tests:** TC-0601-01 cash refund · TC-0601-02 credit reduction · TC-0601-03 partial with excess refund · TC-0601-04 over-return rejected · TC-0601-05 voided rejected · TC-0601-06 role gate · TC-0601-07 idempotent.
- **Deps:** US-0503, US-0701, US-0402 · **Pri:** Must · **Est:** 1.25 dd (L)
- **DoD:** Standard.

### US-0602 · Return UI (web, S4)

- **Role / Story:** As a manager, I want a return dialog that shows exactly what will happen before I confirm, so that I do not make costly mistakes.
- **Trace:** FR-32, FR-33, UC-12, UI-AC-08.
- **AC:**
  1. Given a sale, then quantity inputs are limited to returnable quantities.
  2. A preview shows the return value, debt reduction and cash refund.
  3. A reason is required.
  4. After confirm, the sale detail shows the return and the updated amounts.
- **RE:** SCR-W-12 · **BE / FL / AI:** — · **UX:** via US-1503
- **Tasks:** T-0602-1 Dialog · T-0602-2 Client-side preview (display only; the server is authoritative).
- **Tests:** TC-0602-01 preview and over-return prevention.
- **Deps:** US-0601, US-0504 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0603 · Mobile return (R1.1, S8)

- **Role / Story:** As a manager at the counter, I want to process a return on the phone, so that I do not need the computer.
- **Trace:** FR-32, UC-12.
- **AC:** Given a manager on mobile, when they select a sale, items and quantities, then the same rules and preview as US-0602 apply. The return is online-only (CR-02).
- **FL:** SCR-M-15 · **BE / RE / AI:** — · **UX:** R1.1 design
- **Tasks:** T-0603-1 Sale search · T-0603-2 Return form and confirm.
- **Tests:** TC-0603-01 mobile return flow.
- **Deps:** US-0601 · **Pri:** Must (mobile part deferred) · **Est:** 0.75 dd (M)
- **DoD:** Standard.

---

# E07 — Debts and Payments

### US-0701 · Debt schema extension, due dates and opening debts (S2)

- **Role / Story:** As an owner, I want every debt tied to its customer with an optional due date, so that I can track who owes what and when.
- **Trace:** FR-34, FR-35, FR-36, D-10.
- **AC:**
  1. Given existing debts, when the migration runs, then every debt has a `customer_id` equal to its invoice's customer. A migration test asserts a 100% match.
  2. Given an opening debt with `due_date`, then it is stored. A past date is allowed for legacy debts (they become overdue immediately).
  3. Given `GET /debts/{id}`, then the response includes original, paid, returned, remaining, customer, invoice, `created_at`, `due_date` and status.
- **BE:** Migration and backfill; `DebtResource`/`DebtDetailsResource` updates; `StoreDebtRequest` adds `due_date`.
- **RE:** US-0704 · **FL:** US-0705 · **UX / AI:** —
- **Tasks:** T-0701-1 Migration and backfill · T-0701-2 Resources · T-0701-3 Tests.
- **Tests:** TC-0701-01 backfill · TC-0701-02 opening debt with due date · TC-0701-03 details fields.
- **Deps:** US-0102 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard. Migration rollback (`down`) is tested.

### US-0702 · Due, overdue and highest-balance lists (S3)

- **Role / Story:** As an owner, I want lists of debts due today, due this week, overdue, and by highest balance, so that I know whom to follow up.
- **Trace:** FR-37, FR-41, FR-42, UC-15.
- **AC:**
  1. Given the store timezone, then "due today" includes debts whose `due_date` is the local today and whose remaining is > 0.
  2. Given paid or cancelled debts, then they are never listed as overdue.
  3. Given `sort=balance`, then customers are ordered by total remaining, descending.
  4. Given the outstanding endpoint, then the total equals Σ remaining.
- **BE:** `DebtService` scopes; query parameters on `GET /debts`.
- **RE:** US-0704 · **FL:** US-0705 · **UX / AI:** — (AI: `get_total_outstanding_debt`)
- **Tasks:** T-0702-1 Scopes and parameters · T-0702-2 Tests at boundary times.
- **Tests:** TC-0702-01 due today at the timezone boundary · TC-0702-02 overdue excludes paid/cancelled · TC-0702-03 highest-balance order · TC-0702-04 outstanding total.
- **Deps:** US-0701, US-0107 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0703 · Payments v1: attribution, history and group-safe reversal (S3)

- **Role / Story:** As a manager, I want payments that are exact, attributable and reversible only in whole operations, so that the payment history stays trustworthy.
- **Trace:** FR-38, FR-39, FR-40, D-10, D-11, **DEF-10**.
- **AC:**
  1. Given a payment, then it stores `store_id`, `customer_id` and `created_by`. The amount is exact to 2 decimals, and the request is idempotent (US-0101).
  2. Given a payment that belongs to a pay-all group, when single reversal is attempted, then the response is 422 `REVERSE_GROUP_REQUIRED`.
  3. Given a group reversal, then all payments are reversed, with `reversed_by`, the reason and an audit entry, and the debts are recomputed from facts.
  4. Given `GET /payments?customer_id=` or `?invoice_id=`, then only that context is returned.
  5. Given existing payments, when the migration runs, then `store_id` and `customer_id` are backfilled correctly.
  6. *(v0.2)* Given a randomized sequence of sales (cash, credit, partial), payments, single and group reversals, returns and voids, then every financial invariant in [05 §1.3](05-data-model-and-api-contracts.md#13-integrity-rules) holds on sqlite **and** MySQL.
- **BE:** Migration and backfill; `PaymentService` (moves logic out of the controller); recompute formula including `return_credit`.
- **RE:** US-0704 · **FL:** US-0705 · **UX:** — · **AI:** US-1003 reuses `PaymentService`
- **Tasks:** T-0703-1 Migration and backfill · T-0703-2 `PaymentService` · T-0703-3 Group rule · T-0703-4 Filters · T-0703-5 Tests · T-0703-6 Invariant test with a seeded randomized sequence (fixed seed recorded for reproducibility).
- **Tests:** TC-0703-01 exact and idempotent payment · TC-0703-02 single reversal in a group blocked · TC-0703-03 group reversal attribution and audit · TC-0703-04 history filters · TC-0703-05 backfill · TC-0703-06 financial invariants after a randomized sequence.
- **Regression for:** DEF-10 → TC-0703-02; DEF-03 (balance accuracy across operations) → TC-0703-06.
- **Deps:** US-0101, US-0102, US-0103, US-0701 (TC-0703-06 also needs US-0601 and US-0503) · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-0704 · Debts and payments UI (web, S4)

- **Role / Story:** As a manager, I want to see debt lists, record and reverse payments, and add opening debts on the web, so that I can manage collections from the office.
- **Trace:** FR-34, FR-38, FR-39, FR-40, FR-42, UC-13, UC-14, UC-15.
- **AC:**
  1. The debts page has tabs: due today, this week, overdue, highest balance and all, with status badges (text + colour).
  2. Record payment shows the remaining-after amount before confirm.
  3. Reverse requires a reason. Grouped operations reverse as a group, with a clear label.
  4. An owner or manager can add an opening debt with a due date.
- **RE:** SCR-W-13, SCR-W-14 · **BE / FL / AI:** — · **UX:** via US-1503
- **Tasks:** T-0704-1 Debts tabs · T-0704-2 Payment dialog · T-0704-3 Reversal dialog · T-0704-4 Opening debt form.
- **Tests:** TC-0704-01 record payment · TC-0704-02 reverse single and group · TC-0704-03 tabs · TC-0704-04 opening debt.
- **Deps:** US-0702, US-0703, US-1201 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-0705 · Mobile debts and payment recording (S5)

- **Role / Story:** As a cashier, I want to see what a customer owes and record their payment on the phone, so that collections happen at the counter.
- **Trace:** FR-14, FR-38, UC-13.
- **AC:**
  1. The customer detail shows remaining, overdue and open debts.
  2. Record payment pre-fills "full remaining", accepts a custom amount (2 decimals), and shows a summary before confirm.
  3. A retry after a timeout does not duplicate the payment (same key).
- **FL:** SCR-M-08, SCR-M-09 · **BE / RE / AI:** — · **UX:** US-1502
- **Tasks:** T-0705-1 Customer detail · T-0705-2 Payment form with idempotent submit.
- **Tests:** TC-0705-01 record payment flow · TC-0705-02 retry produces no duplicate.
- **Deps:** US-0703, US-0304 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

---

# E08 — Dashboard and Insights

### US-0801 · Dashboard metrics v2 (S3)

- **Role / Story:** As an owner, I want sales, collections, new debt, outstanding debt, low stock and actionable alerts for a chosen period, so that I understand my shop at a glance.
- **Trace:** FR-41, FR-46, FR-47, FR-48, AC-10, D-08, CR-09.
- **AC:**
  1. Collections = Σ `paid_amount` of non-voided sales + Σ non-reversed debt payments in the period, returned as separate figures plus a total.
  2. `low_stock_count` and a top-5 low-stock list are included.
  3. Insight cards: overdue (count and amount), due today, top 5 balances.
  4. Voided sales are excluded from sales totals, and returns are reported as a separate figure.
  5. *(v0.2, FR-46 gap)* **New debt in the period** = Σ debts created in the period (sale remainders + opening debts) − debts cancelled by void in the period. It is shown next to outstanding debt.
- **BE:** Extend `DashboardService` (keeping its existing period and bucket logic) · **RE:** US-0802 · **FL:** US-0803 · **UX / AI:** — (AI `get_sales_summary` reuses this service)
- **Tasks:** T-0801-1 Collections · T-0801-2 Low stock · T-0801-3 Insights · T-0801-4 Update the existing dashboard tests.
- **Tests:** TC-0801-01 collections breakdown · TC-0801-02 low-stock metrics · TC-0801-03 insights · TC-0801-04 voided and returns handling per period · TC-0801-05 new-debt metric.
- **Deps:** US-0403, US-0702, US-0501 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-0802 · Web dashboard (S3)

- **Role / Story:** As an owner, I want the dashboard on the web, so that I can review the shop daily.
- **Trace:** FR-46–48, UC-17, AC-10.
- **AC:**
  1. The period filter updates KPI cards, insight cards and the CSS bar charts.
  2. A new store sees helpful empty states.
  3. Clicking an insight card navigates to the related list.
- **RE:** SCR-W-05 · **BE / FL / AI:** — · **UX:** US-1501
- **Tasks:** T-0802-1 KPI and insight cards · T-0802-2 Charts · T-0802-3 Empty states.
- **Tests:** TC-0802-01 period switch · TC-0802-02 empty state.
- **Deps:** US-0801, US-1201 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0803 · Mobile dashboard summary (S5)

- **Role / Story:** As a cashier or owner, I want today's key numbers on the phone home screen, so that I see the day's progress.
- **Trace:** FR-46, FR-47, UC-17.
- **AC:** The home screen shows sales, collections and outstanding debt for the selected period, plus alert counts. The numbers equal the web dashboard for the same period.
- **FL:** SCR-M-10 · **BE / RE / AI:** — · **UX:** US-1502
- **Tasks:** T-0803-1 Home screen.
- **Tests:** TC-0803-01 parity with the web numbers.
- **Deps:** US-0801, US-1301 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

---

# E09 — Secure Debt Link and Sharing (R1.1, S8)

### US-0901 · Secure debt-link API

- **Role / Story:** As an owner, I want to generate an expiring, revocable statement link for a customer, so that they can check their balance without seeing anyone else's data.
- **Trace:** FR-43, BR-06, NFR-09, NFR-15, AC-05, UC-16, D-17, CR-07.
- **AC:**
  1. Given generation, then the token is a UUIDv4, only its SHA-256 hash is stored, and the plaintext URL is returned once.
  2. Given the public URL, then it contains only the token (no customer, store or sequential IDs), and the payload contains no phone number and no internal IDs.
  3. Given more than 30 days have passed, then the link returns 404 with a neutral message.
  4. Given a regenerate or revoke action, then the previous token stops working immediately.
- **BE:** Migration; `DebtLinkService`; owner/manager endpoints; public endpoint (throttled, `noindex` header); audit entries.
- **RE:** US-0902 · **FL:** US-0903 · **UX / AI:** —
- **Tasks:** T-0901-1 Migration and service · T-0901-2 Endpoints · T-0901-3 Public payload minimisation.
- **Tests:** TC-0901-01 UUIDv4 and hashed at rest · TC-0901-02 no IDs or phone in the URL and payload · TC-0901-03 30-day expiry · TC-0901-04 regenerate and revoke.
- **Deps:** US-0302 · **Pri:** Should · **Est:** 0.75 dd (M)
- **DoD:** Standard plus a security review checklist ([10 §5](10-ai-assisted-sdlc-workflow.md)).

### US-0902 · Public statement page

- **Role / Story:** As a shop customer, I want to open the link and see my statement clearly on my phone, so that I know what I owe.
- **Trace:** FR-43, NFR-07, UC-06.
- **AC:**
  1. Given a valid link, then the page shows the store name, customer display name, chronological lines and totals in Arabic RTL.
  2. Given an invalid or expired link, then a neutral page is shown with no data.
  3. On a 4G-throttled Lighthouse run, the page loads in ≤ 3 s.
- **RE:** SCR-W-17 (public route `/s/:token`, lightweight bundle) · **BE / FL / AI:** — · **UX:** R1.1 design
- **Tasks:** T-0902-1 Page · T-0902-2 Performance check.
- **Tests:** TC-0902-01 renders · TC-0902-02 invalid page · TC-0902-03 4G load time.
- **Deps:** US-0901 · **Pri:** Should · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-0903 · Share via WhatsApp

- **Role / Story:** As an owner, I want to send the link via WhatsApp with a ready message, so that sharing takes one tap.
- **Trace:** FR-44, UC-16.
- **AC:** Given a generated link:
  - on mobile, the OS share sheet opens with the Arabic text and link;
  - on the web, a `wa.me` link opens with the text prefilled (the customer phone is used if present);
  - nothing is sent automatically (no campaigns, per SRS §1.9).
- **FL:** SCR-M-14 · **RE:** Button on SCR-W-07 · **BE / AI:** — · **UX:** R1.1 design
- **Tasks:** T-0903-1 Mobile share · T-0903-2 Web share.
- **Tests:** TC-0903-01 share content includes the link and text.
- **Deps:** US-0901 · **Pri:** Should · **Est:** 0.25 dd (S)
- **DoD:** Standard.

---

# E10 — AI Assistant (R1.1, S7–S8)

### US-1001 · AI provider adapter and evaluation spike

- **Role / Story:** As the TL, I want a provider-independent AI integration chosen by measured Arabic performance, so that the assistant is reliable and replaceable.
- **Trace:** FR-49, FR-61, FR-63, NFR-15, D-15.
- **AC:**
  1. Given the 30-utterance evaluation set, then a report records intent accuracy, entity accuracy, refusal correctness, latency and cost for the candidate provider(s).
  2. Given a provider timeout or error, then the user receives a recoverable error, no draft or business record is created, and a retry is possible.
  3. Given any client, then the provider API key is never exposed (it is server-side only).
  4. Conversations and messages are stored, with a 90-day retention command.
- **BE:** `AiClient` interface and one implementation; `ai_conversations`, `ai_messages`; orchestrator loop with tool allow-list; timeout and retry policy.
- **RE / FL:** US-1005/1006 · **UX:** — · **AI:** Core
- **Tasks:** T-1001-1 Evaluation set (TL reviews the utterances) · T-1001-2 Adapter · T-1001-3 Orchestrator · T-1001-4 Retention command.
- **Tests:** TC-1001-01 timeout → no records and retry · TC-1001-02 no key in any response or bundle · TC-1001-03 evaluation report produced.
- **Deps:** R1 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard plus the evaluation report attached.

### US-1002 · AI read tools and daily summary

- **Role / Story:** As an owner, I want to ask "كم بعت اليوم؟" or "قديش على أبو محمد؟" and get answers from my real data, so that I do not navigate screens.
- **Trace:** FR-50, FR-51, FR-52, FR-61, FR-62, BR-13, BR-14, AC-09, UC-18.
- **AC:**
  1. Given "today's sales", then the answer's figures equal `GET /dashboard?period=today`.
  2. Given an ambiguous customer name, then the assistant lists candidates and asks; it does not guess.
  3. Given tools executed for a store A user, then no store B data can be returned, even if the model requests a store B ID (AC-09).
  4. Given an employee asking for a manager-only action (e.g., reversal), then the assistant explains it is not permitted; no tool exists for it (BR-13).
  5. Given "daily summary", then the summary's numbers match the dashboard and low-stock data.
- **BE:** Tool registry with the 7 read tools ([05 §5](05-data-model-and-api-contracts.md#5-ai-tool-contracts-r11)), each invoking existing services under the user's policies.
- **RE / FL:** — · **UX:** — · **AI:** Prompts and tool schemas
- **Tasks:** T-1002-1 Registry and schemas · T-1002-2 Tools · T-1002-3 System prompt (Arabic) · T-1002-4 Tests with a faked provider.
- **Tests:** TC-1002-01 sales tool parity · TC-1002-02 ambiguity → candidates · TC-1002-03 cross-store denial · TC-1002-04 permission boundary · TC-1002-05 summary parity.
- **Deps:** US-1001, US-0801, US-0302, US-0403 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-1003 · AI payment draft with preview and confirmation

- **Role / Story:** As a cashier, I want to say "أبو محمد دفع 50 شيكل" and confirm a preview, so that payments are fast but never automatic.
- **Trace:** FR-53–57, FR-59, FR-63, BR-02, UC-20, D-29.
- **AC:**
  1. Given a payment request, then a draft is created and the preview shows the customer, amount, allocation and remaining-after. On confirm, exactly one payment is recorded through `PaymentService`.
  2. Given no confirm, then no payment exists (BR-02).
  3. Given a double confirm, then one payment exists (the idempotency key is the draft ID).
  4. Given an expired draft (> 10 min), then confirm returns 422 `DRAFT_EXPIRED`.
  5. Given another user, when they try to confirm the draft, then the response is 404.
  6. Given the balance changed between draft and confirm, then confirm re-validates and fails cleanly if the payment is now invalid.
- **BE:** `ai_action_drafts`; `draft_payment` tool; confirm and cancel endpoints; audit `ai_draft.confirmed`.
- **RE / FL:** Preview UI (US-1005/1006) · **UX:** US-1504 · **AI:** Tool schema
- **Tasks:** T-1003-1 Drafts table · T-1003-2 Tool · T-1003-3 Confirm/cancel · T-1003-4 Tests.
- **Tests:** TC-1003-01 draft → confirm → one payment · TC-1003-02 no confirm → nothing · TC-1003-03 double confirm → one · TC-1003-04 expired · TC-1003-05 other user · TC-1003-06 re-validation at confirm.
- **Deps:** US-1002, US-0703 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-1004 · AI invoice draft with preview and confirmation

- **Role / Story:** As a cashier, I want to say "سجل لأبو محمد 3 كراتين مياه، دفع 20 والباقي دين" and confirm an exact preview, so that I can record a sale by voice or text.
- **Trace:** FR-53–58, FR-62, BR-14, AC-08, UC-19, D-29.
- **AC:**
  1. Given the request, then the preview shows lines with **DB prices**, the total, paid amount and resulting debt. The executed sale equals the preview (AC-08).
  2. Given cancel, then nothing is written.
  3. Given the model supplies a price, then it is ignored; the DB price is used.
  4. Given an unknown or ambiguous product, then the assistant asks for clarification; no draft is made.
  5. Given insufficient stock at confirm time, then the response is 422 and no partial record exists.
- **BE:** `draft_invoice` tool; reuses `SaleService` validation and execution.
- **RE / FL:** US-1005/1006 · **UX:** US-1504 · **AI:** Tool schema and prompt examples
- **Tasks:** T-1004-1 Tool · T-1004-2 Preview builder · T-1004-3 Tests.
- **Tests:** TC-1004-01 preview = executed sale · TC-1004-02 cancel → nothing · TC-1004-03 model price ignored · TC-1004-04 ambiguity → question · TC-1004-05 stock failure at confirm.
- **Deps:** US-1003, US-0502 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-1005 · Web AI chat

- **Role / Story:** As an owner, I want the assistant on the web with the same preview and confirm, so that I can use it at the desk.
- **Trace:** FR-49, FR-56, FR-57, UI-AC-09.
- **AC:** Given a draft, then a preview panel appears; Confirm and Cancel are equal-size; Cancel never calls confirm. The "AI unavailable" state has a retry.
- **RE:** SCR-W-16 · **BE / FL:** — · **UX:** US-1504 · **AI:** —
- **Tasks:** T-1005-1 Chat · T-1005-2 Preview panel.
- **Tests:** TC-1005-01 preview, confirm and cancel behaviour.
- **Deps:** US-1003 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-1006 · Mobile AI chat

- **Role / Story:** As a cashier, I want the assistant on the phone, so that I can ask and act quickly.
- **Trace:** FR-49, FR-56, FR-57, UI-AC-09.
- **AC:** Same as US-1005 on SCR-M-12/13. When offline, a clear "AI needs internet" state is shown (SRS §2.3 offline rule).
- **FL:** SCR-M-12, SCR-M-13 · **BE / RE:** — · **UX:** US-1504 · **AI:** —
- **Tasks:** T-1006-1 Chat · T-1006-2 Preview sheet.
- **Tests:** TC-1006-01 preview, confirm, cancel and offline state.
- **Deps:** US-1003 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-1007 · Mobile voice input (S8)

- **Role / Story:** As a cashier with busy hands, I want to speak my request, so that the assistant works without typing.
- **Trace:** FR-60, UC-21, D-16, CR-12.
- **AC:**
  1. Given microphone permission, then speech (Arabic locale) is transcribed, shown for editing, and sent to the **same** `/ai/messages` endpoint as text.
  2. Given permission is denied, then text input remains available.
- **FL:** Mic button on SCR-M-12 · **BE / RE:** — · **UX:** US-1504 · **AI:** —
- **Tasks:** T-1007-1 Speech plugin and permission · T-1007-2 Transcript edit.
- **Tests:** TC-1007-01 transcript → same endpoint; denied → fallback.
- **Deps:** US-1006 · **Pri:** Unclear (see [01](01-requirements-gap-analysis.md) FR-60) · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-1008 · Web voice input (R2, optional)

- **Role / Story:** As an owner on a supporting browser, I want voice input on the web.
- **Trace:** FR-60, CR-12.
- **AC:** On browsers with the Speech Recognition API, the mic button works; elsewhere it is hidden.
- **RE:** SCR-W-16 · **BE / FL / UX / AI:** —
- **Tasks:** T-1008-1 Feature-detected mic button.
- **Tests:** TC-1008-01 supported vs hidden.
- **Deps:** US-1005 · **Pri:** Could · **Est:** 0.5 dd (S) — *not in the baseline estimate*
- **DoD:** Standard.

---

# E11 — Offline and Synchronization (R2, S9–S10)

### US-1101 · Batch sync API with conflict state

- **Role / Story:** As the system, I want to accept queued device transactions in order, exactly once, without discarding any, so that offline work reconciles safely.
- **Trace:** FR-65, FR-66, BR-10, UC-22, D-03.
- **AC:**
  1. Given a batch, then items are processed in `seq` order, each in its own transaction, and results are returned per item.
  2. Given an already-applied `client_transaction_id`, then the result is `duplicate` with the original `server_id` and no effect.
  3. Given a payment exceeding the remaining debt, then the result is `conflict` and the item is stored in `sync_conflicts` (not applied, not discarded).
  4. Given a sale causing negative stock, then the result is `flagged` with `NEGATIVE_STOCK`, and the sale is recorded.
- **BE:** `/sync/batch`, `/sync/bootstrap`; `sync_conflicts`; reuses services with the idempotency key = `client_transaction_id`.
- **Tasks:** T-1101-1 Endpoint · T-1101-2 Flag/conflict policies · T-1101-3 Bootstrap/delta · T-1101-4 Tests.
- **Tests:** TC-1101-01 order · TC-1101-02 duplicate · TC-1101-03 payment conflict stored · TC-1101-04 negative-stock flag.
- **Deps:** US-0101, D-03 · **Pri:** Must · **Est:** 1.5 dd (L)
- **DoD:** Standard.

### US-1102 · Local catalog and customer cache

- **Role / Story:** As a cashier, I want products and customers available on the phone without internet, so that I can keep selling.
- **Trace:** FR-64, NFR-03, D-19.
- **AC:**
  1. Given the bootstrap, then products, customers and balances are stored locally and refreshed by delta.
  2. Given 10,000 products, then a local search returns in ≤ 0.5 s on the reference device. This is the D-19 benchmark.
- **FL:** Storage layer (Hive/hive_ce or SQLite per D-19) · **BE:** bootstrap from US-1101
- **Tasks:** T-1102-1 Benchmark and decision · T-1102-2 Storage · T-1102-3 Sync-down.
- **Tests:** TC-1102-01 bootstrap and delta · TC-1102-02 benchmark (feeds TC-1405-01).
- **Deps:** US-1101 · **Pri:** Must · **Est:** 1.5 dd (L)
- **DoD:** Standard.

### US-1103 · Offline sale and payment capture

- **Role / Story:** As a cashier, I want to complete sales and record payments during an outage, so that the shop never stops.
- **Trace:** FR-64, NFR-04, NFR-05, BR-08, CR-02.
- **AC:**
  1. Given no connectivity, then a sale is committed locally, the local stock is updated within 200 ms, and the item is queued with a `client_transaction_id` and `occurred_at`.
  2. Given an offline payment, then it is queued and the local balance is updated.
  3. Given an app restart, then queued items persist and `occurred_at` is preserved through sync.
- **FL:** Queue and local commit · **BE:** —
- **Tasks:** T-1103-1 Local transaction model · T-1103-2 Queue · T-1103-3 UI states.
- **Tests:** TC-1103-01 offline sale persists · TC-1103-02 offline payment · TC-1103-03 `occurred_at` preserved.
- **Deps:** US-1102 · **Pri:** Must · **Est:** 2.0 dd (L)
- **DoD:** Standard.

### US-1104 · FIFO sync engine and indicator

- **Role / Story:** As a cashier, I want queued work sent automatically, in order, and to see its status, so that I trust the system.
- **Trace:** FR-65, FR-67, NFR-06, BR-05, AC-06, AC-07.
- **AC:**
  1. Given 10 queued items, when reconnected, then the server receives them in FIFO order and each takes effect exactly once (AC-07).
  2. Given the connection drops mid-sync, then on resume no item is duplicated and none is lost (AC-06).
  3. The indicator shows synced, synchronizing, or pending (n), plus a "needs review" count.
- **FL:** Engine with backoff · SCR-M-16
- **Tasks:** T-1104-1 Engine · T-1104-2 Indicator · T-1104-3 Tests.
- **Tests:** TC-1104-01 FIFO exactly once · TC-1104-02 interrupted sync · TC-1104-03 indicator states.
- **Deps:** US-1101, US-1103 · **Pri:** Must · **Est:** 1.5 dd (L)
- **DoD:** Standard.

### US-1105 · Queue limit enforcement

- **Role / Story:** As an owner, I want the app to warn and then stop offline financial writes before the queue becomes unmanageable, so that recovery remains possible.
- **Trace:** FR-68, BR-12, D-18.
- **AC:**
  1. At 800 pending items, a persistent warning with "Sync now" is shown.
  2. At 1000 pending items, new offline financial writes are blocked with an explanation; reads still work.
- **FL:** Queue guard · **BE:** —
- **Tasks:** T-1105-1 Guard and UI.
- **Tests:** TC-1105-01 warn at 800 · TC-1105-02 block at 1000.
- **Deps:** US-1104 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-1106 · Conflict review and resolution (web)

- **Role / Story:** As a manager, I want to review flagged and conflicting offline items and resolve them, so that no money is lost or double counted.
- **Trace:** BR-10, UC-22, D-03.
- **AC:** Given a conflict, then the manager can:
  - apply it to another debt of the same customer;
  - record it as a refund;
  - void it with a reason.

  Each resolution is audited. Flagged sales can be acknowledged.
- **RE:** SCR-W-18 · **BE:** resolution endpoints
- **Tasks:** T-1106-1 Endpoints · T-1106-2 Screen.
- **Tests:** TC-1106-01 each resolution path, with audit.
- **Deps:** US-1101 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

### US-1107 · Optional location capture

- **Role / Story:** As an owner, I want the option to record the approximate location of offline transactions for traceability.
- **Trace:** FR-69, BR-08.
- **AC:** Given the feature is disabled (the default), or permission is denied, then no location is collected. When enabled and permitted, the approximate location is attached to queued items.
- **FL:** Permission and setting · **BE:** optional fields
- **Tasks:** T-1107-1 Setting and capture.
- **Tests:** TC-1107-01 captured only when enabled and permitted.
- **Deps:** US-1103 · **Pri:** Could · **Est:** 0.5 dd (S)
- **DoD:** Standard plus a privacy note in the release notes.

---

# E12 — Web Application Shell

### US-1201 · React app shell and API client (S3)

- **Role / Story:** As a web user, I want a consistent, RTL, role-aware application frame, so that every screen behaves predictably.
- **Trace:** FR-05, FR-06, NFR-14, D-21, **DEF-17**.
- **AC:**
  1. CI runs `oxlint` with `no-undef` and `vite build`, and both pass.
  2. A 401 from any call logs the user out and redirects to login.
  3. Navigation hides owner-only items from managers and employees.
  4. `<html lang="ar" dir="rtl">`; the layout works at 768–1280 px.
  5. Financial POSTs automatically carry an `Idempotency-Key`, which is reused on retry.
- **RE:** `apiClient`, TanStack Query provider, auth context, layout, route guards, base components · **BE / FL / AI:** — · **UX:** US-1501, US-1503
- **Tasks:** T-1201-1 `apiClient` · T-1201-2 Layout and navigation · T-1201-3 Guards · T-1201-4 CI job · T-1201-5 Fix the lint warnings.
- **Tests:** TC-1201-01 lint (with `no-undef`, **zero warnings**) and build green · TC-1201-02 401 handling · TC-1201-03 role-aware navigation · TC-1201-04 RTL and responsive checklist.
- **Regression for:** DEF-12 → TC-1201-01; DEF-17 → TC-1201-01.
- **Deps:** US-0106 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

---

# E13 — Mobile Application Shell

### US-1302 · Flutter environment and device readiness — spike SP-01 (S1) — *added in v0.2*

- **Role / Story:** As the developer, I want the Flutter toolchain and both test phones proven before any mobile estimate is trusted, so that setup problems surface in week 1, not week 5.
- **Value:** Turns environment setup from an uncounted "lead time" into measured, planned work (risk R-02).
- **Trace:** NFR-13, A-05, D-20.
- **Pre:** The TL has provided the reference (mid-range, Android ≥ 10) and low-end (Android 8–9, 2–3 GB RAM) phones, or confirmed their models. Large downloads run in the background during S1.
- **AC:**
  1. `flutter doctor -v` shows the Android toolchain green (SDK, licences, the bundled JDK). The Flutter version is pinned and recorded.
  2. A debug build **and** a release APK run on both phones (and on the emulator if virtualization is available). The first-build and incremental-build times are recorded.
  3. A phone on the same Wi-Fi reaches the local Laravel API (`php artisan serve --host=0.0.0.0`, Windows firewall rule, debug-only cleartext network configuration or HTTPS tunnel). A test request returns 200.
- **FL:** Toolchain only (no app code) · **BE / RE / UX / AI:** —
- **Tasks:** T-1302-1 Install the SDK, Android Studio and licences · T-1302-2 Device USB debugging and drivers · T-1302-3 LAN and cleartext connectivity · T-1302-4 Record versions, timings and device models in `docs/mobile/environment.md`.
- **Tests:** TC-1302-01 doctor report · TC-1302-02 release APK installs and runs on both phones · TC-1302-03 phone → local API returns 200.
- **Deps:** — · **Pri:** Must · **Est:** **0.75 dd** (v0.4; was 0.5 — first-time Windows setup with two phones)
- **DoD:** The environment note is committed; any blocker is reported to the TL the same day.

### US-1301 · Flutter walking skeleton and readiness spikes SP-02 – SP-04 (S2)

> **v0.4 split (approved):** the S1 parts became US-1303, US-1304, US-1305 and US-1306. **Remainder in S2:** T-1301-7 scan → `/products/lookup` integration, **0.25 dd**, after US-0401. SP-04 is measured on US-1303, US-1304 and US-0205 instead of a search screen. **Gate G-FL moves to the end of S1.** TC-1301-04 is retired and replaced by TC-1305-01 (the old ID is not reused). The text below is kept for history.

- **Role / Story:** As the developer, I want a minimal Flutter app that logs in, calls the API and scans a barcode on a real device, **and** measurements of my own Flutter pace, so that the S5 estimate rests on evidence.
- **Trace:** NFR-13, NFR-02, FR-03, FR-17, FR-18 (spike), D-20, D-31.
- **Pre:** US-1302 done; the barcode samples are prepared (20 real EAN-13/UPC products, 5 printed Code128 labels, plus glossy, curved, damaged and low-light cases).
- **AC:**
  1. `flutter analyze` reports no issues; the folder template matches [04 §5.2](04-system-architecture.md#52-flutter-mobile-proposed-d-20).
  2. **SP-03:** the app logs in against the local API (configurable base URL) and stores the token securely. An `Idempotency-Key` created before an app kill is still present after restart.
  3. **SP-02:**
     - At most two maintained scanning plugins are compared (maintenance activity, licence, minSdk).
     - For the chosen plugin, scan-to-result p50 and p90 are recorded over 20 codes × 2 phones, against the 1.5 s target.
     - The behaviour of continuous detection of the same code is documented as input to **D-31**.
     - Scanning a real product shows the product name returned by `/products/lookup`.
  4. **SP-04:**
     - A product-search screen is built with Riverpod and go_router against an estimate written **before** starting.
     - The pace factor **k = actual ÷ estimate** is recorded.
  5. Package versions are pinned and recorded, with a maintenance check note per package.
- **Gate G-FL (end of S2):**
  - If SP-02 or SP-03 fails, or k > 1.3, then S5 is re-estimated as 6.5 × k and the TL decides: re-plan, add a Flutter contributor, or reduce the mobile scope.
  - This gate is recorded in the S2 status note.
- **FL:** Project, `ApiClient` with an idempotency helper, login screen, scan spike, search screen · **BE / RE / AI:** — · **UX:** —
- **Tasks:** T-1301-1 Create the project and template · T-1301-2 Packages and maintenance notes · T-1301-3 Login and key persistence (SP-03) · T-1301-4 Barcode plugin comparison and timing (SP-02) · T-1301-5 CI job (analyze and test) · T-1301-6 Pace calibration screen (SP-04).
- **Tests:** TC-1301-01 analyze clean · TC-1301-02 login against the API, key persists across a kill · TC-1301-03 real scan shows the product · TC-1301-04 barcode spike report (p50/p90 per phone, repeat-detection behaviour) · TC-1301-05 pace factor k recorded and G-FL decision logged.
- **Deps:** US-1302, US-0401 (lookup endpoint) · **Pri:** Must · **Est:** 1.5 dd (L)
- **DoD:** Standard plus a short "how to run" README in the Flutter project and the spike report in `docs/mobile/spikes.md`.

### US-1303 · Flutter project foundation (S1, 1.0 dd) — *v0.4*

- **Role / Story:** As the developer, I want a clean Flutter project with Arabic RTL, navigation, state and theme foundations, so that every later screen is built on one consistent structure.
- **Trace:** NFR-12, NFR-13, D-20, D-36, D-37.
- **AC:**
  1. The app boots in Arabic RTL on both phones.
  2. The navigation skeleton matches the DR-1 map (bottom navigation, role landing).
  3. `flutter analyze` reports no issues. The theme uses a **neutral** palette until DR-2.
- **FL:** `mobile/` project; feature-first folders; `flutter_lints`; env files; `go_router` shell; Riverpod root scope; theme wired to US-1501 tokens; shared loading, empty and error widgets; `mobile/README.md`.
- **Tests:** TC-1303-01 widget smoke · TC-1303-02 RTL directionality · TC-1303-03 analyze clean.
- **Deps:** US-1302, US-1505 (DR-1), D-20, D-36, D-37 · **Pri:** Must · **Est:** 1.0 dd

### US-1304 · Mobile API client foundation (S1, 0.5 dd) — *v0.4*

- **Role / Story:** As the developer, I want one API client that turns every v1 error into a typed failure and keeps idempotency keys across restarts, so that screens handle real responses consistently.
- **Trace:** FR-66 (client part), NFR-08, D-04, D-22.
- **AC:**
  1. Every error code in the frozen v1 contract maps to a typed failure (401, 403 `USER_INACTIVE`, 422 field errors, 428 / 409 idempotency, 429 + `Retry-After`, 5xx with `correlation_id`, network error).
  2. An `Idempotency-Key` created before an app kill is reused after restart (SP-03).
- **Tests:** TC-1304-01 error mapping (fake adapter) · TC-1304-02 key persistence across restart.
- **Deps:** US-0106 contract freeze, US-1303 · **Pri:** Must · **Est:** 0.5 dd

### US-1305 · Barcode camera spike, SP-02 (S1, 0.5 dd) — *v0.4*

- **Role / Story:** As the TL, I want measured barcode-scanning evidence on our real phones before the POS is built, so that the plugin and the repeat-scan rule are chosen on facts.
- **Trace:** FR-17, FR-18, NFR-02, D-31.
- **AC:** At most two maintained camera plugins are compared (maintenance, licence, minSdk); p50/p90 scan-to-result on 20 real codes × 2 phones (glossy, curved, damaged, low-light); continuous-detection behaviour of the same code documented; report in `docs/mobile/spikes.md` with a recommendation. No backend call.
- **Tests:** TC-1305-01 spike report (replaces TC-1301-04).
- **Deps:** US-1302 · **Pri:** Must · **Est:** 0.5 dd

### US-1306 · Mobile ↔ Laravel auth integration and Flutter CI (S1, 0.5 dd) — *v0.4*

- **Role / Story:** As the developer, I want the real app tested against the real API on a real phone, and Flutter checks in CI, so that mobile auth is proven end to end.
- **Trace:** FR-03, NFR-08, NFR-13.
- **AC:** All six scenarios below pass on the reference phone against local `/api/v1`; `flutter analyze` + `flutter test` run in CI.
- **Tests:** TC-1306-01 login OK · TC-1306-02 wrong password · TC-1306-03 throttled 429 · TC-1306-04 deactivated 403 · TC-1306-05 logout then the next call is 401 · TC-1306-06 session restore after app restart.
- **Deps:** US-0205, US-0104, US-0105, US-0108 · **Pri:** Must · **Est:** 0.5 dd

---

# E14 — Release and Operations

### US-1401 · Environments and deployment (S6)

- **Role / Story:** As the TL, I want staging and production deployed repeatably and securely, so that releases are low-risk.
- **Trace:** NFR-08, NFR-16, D-25, **DEF-15**.
- **AC:**
  1. Production runs with `APP_ENV=production`, `APP_DEBUG=false`, HTTPS only, a CORS allow-list, a queue worker and the scheduler.
  2. Staging mirrors production on a separate database.
  3. Deployment follows [12](12-release-and-deployment-plan.md), including a backup before migrate.
  4. The smoke test passes after deployment.
- **Tasks:** T-1401-1 Provision · T-1401-2 Environment checklist · T-1401-3 Deploy script · T-1401-4 Smoke test.
- **Tests:** TC-1401-01 configuration checklist verified · TC-1401-02 smoke test after deploy.
- **Deps:** D-25 · **Pri:** Must · **Est:** 0.75 dd (M)
- **DoD:** Standard.

### US-1402 · Backup and restore drill (S6)

- **Role / Story:** As the TL, I want to prove we can restore the database, so that data loss is recoverable.
- **Trace:** NFR-16.
- **AC:** Given a daily automated backup, when it is restored to staging, then the row counts and a financial checksum (Σ invoices, Σ payments) match. The drill steps and timing are documented.
- **Tasks:** T-1402-1 Backup schedule · T-1402-2 Restore drill and runbook.
- **Tests:** TC-1402-01 restore drill evidence.
- **Deps:** US-1401 · **Pri:** Must · **Est:** 0.25 dd (S)
- **DoD:** Standard.

### US-1403 · UAT and release (S6, repeated per release)

- **Role / Story:** As the TL, I want an acceptance run against the release's criteria with a real or simulated shop day, so that the release is fit for use.
- **Trace:** AC-01–AC-04, AC-10 (R1); NFR-12, NFR-14.
- **AC:**
  1. Every in-scope AC has passing evidence.
  2. Task-based usability: a walk-in cash sale takes ≤ 4 taps after scanning; the web return flow completes without help.
  3. Release notes and known limitations are published.
- **Tasks:** T-1403-1 UAT script · T-1403-2 Run and record · T-1403-3 Release notes.
- **Tests:** TC-1403-01 UAT script results · TC-1403-02 usability task results.
- **Deps:** All release stories · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard plus TL sign-off.

### US-1404 · Performance checks (S6)

- **Role / Story:** As the TL, I want measured evidence for the API and barcode performance targets, so that NFRs are verified rather than assumed.
- **Trace:** NFR-01, NFR-02, AC-01.
- **AC:**
  1. p95 < 3 s for the main endpoints on staging, with a seeded store (5,000 products, 1,000 customers, 20,000 sales).
  2. 20 scans on the reference device average ≤ 1.5 s from scan to cart.
- **Tasks:** T-1404-1 Seeder (staging only) · T-1404-2 Load script · T-1404-3 Device timing.
- **Tests:** TC-1404-01 API p95 · TC-1404-02 barcode timing.
- **Deps:** US-1401, US-0505 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Standard.

### US-1405 · Offline performance tests (R2, S10)

- **Role / Story:** As the TL, I want the offline NFRs measured on the reference device.
- **Trace:** NFR-03, NFR-05, NFR-06.
- **AC:**
  1. A local search over 10,000 items takes ≤ 0.5 s.
  2. A local sale commit takes ≤ 200 ms.
  3. Queues of 100 and 1000 items sync in ≤ 60 s at ≥ 1 Mbps.
- **Tests:** TC-1405-01 search · TC-1405-02 local commit · TC-1405-03 sync time.
- **Deps:** US-1104 · **Pri:** Must · **Est:** 1.0 dd (M)
- **DoD:** Standard.

---

# E15 — UX and Design System

### US-1501 · Design tokens and core components (S1)

> **v0.4:** re-scoped mobile-first (RTL/bidi sample sheet, colour roles for payment states, component state sheet); estimate 0.5 → **0.75 dd**. Approved at DR-2. See [14 §5.6](14-sprint-1-execution-plan.md).

- **Role / Story:** As the developer, I want one token set and component spec for web and mobile, so that the UI is consistent and accessible.
- **Trace:** NFR-12, NFR-14, SRS §9.4.
- **AC:**
  1. Tokens and components from [06 §5](06-ui-ux-and-screen-plan.md#5-component-and-design-system-specification) are finalised.
  2. All colour pairs pass AA contrast.
  3. Each component specifies its states.
- **Tasks:** T-1501-1 Finalise tokens · T-1501-2 Contrast check · T-1501-3 Component state spec.
- **Tests:** TC-1501-01 contrast report · TC-1501-02 TL review.
- **Deps:** — · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Reviewed by the TL.

### US-1502 · POS and checkout wireframes (S1 — moved from S2 in v0.4)

> **v0.4:** moved to S1 and narrowed to SCR-M-02 – M-06 plus the F-1 prototype test (M-07 – M-11 move to US-1508). Split: low-fi 0.25 (P1) + prototype and hallway test 0.25 (P4). The test may slip to S2 if participants are unavailable; the low-fi may not.

- **Role / Story:** As the TL, I want the most-used mobile flows designed before coding, so that the POS is fast.
- **Trace:** FR-17, FR-18, FR-23–26, UC-08, UC-10, UC-11, NFR-12.
- **AC:** SCR-M-02 to SCR-M-06 and SCR-M-07 to SCR-M-11 have wireframes (Figma or annotated sketches) reviewed against UI-AC-01 to UI-AC-05, and a clickable prototype of flow 4.1 is tested with 2–3 people.
- **Tasks:** T-1502-1 Wireframes · T-1502-2 Prototype test.
- **Tests:** TC-1502-01 review checklist and test notes.
- **Deps:** US-1501 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Reviewed by the TL.

### US-1503 · Web admin wireframes (S3)

- **Role / Story:** As the TL, I want the back-office screens designed before S4, so that web production is fast and consistent.
- **Trace:** SRS §9.3.
- **AC:** SCR-W-05 to SCR-W-15 have wireframes reviewed against UI-AC-04 to UI-AC-08 and UI-AC-11 to UI-AC-12.
- **Tasks:** T-1503-1 Wireframes · T-1503-2 Review.
- **Tests:** TC-1503-01 review checklist.
- **Deps:** US-1501 · **Pri:** Must · **Est:** 0.5 dd (S)
- **DoD:** Reviewed by the TL.

### US-1504 · AI chat and preview wireframes (S7)

- **Role / Story:** As the TL, I want the AI preview and confirmation design to make the consequences obvious, so that users never confirm by accident.
- **Trace:** FR-56, FR-57, BR-02.
- **AC:** SCR-M-12/13 and SCR-W-16 are wireframed, reviewed against UI-AC-09, and include the error, unavailable, ambiguous and expired states.
- **Tasks:** T-1504-1 Wireframes.
- **Tests:** TC-1504-01 review checklist.
- **Deps:** US-1501 · **Pri:** Must · **Est:** 0.25 dd (S)
- **DoD:** Reviewed by the TL.

### US-1505 · Mobile IA, navigation and R1 screen inventory (S1, 0.25 dd) — *v0.4*

- **Role / Story:** As the TL, I want the mobile navigation, role landing and screen list agreed before any screen is built, so that the app structure is decided once.
- **AC:** Navigation map, role landing rule (employee → POS; owner / manager → Home), ranked R1 inventory, and a state matrix per S1 screen listing every real API response of the v1 contract; approved at DR-1.
- **Tests:** TC-1505-01 DR-1 sign-off.
- **Deps:** US-0106 (contract list) · **Pri:** Must · **Est:** 0.25 dd

### US-1506 · Mobile visual direction (S1, 0.5 dd) — *v0.4*

- **Role / Story:** As the TL, I want two distinct, reasoned visual directions on the same screens, so that I choose the look of the product deliberately.
- **AC:** Two directions applied to login and the POS cart, each with a written rationale against the design principles ([14 §5.2](14-sprint-1-execution-plan.md)); the TL selects one at DR-2 (or asks for a revision). **Protected scope.**
- **Tests:** TC-1506-01 DR-2 decision recorded.
- **Deps:** US-1501 draft · **Pri:** Must · **Est:** 0.5 dd

### US-1507 · Auth and app-shell screen designs (S1, 0.25 dd) — *v0.4*

- **Role / Story:** As the developer, I want every sign-in and shell state designed before I style it in Flutter, so that the implementation does not invent UI.
- **AC:** Low-fi, then hi-fi in the chosen direction: login, field validation, invalid credentials, throttled with countdown, inactive account, session expired, network error, shell with bottom navigation, offline banner. Every US-0205 state has a design; approved at DR-2.
- **Tests:** TC-1507-01 DR-2 sign-off.
- **Deps:** US-1505, US-1506 · **Pri:** Must · **Est:** 0.25 dd (low-fi 0.125 + hi-fi 0.125)

### US-1508 · Mobile hi-fi designs for R1 screens (S4, 0.75 dd) — *v0.4*

- **Role / Story:** As the TL, I want hi-fi designs of the POS, checkout, customer, payment, home and product screens in the approved direction before S5, so that mobile implementation does not invent UI.
- **Trace:** NFR-12, §9.4; SCR-M-02 – M-11.
- **AC:**
  1. Every SCR-M-02 – M-11 screen has a hi-fi design with its state matrix, using only design-system components.
  2. The designs incorporate the DR-3 prototype findings.
  3. They are approved at a design review before S5 starts.
- **Tests:** TC-1508-01 design-review sign-off.
- **Deps:** US-1501, US-1506 (DR-2), US-1502 · **Pri:** Must · **Est:** 0.75 dd

---

## Estimate Reconciliation

| Sprint | Stories (dd) | Non-story items | Total dd |
|---|---|---|---|
| S1 | 0101 **1.5** · 0102 0.75 · 0103 0.75 · 0104 0.25 · 0105 0.75 · 0106 0.5 (+ T-0106-5 0.25) · 0107 0.25 · 0108 0.5 · **0109 0.25** · 1501 0.75 · **1302 0.75** · 1303 1.0 · 1304 0.5 · 0205 0.75 · 1305 0.5 · 1306 0.5 · 1505 0.25 · 1502 0.5 · 1506 0.5 · 1507 0.25 | design revisions 0.25 · wrap / G-FL 0.5 | **12.75** (v0.4; was 6.5) |
| S2 | 0401 0.75 · 0402 0.75 · 0403 0.25 · 0305 0.25 · 0701 0.5 · 0501 1.0 · 0502 0.75 · 0503 0.75 · 1502 0.5 · 1301 **1.5** | — | **7.0** |
| S3 | 0601 1.25 · 0702 0.5 · 0703 **1.0** · 0302 0.75 · 0801 0.75 · 1503 0.5 · 1201 0.75 · 0202 0.25 · 0201 0.25 · 0802 0.5 | — | **6.5** |
| S4 | 0204 0.5 · 0301 **1.0** · 0303 0.5 · 0405 0.75 · 0504 0.5 · 0602 0.5 · 0704 1.0 | integration 0.5 | **5.25** |
| S5 | 0205 0.5 · 0505 1.5 · 0506 1.25 · 0304 0.5 · 0705 1.0 · 0406 0.5 · 0803 0.5 | hardening 0.75 | 6.5 |
| S6 | 0203 1.0 · 1401 0.75 · 1402 0.25 · 1404 0.5 · 1403 1.0 | buffer 0.5 | 4.0 |
| **R1** | | | **35.75** |
| S7 | 1504 0.25 · 1001 0.75 · 1002 1.0 · 1003 0.75 · 1004 1.0 · 1005 0.5 · 1006 0.5 | — | 4.75 |
| S8 | 0901 0.75 · 0902 0.5 · 0903 0.25 · 1007 0.75 · 0603 0.75 | release 0.5 | 3.5 |
| **R1.1 (cumulative)** | | | **44.0** |
| S9 | 1101 1.5 · 1102 1.5 · 1103 2.0 | regression 0.5 | 5.5 |
| S10 | 1104 1.5 · 1105 0.5 · 1106 1.0 · 0407 0.5 · 1405 1.0 · 1107 0.5 | release 0.5 | 5.5 |
| **R2 (cumulative)** | | | **55.0** |
| Not in the baseline | 1008 (0.5, Could) · D-32 frontend test tooling (+0.5, conditional) · CR-13 weighted goods (+1.0–1.5, conditional) | | — |

**v0.2 changes (+2.0 dd in R1), shown in bold above:**

| Story | Change | dd |
|---|---|---|
| US-0101 | Replay test across every financial endpoint | +0.25 |
| US-0109 | New: SRS verification | +0.25 |
| US-1302 | New: Flutter environment spike | +0.5 |
| US-1301 | Spikes SP-02 – SP-04 | +0.5 |
| US-0703 | Invariant test | +0.25 |
| US-0301 | Customer deactivation | +0.25 |
