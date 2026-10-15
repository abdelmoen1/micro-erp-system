# 03 — Decision Log and Change Requests

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL**
> Every recommendation below is a proposal. Nothing here changes the approved SRS v1.1. Requirement changes are listed separately as **Change Requests (CR)** for the Team Leader (TL) to accept or reject.
>
> **v0.2 (2026-10-13):**
> - D-31 to D-35 added.
> - Blocking sprints corrected: D-01 and D-02 no longer block S1; D-28 now blocks S1.
> - Every decision is classified A, B or C.
> - **No decision is approved by default.**
>
> The classified approval list is in [13 §6](13-final-review-and-decision-pack.md).
>
> **v0.4 (2026-10-13) — TL approval of Sprint 1:** the TL approved D-04, D-09, D-12, D-13, D-20, D-22, D-23 / CR-14 (value `Asia/Gaza`), D-24, D-36, D-37 (`com.hisbah.smartshop`) and D-38. They are recorded in Part 3 with their exact wording. All other decisions remain open.

**Legend**

| Field | Values |
|---|---|
| **Approval** | **Required** = must be decided before the dependent sprint starts. **Advisory** = lower-impact; a recommendation is given, but it **still needs an explicit TL decision**. Nothing applies by default (v0.2). |
| **Category (v0.2)** | **A** = safe to approve now (technical, low risk, reversible) · **B** = business decision for the TL · **C** = technical, needs evidence (spike, test, benchmark) before deciding |
| **Blocks** | The earliest sprint that cannot start or finish safely without the decision (sprint IDs from [07](07-milestones-and-sprints.md)). |
| **Cost** | Incremental developer-days (dd) relative to the plan in [07](07-milestones-and-sprints.md). |

---

## Part 1 — Decision Log

### D-01 · Release strategy

- **Question:** Deliver the full SRS v1.1 in one release (Scenario B), or in stages with a smaller first release (Scenario A)?
- **Why it matters:** A solo developer cannot deliver the full scope in 20 days ([11](11-risk-register-and-feasibility.md)). A big-bang release delays all feedback and concentrates integration risk at the end.
- **Options:**
  1. Scenario B: one release, about 64 dd including contingency.
  2. **Scenario A, staged:** R1 *Core Shop* (web + mobile online), then R1.1 *AI & Sharing*, then R2 *Offline*.
  3. Scenario A with AI moved into R1 ahead of mobile.
- **Recommendation: Option 2.**
  - R1 is the smallest release that runs the whole shop cycle (catalog → sale → stock → debt → payment → return → dashboard) safely.
  - The first usable release lands at about 34 dd base instead of about 56 dd.
  - AI and offline work then build on a stable, idempotent API.
- **Risks:**
  - The AI differentiator (SRS §1.6) appears about 1.5 weeks after R1.
  - Offline arrives last, although the SRS lists it as Must Have. This requires **CR-01**.
- **Cost:** None. This is a sequencing choice.
- **SRS:** §1.8, §6.1 MoSCoW, §10.
- **Approval:** **Required** · **Category:** B · **Blocks:** S5–S6 release planning. **Not S1** (v0.2): S1 content is identical in every scenario.
- **v0.2 note:**
  - R1 is **not** the SRS-defined MVP. Chapter 10 (MVP Acceptance Boundary) includes Offline, Sync, AI Read, AI Action, Voice and Secure Link.
  - Calling R1 an "MVP" requires CR-01 **and** an SRS amendment under the SRS Change Rule.
  - Without that, R1 is the *first launchable increment*, and the SRS MVP is reached when R2 completes.

### D-02 · Offline scope and timing

- **Question:** Which operations must work offline, and in which release?
- **Why it matters:** Offline financial writes are the hardest and riskiest part of the SRS (FR-64–68, BR-05/10/12). They need a local catalog, a local commit, a FIFO queue, conflict handling and device testing.
- **Options:**
  1. Full offline in R1 (sales, returns, payments, opening debts).
  2. **R1 online-only, but every financial write carries an idempotency key from day 1. R2 adds offline sales and payments. Returns and opening debts stay online-only.**
  3. Offline cash sales only, in R1.
- **Recommendation: Option 2.**
  - Server idempotency (US-0101) is needed anyway for retries.
  - Offline returns need both the original invoice and its returnable quantities on the device, which doubles the conflict surface for a rare operation.
  - Option 3 still needs the whole sync engine. Most of the cost is the engine, not the number of operation types.
- **Risks:** R1 cannot sell during an internet outage. Mitigations:
  - A clear offline banner and blocked actions.
  - Retry-safe writes, so a resubmit never duplicates.
- **Cost:** −10 to −12 dd from R1, moved to R2.
- **SRS:** FR-64–68, NFR-04/05/06, BR-05/10/12, AC-06/07, UC-22 → **CR-01, CR-02**.
- **Approval:** **Required** · **Category:** B · **Blocks:** decide **before the end of S4**, together with **D-35**. The API is designed offline-ready from S1 in every case: idempotency keys, `client_transaction_id`, `occurred_at`.
- **v0.2 note:**
  - **Technically justified.**
  - **Against the SRS:** it requires CR-01, because Offline is Must Have and part of the chapter 10 boundary.
  - **Commercially:** it is acceptable only if the pilot shops have reliable connectivity (D-35). SRS §1.2 requires that outages must not stop selling.
  - **If pilot shops face frequent outages:** move offline sales and payments into R1 (+≈ 9.5 dd).

### D-03 · Offline synchronization semantics (designed now, built in R2)

- **Question:** How do offline transactions reconcile with server state?
- **Why it matters:** FIFO preserves order but **does not** resolve conflicts. Examples: stock sold out on another device; a debt already paid elsewhere; a credit limit exceeded.
- **Options:**
  1. Reject conflicting items.
  2. **Server-authoritative "accept-and-flag" for sales; "hold-for-review" for payments.**
  3. Last-write-wins.
- **Recommendation: Option 2.**
  - **Sales:** An offline sale *physically happened*, so it is always recorded. If stock goes negative or a credit limit is exceeded, the sale is recorded with a `review_flag`. It appears in a manager review list.
  - **Payments:** If an offline payment exceeds the current remaining debt, it is stored in `sync_conflicts`. It is **not applied and not discarded** (BR-10). A manager resolves it in one of three ways:
    - apply it to another debt of the same customer;
    - record it as a refund;
    - void it with a reason.
  - **Ordering and deduplication:** Each device keeps strict FIFO. A duplicate `client_transaction_id` returns the original result (FR-66).
  - **Transport:** A batch endpoint returns a per-item status: `applied | duplicate | flagged | conflict | rejected_validation`.
  - Option 1 loses real-world events. Option 3 is unsafe for money.
- **Risks:** A manager workload exists for flagged items, and the reviewer screen must be built.
- **Cost:** Included in R2 (US-1101, US-1106).
- **SRS:** FR-65, FR-66, BR-10, UC-22.
- **Approval:** **Required before R2.**

### D-04 · Duplicate-request prevention (idempotency)

- **Question:** What prevents duplicate financial writes across web, mobile, retries and sync?
- **Why it matters:** Confirmed defect **DEF-02**. UI button-disabling alone is **not** acceptable.
- **Options:**
  1. Client-generated `Idempotency-Key` (UUIDv4) header, recorded in an `idempotency_keys` table in the **same DB transaction** as the business write.
  2. Unique `client_transaction_id` columns on each business table only.
  3. Server-side duplicate detection by hashing payload and time window.
- **Recommendation: Option 1, plus the key stored on the created entity as `client_transaction_id`.** The rules are:
  - **Unique constraint:** `UNIQUE(store_id, idempotency_key)`. Two concurrent requests with the same key cannot both commit.
  - **Replay:** The same key with the same payload hash returns the **original response** (HTTP status + body) and header `Idempotent-Replay: true`.
  - **Mismatch:** The same key with a different payload returns `409 IDEMPOTENCY_KEY_REUSED`.
  - **Missing key:** A request without a key on a financial endpoint returns `428 IDEMPOTENCY_KEY_REQUIRED`.
  - **Retention:** Keys are kept at least 30 days, which covers the offline queue horizon.
  - **Why not option 3:** It produces false positives for genuine repeat sales, for example two identical cash sales a minute apart.
- **Risks:** Clients must persist the key until they receive an acknowledgement. This is specified in [05](05-data-model-and-api-contracts.md).
- **Cost:** 1.25 dd (US-0101).
- **SRS:** FR-66, NFR-10, AC-06, AC-07, UC-19/22 postconditions ("exactly once").
- **Approval:** **Required** · **Blocks:** S1.

### D-05 · Sales-return financial rule

- **Question:** How does a return affect a cash, partially paid, or unpaid invoice?
- **Why it matters:** FR-33 says "according to return rules", but the SRS never defines them. This is a business rule that must not be invented silently.
- **Options:**
  1. **Debt-first:** the return value first reduces the invoice's remaining debt; any excess is refunded in cash.
  2. Proportional: split between debt and refund by the paid ratio.
  3. Store credit only.
- **Recommendation: Option 1.**
  - It matches shop practice: the customer owes less before getting cash back.
  - It is simple to explain and to audit.
- **Rules (proposed):**
  - Returned quantity ≤ sold quantity − previously returned quantity.
  - Return value = quantity × the original unit price. No restocking fee in the MVP.
  - Stock is restored through a `return` stock movement.
  - Debt is reduced by `min(return_value, remaining_debt)` via `debts.return_credit`.
  - Any excess becomes `refund_amount`, paid in cash or another method.
  - Returns are not allowed on voided invoices.
  - Roles: Owner/Manager (UC-12).
  - Cash invoice: the refund is the full return value.
- **Risks:** Proportional refunds may be expected by some shops. The rule can be extended later by adding a policy setting.
- **Cost:** 1.25 dd (US-0601). No additional cost.
- **SRS:** FR-32, FR-33, AC-04, UC-12 → **CR-05**.
- **Approval:** **Required** · **Blocks:** S3.

### D-06 · Invoice immutability and corrections

- **Question:** When does an invoice become immutable, and how are mistakes corrected?
- **Why it matters:** **DEF-05, DEF-06, DEF-11**. BR-07 only covers "finalized and synchronized" invoices, but online invoices have no finalize step.
- **Options:**
  1. **An invoice is final at creation.** Corrections are made only by **void** or **return**.
  2. Allow editing within N minutes of creation.
  3. Keep editing, owner-only, with an audit log.
- **Recommendation: Option 1.**
  - **Void:** Owner/Manager only. Requires a reason. Allowed only if the invoice has no non-reversed payments and no returns. It restores stock with `sale_void` movements, cancels the linked debt, and writes an audit log entry.
  - **Edit:** Only non-financial fields (notes) remain editable.
  - **Removed:** customer reassignment and hard delete.
  - Option 2 creates time-dependent behaviour that is hard to test and conflicts with stock movements. Option 3 still allows rewriting history.
- **Risks:**
  - Existing tests that assert editing and deleting must be rewritten. This is intentional.
  - The existing React and Postman flows never used those endpoints, so the impact is low.
- **Cost:** 0.75 dd (US-0503).
- **SRS:** FR-30, FR-31, BR-07, FR-70 → **CR-03**.
- **Approval:** **Required** · **Blocks:** S2.

### D-07 · Walk-in (anonymous) cash sales

- **Question:** Does every sale require a customer?
- **Why it matters:** The schema currently requires `invoices.customer_id`, but POS cash sales are usually anonymous (UC-10 does not mention a customer).
- **Options:**
  1. **Nullable customer for fully paid sales.** Credit or partial sales require a customer.
  2. An auto-created "Walk-in" customer per store.
  3. Always require a customer.
- **Recommendation: Option 1.**
  - Reporting stays honest: there is no fake customer whose statement grows forever.
  - Validation is simple: `customer_id` is required if `paid_amount < total`.
- **Risks:** One additive migration, which alters the column to nullable.
- **Cost:** 0.1 dd (inside US-0501).
- **SRS:** FR-23, FR-24, UC-10; ERD `Customer 1:* Invoice` → **CR-04**.
- **Approval:** **Required** · **Blocks:** S2.

### D-08 · Recording money received at sale ("collections")

- **Question:** Cash sales currently create no Payment row. What does "collections" (FR-46) mean?
- **Options:**
  1. **Add `invoices.paid_amount` (money received at the till).** Collections = Σ `paid_amount` of non-voided invoices + Σ non-reversed debt payments in the period.
  2. Create a Payment row for every sale. This requires `payments.debt_id` to become nullable, which breaks the current debt-scoped design.
  3. Keep collections = debt payments only.
- **Recommendation: Option 1.**
  - Minimal disruption to the proven payment/debt model.
  - The dashboard shows the breakdown "received at sale" vs "debt repayments".
- **Cost:** Included in US-0501/US-0801.
- **SRS:** FR-24, FR-26, FR-46 → **CR-09**.
- **Approval:** Advisory.

### D-09 · Money representation and arithmetic

- **Question:** How are monetary values validated, computed and serialized?
- **Why it matters:** **DEF-03**.
- **Options:**
  1. **`DECIMAL(12,2)` storage + `decimal:0,2` validation + `bcmath` string arithmetic in a `Money` helper + JSON money as strings (`"12.50"`).**
  2. Integer agorot (cents) columns. This means a migration of all money columns.
  3. Keep floats.
- **Recommendation: Option 1.**
  - `bcmath` is already installed (verified), so no new dependency is needed.
  - The existing column types are kept, with precision widened 10 → 12 in additive migrations only where needed.
  - Strings avoid JSON float drift in both clients.
  - The currency is **NIS (ISO 4217 code `ILS`)**, returned once in API meta.
- **Risks:** Changing JSON money from numbers to strings breaks existing response shapes. Acceptable: there are no production clients (A-02).
- **Cost:** 0.75 dd (US-0102).
- **SRS:** FR-45, BR-03, NFR-11.
- **Approval:** **Required** · **Blocks:** S1.

### D-10 · Debt and payment schema extension

- **Question:** How do we align `debts` and `payments` with the SRS ERD?
- **Recommendation:** Additive migrations only (no edits to existing migrations):
  - **`debts`:**
    - add `customer_id` (backfilled from `invoices.customer_id`), `due_date` (nullable) and `return_credit` (default 0);
    - status is derived from remaining amount; overdue is computed as `remaining > 0 AND due_date < today(store tz)`, never stored.
  - **`payments`:**
    - add `store_id` and `customer_id` (backfilled through the debt), `reversed_by`, and `client_transaction_id`;
    - payments then get direct store isolation instead of isolation only through a join.
- **Why:** Needed by statements, overdue lists, secure links and AI customer-balance tools.
- **Risks:** Backfill correctness. Mitigation: a migration test that asserts a 100% match.
- **Cost:** 0.5 dd (US-0701) + 0.25 dd (inside US-0703).
- **SRS:** FR-35–37, FR-39, FR-70, §8.
- **Approval:** Advisory.

### D-11 · Reversing grouped (pay-all) payments

- **Question:** May a single payment inside a pay-all group be reversed alone?
- **Options:**
  1. **No: grouped payments are reversible only as a group.**
  2. Yes, with the group marked "partially reversed".
- **Recommendation: Option 1.** It keeps one operation equal to one reversal and fixes DEF-10.
- **Cost:** Included in US-0703.
- **SRS:** FR-39 → **CR-10** (part).
- **Approval:** Advisory.

### D-12 · Role and permission matrix

- **Question:** What exactly may each role do?
- **Why it matters:** SRS §3.2 is descriptive. "Unless explicitly authorized" implies per-user grants, which the ERD does not model. FR-08 says "authorized users" invite staff, while the code allows the owner only.
- **Recommendation:** A **fixed matrix, centralized in Laravel Policies, and no per-user grants in the MVP**:
  - **One owner per store;** promotion to owner is impossible (fixes DEF-04).
  - **Invitations and staff management:** Owner only.
  - Full matrix: [05 §6](05-data-model-and-api-contracts.md#6-authorization-matrix).
- **Cost:** 0.75 dd (US-0105).
- **SRS:** §3.2, FR-06, FR-08, FR-09, BR-13 → **CR-10**.
- **Approval:** **Required** · **Blocks:** S1.
- **TL decision (2026-10-13): Approved.** Employees may record actual payments, **including full repayment of a customer's debt (pay-all)**. Debt write-offs require separate authorization and must never be treated as real payments. Reversals stay with owner and manager.

### D-13 · Removing staff

- **Recommendation:** **Deactivate** instead of hard delete. This means setting `status=inactive` and `deactivated_at`, revoking all tokens, and blocking login. Financial attribution (`created_by`, `reversed_by`, audit logs) is preserved. This fixes DEF-09.
- **Alternative:** Soft delete. It is less explicit and affects unique-email reuse.
- **Cost:** Included in US-0105.
- **SRS:** FR-09, FR-70.
- **Approval:** Advisory.
- **TL decision (2026-10-13): Approved** — deactivate, never delete financial actors.

### D-14 · OTP provider and flow

- **Question:** Which SMS/OTP provider, and is the phone also the login identifier?
- **Why it matters:** FR-02/BR-09 make OTP a precondition for store activation. Provider coverage for +970/+972 numbers and the cost per SMS are unverified.
- **Options:**
  - Provider:
    1. International SMS API (e.g., Twilio Verify, Vonage Verify).
    2. Local Palestinian SMS gateway.
    3. Firebase Phone Authentication.
  - Identity: (a) keep email + password login, with OTP at registration only; (b) phone becomes the login identifier.
- **Recommendation: an `OtpSender` interface with a `log` driver (dev/test) and one production driver chosen by the TL after a 0.25 dd coverage/cost check; identity option (a).**
  - **OTP rules:**
    - 6 digits, stored as a hash;
    - 5-minute expiry; 5 attempts;
    - 60 s resend cooldown;
    - throttled per phone and per IP.
  - **Store status:** a store starts as `pending_verification` and becomes `active` on verification.
  - Option (b) changes authentication end to end and is not required by the SRS.
- **Risks:** Provider onboarding or sender-ID approval delays (R-09). The `log` driver keeps development unblocked.
- **Cost:** 1.0 dd (US-0203) + provider setup time.
- **SRS:** FR-02, BR-09, UC-01, UC-02 → **CR-08**.
- **Approval:** **Required** · **Blocks:** S6 (provider); the interface does not block.

### D-15 · AI provider, model and data policy

- **Question:** Which external AI provider, and what shop data may be sent to it?
- **Why it matters:**
  - Arabic (including dialect) understanding and tool-calling reliability decide whether FR-50–59 work at all.
  - Sending customer names and balances to a third party touches NFR-15.
- **Options:** Any provider with reliable function/tool calling and acceptable Arabic quality (e.g., Anthropic, OpenAI, Google). The choice should be made by an **evaluation spike**, not by preference.
- **Recommendation:**
  1. **Provider-agnostic `AiClient` adapter.** The API key lives only on the server.
  2. **0.5 dd evaluation spike** with a fixed test set of 30 Arabic utterances (questions, payments, invoices, ambiguous names, unsupported requests), scoring intent accuracy, entity extraction, refusal behaviour, latency and cost per request.
  3. **Data minimization:**
     - The model receives the user text plus tool results only. It never receives raw tables or other stores' data.
     - Conversation logs are stored for 90 days.
  4. **Hard limit:** the model can only *propose* writes via draft tools (D-29); it never executes them.
- **Risks:** Cost and latency (R-07); dialect misunderstanding (R-08). Mitigated by the preview/confirm design and customer/product disambiguation.
- **Cost:** 0.5 dd spike (inside US-1001) + provider account setup.
- **SRS:** FR-49–63, NFR-15, BR-13, BR-14.
- **Approval:** **Required** · **Blocks:** S7.

### D-16 · Voice-to-text

- **Recommendation:**
  - **Mobile:** on-device platform speech recognition (Arabic locale) through a maintained Flutter plugin, in R1.1 (US-1007).
  - **Web:** browser Speech Recognition only on supporting browsers, deferred to R2 as optional (US-1008).
  - **Alternative:** cloud STT. It has better dialect accuracy but adds cost, latency and data transfer; evaluate if on-device accuracy fails the spike.
- **Cost:** 0.75 dd.
- **SRS:** FR-60 ("approved web clients"), UC-21 → **CR-12**.
- **Approval:** Advisory.

### D-17 · Secure debt-link token

- **Recommendation:**
  - **Token:**
    - UUIDv4 (random, 122 bits), which is SRS-compliant;
    - stored **as a SHA-256 hash**, never as plaintext;
    - the plaintext is shown only once, at generation.
  - **Lifecycle:**
    - expires after 30 days;
    - one active link per customer: regenerating revokes the previous link;
    - manual revoke supported;
    - each access updates `last_accessed_at`.
  - **Public page:**
    - **Shows:** store name, customer display name, chronological statement, totals.
    - **Never shows:** customer phone, internal IDs, or other customers' data.
    - Rate-limited, `noindex`, HTTPS only.
  - Expired or revoked links show a neutral "link no longer valid" page.
- **Why:** UUID alone is only an identifier. Hashing plus expiry plus revocation is the actual access control.
- **Cost:** 0.75 + 0.5 dd (US-0901, US-0902).
- **SRS:** FR-43, BR-06, NFR-09, NFR-15, AC-05, UC-16 → **CR-07**.
- **Approval:** Advisory.

### D-18 · Sync queue limit behaviour (R2)

- **Recommendation:**
  - At **800 pending items (80%)**: show a persistent warning and offer "Sync now".
  - At **1000 pending items**: block new offline financial writes until connectivity is restored. Read-only work continues.
  - Items with `retry_count > 10` are shown in a "stuck items" list.
  - The queue is **never** silently truncated.
- **SRS:** FR-68, BR-12.
- **Approval:** Required before R2.

### D-19 · Mobile local storage technology (R2)

- **Question:** Hive (named in the SRS) or SQLite (e.g., drift) for the offline queue and local catalog?
- **Why it matters:**
  - The queue needs ordered, transactional writes. The local catalog needs fast search over 10,000 items (NFR-03).
  - The maintenance status of the original `hive` package must be verified at decision time. A community fork (`hive_ce`) exists.
- **Options:**
  1. Hive / hive_ce, as the SRS states.
  2. SQLite via drift. This requires a CR because the SRS names Hive.
- **Recommendation:** Decide at the start of R2 after a 0.5 dd benchmark on the target device. The default is **Option 1 (SRS-compliant)** unless the benchmark or the maintenance check fails. **CR-11** is conditional.
- **SRS:** §2.1, §2.3, NFR-03, NFR-13.
- **Approval:** Required before R2.

### D-20 · Flutter architecture

- **Recommendation:**
  - **Structure:** feature-first folders; a single `ApiClient` (HTTP) that injects an `Idempotency-Key` on financial calls.
  - **Packages:**
    - state management: `flutter_riverpod`;
    - routing: `go_router`;
    - token storage: `flutter_secure_storage`;
    - scanning: a maintained camera barcode plugin.
  - Exact packages and versions are pinned in US-1301 after a maintenance check.
- **Why:** Riverpod and go_router are widely documented, which helps AI-assisted work for a developer with limited Flutter experience. A fixed folder template limits divergence.
- **Alternatives:** Provider (simpler, less structured); Bloc (more boilerplate).
- **Approval:** Advisory (dependency adoption is approved in US-1301).

### D-21 · React additions

- **Recommendation:**
  - **Add:** **TanStack Query** for server state and caching. That is the only new runtime dependency.
  - **Keep:** existing CSS with design tokens as CSS variables; a small `fetch`-based API client that adds the auth header, `Idempotency-Key`, error mapping and 401 handling.
  - **Avoid in the MVP:** a UI kit and a chart library. Charts are simple CSS bars.
- **Approval:** **Required** (dependency change) · **Blocks:** S3.

### D-22 · API versioning

- **Recommendation:** Move all endpoints to `/api/v1` now. No external client depends on `/api` (A-02); doing it later would break mobile releases. The public statement lives at `/api/v1/public/statements/{token}`.
- **Cost:** Included in US-0106.
- **Approval:** **Required** · **Blocks:** S1.

### D-23 · Business timezone

- **Recommendation:**
  - Add `stores.timezone`, defaulting to **`Asia/Hebron`**. The TL confirms (`Asia/Gaza` and `Asia/Jerusalem` are alternatives).
  - Store timestamps in UTC. Compute day, week, month and due-date boundaries in the store timezone. This fixes DEF-07.
- **Approval:** **Required** (value) · **Blocks:** S1.
- **TL decision (2026-10-13, with CR-14): Approved** — store-specific timezone configuration; **`Asia/Gaza`** is the default for Gaza pilot stores, and another appropriate timezone may be set per store.

### D-24 · CI and MySQL test parity

- **Recommendation:**
  - **CI:** GitHub Actions on every push or PR:
    - backend: PHPUnit on sqlite **and** MySQL 8;
    - React: lint (with `no-undef`) and build;
    - Flutter: `analyze` and `test`, once Flutter exists.
  - **Locally:** the developer can run the MySQL suite against XAMPP using a **dedicated, disposable** `hisbah_test` database. Running tests against the dev or production DB is never allowed.
- **Why:** DEF-16 shows sqlite and MySQL behave differently on decimals.
- **Cost:** 0.5 dd (US-0108).
- **Approval:** **Required** · **Blocks:** S1.

### D-25 · Hosting and deployment target

- **Options:**
  1. VPS with a server-management tool.
  2. Managed Laravel hosting.
  3. Shared hosting.
- **Requirements (any option):**
  - PHP 8.2+;
  - MySQL 8 with automated daily backups;
  - HTTPS;
  - queue worker and scheduler;
  - SSH or deploy hooks;
  - a staging environment.
- **Recommendation:** The TL selects the target by the end of S4, against the checklist in [12](12-release-and-deployment-plan.md). Shared hosting is discouraged: it usually has no queue worker or SSH.
- **Approval:** **Required** · **Blocks:** S6.

### D-26 · Credit limit semantics

- **Recommendation:**
  - Add `customers.credit_limit` (nullable). Null means "no limit", consistent with "when enabled" in BR-01.
  - A credit or partial sale is rejected if `outstanding + new_debt > credit_limit`.
  - Owner/Manager set the limit.
  - In R2 (offline), the check runs against the cached balance; the server re-checks and flags (D-03).
- **Cost:** 0.25 dd (US-0305).
- **SRS:** BR-01, UC-11.
- **Approval:** Advisory.

### D-27 · Stock policy (online)

- **Recommendation:**
  - An online sale is rejected when `quantity > current_stock` (UC-10). There is no negative stock online.
  - The stock row is locked (`lockForUpdate`) during the sale transaction.
  - Products are integer-quantity in the MVP. Weighted or fractional goods are out of scope (**CR-13**).
- **v0.2 business caveat:**
  - Small-shop stock records are often inaccurate at first.
  - Strict rejection can therefore block a real sale of an item physically on the shelf.
  - **Alternative:** allow the sale with a warning, a `NEGATIVE_STOCK` flag and a manager review list. This costs about +0.25 dd and reuses the R2 flag design.
  - **This is the TL's business choice.**
- **Approval:** Advisory · **Category:** B · **Blocks:** S2.

### D-28 · SRS baseline file

- **Recommendation:** The TL commits SRS v1.1 to `docs/srs/Hisbah_Smart_Shop_SRS_v1.1.pdf` and marks `documemtation/SRS.pdf` as superseded. This is a TL action: this package does not move or edit the SRS.
- **Approval:** Required (TL action) · **Category:** B · **Blocks:** **S1** (v0.2). US-0109 verifies the matrix against the committed file. Until then [01](01-requirements-gap-analysis.md) is PROVISIONAL.
- **Steps:** see [13 §5](13-final-review-and-decision-pack.md).
- **Clarification (v0.4, 2026-10-13):** the missing SRS v1.1 file **blocks only the final SRS verification (US-0109)**. Independent Sprint 1 work proceeds. Traceability is **not** claimed as verified until the approved PDF is committed and checked; [01](01-requirements-gap-analysis.md) stays PROVISIONAL until then.

### D-29 · AI action boundaries (drafts and confirmation)

- **Recommendation:**
  - **Allowed writes:** the AI may create **drafts** only, for exactly two types: `payment` and `invoice`.
  - **Draft lifecycle:**
    - a draft is server-validated at creation **and again at confirmation**, against current DB state;
    - it expires after 10 minutes;
    - it can be confirmed only by the same user who created it;
    - it executes through the same `SaleService` / `PaymentService` as manual flows, with an idempotency key derived from the draft ID.
  - **Prices:** always come from the DB, never from the model.
  - **Ambiguity:** an ambiguous customer or product returns choices to the user; nothing is guessed.
- **SRS:** FR-53–59, FR-61–63, BR-02, BR-13, BR-14.
- **Approval:** Advisory (implements the SRS as written).

### D-30 · Web sale creation in R1

- **Question:** Must the React admin create sales in R1, or only view, void and return them?
- **Recommendation:** **View, void and return only in R1.** Sale creation is mobile-first (SRS §1.1, §9.2); §9.3 lists invoices for web without requiring a web POS. A manual web sale form can follow in R1.1 if requested (+0.75 dd).
- **Approval:** Advisory.

### D-31 · Repeat-scan rule (FR-18) — *v0.2*

- **Question:** A camera scanner keeps detecting the same barcode while it is in view. How do we distinguish an intentional re-scan (+1) from continuous detection of the same code?
- **Options:**
  1. Per-code cooldown (e.g., 1.5 s) before the same code can add +1 again.
  2. Scan-then-tap: each detection must be confirmed or the scanner re-armed.
  3. Single-shot scanner that closes after each read.
- **Recommendation:** decide after spike **SP-02** (US-1301) measures real behaviour on both phones. The default candidate is option 1, with an audible or haptic cue per accepted scan.
- **Why it matters:** a wrong rule silently inflates quantities, which is a financial error (AC-02).
- **Category:** C · **Approval:** Required · **Blocks:** S5 (evidence produced in S2).

### D-32 · Automated UI regression tests for the web — *v0.2*

- **Question:** UI defects (DEF-13, register not wired) currently have only manual checks. Under the rule "a defect is closed only with a permanent in-repo regression test", should we add an automated web test tool?
- **Options:**
  1. Vitest + Testing Library (component level).
  2. Playwright (end-to-end against the local API).
  3. No tool; manual scripts plus a TL-signed exception per UI defect.
- **Recommendation:** a **0.5 dd proof with one option** (Playwright fits flow-level defects better), then decide. This needs dependency approval.
- **Impact of rejection:** DEF-13 and future UI defects can only close by exception.
- **Category:** C · **Approval:** Required · **Blocks:** S3.

### D-33 · Customer deactivation (FR-11) — *v0.2*

- **Recommendation:**
  - Add `customers.status` (active/inactive).
  - An inactive customer is hidden from new sales, but their history, statement and outstanding debt remain, and payments are still accepted.
  - Owner/Manager can deactivate and reactivate; both actions are audited.
- **Why:** FR-11 requires "deactivate/delete", but customers with financial history currently cannot be deleted *or* deactivated.
- **Cost:** +0.25 dd (US-0301).
- **Category:** A · **Approval:** Advisory · **Blocks:** S4.

### D-34 · Developer availability — *v0.2*

- **Question:** How many productive hours per day and days per week will the primary developer work on Hisbah?
- **Why:**
  - All estimates are in developer-days (≈ 6 productive hours).
  - Calendar dates cannot be committed without this.
  - Full-time, 5 days/week: weeks = dd ÷ 5. Half-time: × 2. Six days/week: weeks = dd ÷ 6.
- **Category:** B · **Approval:** Required for calendar planning · **Blocks:** none (it affects dates, not scope).

### D-35 · Pilot-shop connectivity — *v0.2*

- **Question:** Do the first pilot shops have reliable internet during trading hours?
- **Why:** it decides whether R1 (online-only) is launchable for them (D-02, SRS §1.2).
- **Options:**
  1. Reliable → R1 as planned.
  2. Frequent outages → R1 includes offline sales and payments (US-1101–US-1106 + device tests, ≈ +9.5 dd base).
- **Recommendation:** the TL surveys 2–3 candidate shops before the end of S4.
- **Category:** B · **Approval:** Required · **Blocks:** R1 release scope (decide by the end of S4).

---

### D-36 · Flutter project location — *v0.4*

- **Recommendation:** A monorepo folder `mobile/` at the repository root, next to `backend/` and `frontend/`.
- **TL decision (2026-10-13): Approved.**

### D-37 · Android application ID — *v0.4*

- **Why it matters:** the ID cannot change after the first Play Store release.
- **TL decision (2026-10-13): Approved — `com.hisbah.smartshop`.** Check the project configuration before creation and keep it stable.

### D-38 · OTP groundwork in Sprint 1 — *v0.4*

- **TL decision (2026-10-13): No OTP groundwork in S1.** OTP provider integration stays in its planned sprint (US-0203, S6).

---

## Part 2 — Proposed Change Requests

> The approved SRS is **not** edited. Each CR is a proposal for the TL to accept, reject, or modify.

| CR | Existing requirement | Proposed clarification / change | Rationale | Affected IDs | Affected modules / data / UI / API / tests | Schedule & risk impact |
|---|---|---|---|---|---|---|
| **CR-01** | §6.1 lists offline transactions, FIFO sync, idempotency, AI drafts, AI read tools and voice as Must Have for the MVP | **Stage the Must-Haves** into R1 (Core Shop), R1.1 (AI, secure link, WhatsApp, mobile voice, mobile returns), R2 (offline sales/payments, sync, queue limit, conflicts) | 20-day solo infeasibility ([11](11-risk-register-and-feasibility.md)); earliest usable release | FR-43/44, FR-49–68, NFR-03–07, NFR-09, BR-02, BR-05, BR-06, BR-10, BR-12–14, AC-05–09, UC-16, UC-18–22 | Release scope only; no design change | First release at 35.75 dd base instead of 57.5 (v0.2). Offline arrives at 55 dd base. **v0.2:** R1 then is *not* the SRS chapter 10 MVP; naming it MVP requires an SRS amendment under the SRS Change Rule. |
| **CR-02** | FR-64: "sales, returns, and payment/debt operations shall be storable locally while offline" | Offline in R2 covers **sales and payments**. **Returns and opening debts stay online-only.** | Returns need invoice history on the device; rare operation; large conflict surface | FR-64, UC-12, UC-22 | Flutter sync engine; sync API types | −1.5 dd in R2; lower conflict risk. **v0.2: this is a permanent reduction of a Must requirement (not a deferral)** |
| **CR-03** | FR-30 "changes shall obey integrity rules"; BR-07 "finalized and synchronized" | **Invoice is final at creation.** Corrections only via void (Owner/Manager, conditions per D-06) or return. Only notes are editable. | DEF-05/06/11; auditability | FR-30, FR-31, BR-07, FR-70, UC-10/11 | `InvoiceController` update/destroy replaced; `PATCH`/`DELETE` removed; existing tests rewritten | 0.75 dd; removes a P0 |
| **CR-04** | ERD: Customer 1:* Invoice (customer mandatory) | Customer is **optional for fully paid sales**, mandatory when `paid_amount < total` | Walk-in POS reality | FR-23, FR-24, UC-10, §8.2 | `invoices.customer_id` nullable; POS UI "No customer" default | +0.1 dd |
| **CR-05** | FR-33 "according to return rules" (undefined) | Adopt the **debt-first, then refund** rule in D-05 | Rule is undefined; must be explicit before implementation | FR-32, FR-33, AC-04, UC-12 | `sale_returns`, `debts.return_credit`, return UI | None |
| **CR-06** | ERD: `Invoice 0..1 : 1 Debt`; existing debt modeled without an invoice | Keep the existing **synthetic `opening_debt` invoice** model for legacy debts | Already implemented, tested, consistent | FR-34, §8.2 | None (documentation only) | Saves ~1 dd of rework |
| **CR-07** | FR-43/BR-06: "non-sequential UUID token… 30-day expiry" | Specify: **UUIDv4, hashed at rest, single active link per customer, revocable**; define the public fields | A UUID alone is not access control | FR-43, BR-06, NFR-09, NFR-15, AC-05, UC-16 | `customer_debt_links`; public statement endpoint and page | None |
| **CR-08** | FR-02/BR-09 OTP; login by email | OTP **at owner registration only**; login stays email + password; store status `pending_verification` → `active` | Minimal identity change | FR-01–03, BR-09, UC-01/02 | `otp_verifications`, `stores.status`, registration UI | None |
| **CR-09** | FR-46 "collections" undefined for cash sales | Collections = money received at sale + non-reversed debt repayments, shown separately | Cash sales create no payment rows | FR-24, FR-26, FR-46, AC-10 | `invoices.paid_amount`, dashboard | None |
| **CR-10** | §3.2 roles: "unless explicitly authorized"; FR-08 "authorized users invite" | **Fixed role matrix** ([05 §6](05-data-model-and-api-contracts.md#6-authorization-matrix)); single owner; owner-only invitations; grouped payments reverse as a group | No per-user grant model in the ERD | §3.2, FR-06, FR-08, FR-09, FR-39 | Policies; staff UI | None |
| **CR-11** *(conditional)* | §2.1/§2.3: Hive local storage | Use SQLite (drift) instead of Hive **only if** the D-19 benchmark or maintenance check fails | Transactional ordered queue; NFR-03 | §2.1, §2.3, NFR-03, NFR-13 | Flutter storage layer | Decided at R2 start |
| **CR-12** | FR-60: "mobile and approved web clients" | Mobile voice in R1.1; web voice optional in R2 on supporting browsers | Browser STT support is inconsistent | FR-60, UC-21 | Flutter/React chat input | None |
| **CR-13** | Stock quantities unspecified | MVP quantities are **integers** (pieces, cartons). Weighted goods deferred. | Matches existing `invoice_items.quantity` (unsigned int) | FR-15, FR-19, FR-23 | `products`, `stock_movements` | Avoids a ~1 dd unit-of-measure design. **v0.2 business question:** groceries commonly sell by weight (vegetables, cheese). If needed, add +1.0–1.5 dd in S2 (decimal quantities, unit field) |
| **CR-14** | No business timezone in the SRS | Add `stores.timezone` (D-23) | Correct day boundaries | FR-37, FR-42, FR-47 | Dashboard, overdue | None |

---

## Part 3 — Decision Status Tracker

> **v0.2:** category **A** = safe to approve now · **B** = business decision · **C** = needs technical evidence.
> **Blocks S1** marks what must be decided before Sprint 1 starts.
> **All boxes are unchecked:** no decision is approved by default.

| Decision | Category | Approval type | Blocks (first sprint needing it) | Blocks S1? | TL decision | Date |
|---|---|---|---|---|---|---|
| D-01 | B | Required | S5–S6 release planning | No | ☐ | |
| D-02 | B | Required | End of S4 (with D-35) | No | ☐ | |
| D-03 | B | Required | R2 | No | ☐ | |
| D-04 | A | Required | S1 | **Yes** | ☑ Approved | 2026-10-13 |
| D-05 | B | Required | S3 | No | ☐ | |
| D-06 | B | Required | S2 (employee containment in S1 via D-12) | No | ☐ | |
| D-07 | B | Required | S2 | No | ☐ | |
| D-08 | B | Advisory | S2 (column), S3 (reports) | No | ☐ | |
| D-09 | A | Required | S1 | **Yes** | ☑ Approved | 2026-10-13 |
| D-10 | A | Advisory | S2 | No | ☐ | |
| D-11 | A | Advisory | S3 | No | ☐ | |
| D-12 | B | Required | S1 | **Yes** | ☑ Approved (incl. employee pay-all; write-offs separate) | 2026-10-13 |
| D-13 | A | Advisory | S1 | **Yes** | ☑ Approved | 2026-10-13 |
| D-14 | C | Required | S6. **Open the provider account now.** | No | ☐ | |
| D-15 | C | Required | S7 | No | ☐ | |
| D-16 | C | Advisory | S8 | No | ☐ | |
| D-17 | A | Advisory | S8 | No | ☐ | |
| D-18 | B | Required | R2 | No | ☐ | |
| D-19 | C | Required | R2 | No | ☐ | |
| D-20 | C | Advisory | S2 (evidence from SP-01 – SP-04; SP-01 runs in S1) | No | ☑ Approved (provisional; validated at G-FL, end of S1) | 2026-10-13 |
| D-21 | A | Required | S3 | No | ☐ | |
| D-22 | A | Required | S1 | **Yes** | ☑ Approved | 2026-10-13 |
| D-23 | B | Required (value) | S1 | **Yes** | ☑ Approved (`Asia/Gaza` default, per-store) | 2026-10-13 |
| D-24 | A | Required | S1 | **Yes** | ☑ Approved | 2026-10-13 |
| D-25 | B | Required | S6 (choose by end of S4) | No | ☐ | |
| D-26 | B | Advisory | S2 | No | ☐ | |
| D-27 | B | Advisory | S2 | No | ☐ | |
| D-28 | B (TL action) | Required | US-0109 only (v0.4 clarification) | No (blocks only US-0109) | ☐ Open — PDF not yet committed | |
| D-29 | A | Advisory | S7 | No | ☐ | |
| D-30 | B | Advisory | S4 | No | ☐ | |
| D-31 | C | Required | S5 (evidence in S2) | No | ☐ | |
| D-32 | C | Required | S3 | No | ☐ | |
| D-33 | A | Advisory | S4 | No | ☐ | |
| D-34 | B | Required (calendar) | Calendar planning | No | ☐ | |
| D-35 | B | Required | R1 scope, by end of S4 | No | ☐ | |
| D-36 | A | Required | S1 | Yes | ☑ Approved (`mobile/`) | 2026-10-13 |
| D-37 | B | Required | S1 (before project creation) | Yes | ☑ Approved (`com.hisbah.smartshop`) | 2026-10-13 |
| D-38 | B | Required | S1 | Yes | ☑ Approved (no OTP in S1) | 2026-10-13 |

| Change request | Category | Blocks | Blocks S1? | TL decision | Date |
|---|---|---|---|---|---|
| CR-01 | B (+ SRS amendment if R1 is to be called "MVP") | S5–S6 release planning | No | ☐ | |
| CR-02 | B (permanent reduction of FR-64) | R2 | No | ☐ | |
| CR-03 | B | S2 | No | ☐ | |
| CR-04 | B | S2 | No | ☐ | |
| CR-05 | B | S3 | No | ☐ | |
| CR-06 | A | — (documentation) | No | ☐ | |
| CR-07 | A | S8 | No | ☐ | |
| CR-08 | B | S6 | No | ☐ | |
| CR-09 | B | S2/S3 | No | ☐ | |
| CR-10 | B | S1 (with D-12) | **Yes** | ☐ Open — D-12 approved; the SRS wording change itself is not yet decided | |
| CR-11 | C (conditional) | R2 | No | ☐ | |
| CR-12 | B | R1.1/R2 | No | ☐ | |
| CR-13 | B | S2 (product schema) | No | ☐ | |
| CR-14 | A | S1 (with D-23) | **Yes** | ☑ Approved | 2026-10-13 |

**Sprint 1 blockers (v0.2):** D-04, D-09, D-12/CR-10, D-13, D-22, D-23, D-24, CR-14, D-28.

**v0.4 status:** all S1 blockers except D-28 and CR-10 are approved (2026-10-13). D-28 now blocks only US-0109. CR-10 is the SRS wording change behind D-12; it does not block implementation of the approved matrix.
