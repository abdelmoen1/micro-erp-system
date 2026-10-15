# 01 — Requirements Gap Analysis and Traceability Matrix

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL** · **PROVISIONAL MATRIX** (v0.2)
>
> This matrix was built from the SRS v1.1 PDF provided in the planning session. **That PDF is not yet committed to the repository.** The matrix becomes VERIFIED only after:
> 1. the TL commits the approved file and records its SHA-256 (D-28);
> 2. US-0109 confirms that every ID and its wording match.
>
> Do not treat this matrix as final before then.
> Baseline: SRS v1.1 vs. `main @ 71c9d17`, verified 2026-10-12 (see [00](00-project-baseline.md)).
> Release, milestone and sprint assignments follow the recommended Scenario A ([02](02-mvp-scope-and-release-strategy.md), [07](07-milestones-and-sprints.md)). They remain proposals until D-01 and CR-01 are approved.

## 1. Legend

**Code status** (exactly one per requirement):

| Code | Meaning |
|---|---|
| **IV** | Implemented and verified: code evidence plus a passing test on 2026-10-12 |
| **IU** | Implemented but unverified: code exists, but no test asserts the behaviour |
| **P** | Partially implemented |
| **M** | Missing |
| **B** | Blocked: cannot be built or verified until a dependency exists (e.g., no Flutter app) |
| **A** | Ambiguous: requires a decision (D-xx) before implementation |

> A status describes the **backend/API** unless stated. Client gaps (React or Flutter) are listed in the Stories column. No requirement is marked complete because a route or screen merely exists.

**Other columns:**

| Column | Values |
|---|---|
| **Priority** | SRS §6.1 MoSCoW: **Must / Should / Could**. "Unclear" means the SRS is internally inconsistent about the priority. |
| **Sec / Int** | Main security or data-integrity implication: **ISO** isolation, **AUTHZ** authorization, **ATOM** atomic multi-record write, **IDEM** duplicate prevention, **AUD** audit, **PRIV** privacy, **MONEY** monetary precision, **—** none significant |
| **Milestone / Sprint / Release** | From [07](07-milestones-and-sprints.md). M1–M6 = R1, M7–M8 = R1.1, M9–M10 = R2. |
| **Stories** | IDs from [08](08-user-stories-and-technical-tasks.md) |
| **Tests** | Test-case sets from [09](09-testing-and-definition-of-done.md). `TC-0101-*` means all test cases of US-0101. |
| **Acceptance evidence** | What must be shown to accept the requirement |

---

## 2. Functional Requirements (FR-01 – FR-70)

| ID | Requirement | Status | Priority | Depends on | Sec/Int | MS | Sprint | Rel | Stories | Tests | Acceptance evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|
| FR-01 | Owner registration (user + shop) | IV (API); React not wired (DEF-13) | Must | FR-02 | AUTHZ | M3, M6 | S3, S6 | R1 | US-0201, US-0203 | TC-0201-*, TC-0203-* | Web registration creates owner + store after OTP |
| FR-02 | OTP verification before store activation | M | Must | D-14 | AUTHZ, PRIV | M6 | S6 | R1 | US-0203 | TC-0203-* | Store stays `pending_verification` until a valid OTP; throttling proven |
| FR-03 | Authentication, token issue | IV; no throttle, no expiry (DEF-08); React broken (DEF-12) | Must | — | AUTHZ | M1–M3, M5 | S1–S3, S5 | R1 | US-0104, US-0202, US-0205, US-1301 | TC-0104-*, TC-0202-*, TC-0205-* | Login works on web + mobile; 6th failed attempt per minute is throttled; tokens expire |
| FR-04 | Logout | IV | Must | FR-03 | AUTHZ | M3, M5 | S3, S5 | R1 | US-0202, US-0205 | TC-0202-*, TC-0205-* | Token revoked; client clears session |
| FR-05 | Current user, role, shop | IU | Must | FR-03 | AUTHZ | M3 | S3 | R1 | US-0202 | TC-0202-03 | `/me` contract test; UI shows store and role |
| FR-06 | RBAC enforced by backend | P (DEF-04; scattered checks) | Must | D-12 | AUTHZ | M1, M3 | S1, S3 | R1 | US-0105, US-1201 | TC-0105-* | Policy test matrix passes for all 3 roles × protected actions |
| FR-07 | Store isolation | IV for existing modules | Must | — | ISO | M1 (sweep), all | S1+ | R1 | US-0105, US-0108; every new story | TC-0108-02 + per-story ISO cases | Cross-store test per new endpoint returns 404 |
| FR-08 | Staff invitations | IV (owner-only) | Must | D-12, CR-10 | AUTHZ | M4 | S4 | R1 | US-0204 | TC-0204-* | Owner invites from the web UI; invitee joins the correct store |
| FR-09 | Staff management (view, role, remove/deactivate) | P (hard delete, DEF-09) | Must | D-13 | AUTHZ, AUD | M1, M4 | S1, S4 | R1 | US-0105, US-0204 | TC-0105-*, TC-0204-* | Deactivated user cannot log in; history intact |
| FR-10 | Customer creation | IV | Must | — | ISO | M4, M5 | S4, S5 | R1 | US-0301, US-0304 | TC-0301-*, TC-0304-* | Create on web and mobile |
| FR-11 | Customer management | **P** (v0.2: update and guarded soft-delete verified; **no deactivation** for customers with financial history, D-33) | Must | D-33 | ISO, AUD | M4 | S4 | R1 | US-0301 | TC-0301-* | Update; delete guard; deactivate/reactivate (TC-0301-03) |
| FR-12 | Customer financial summary | P (debt-only) | Must | D-10 | ISO, MONEY | M3, M4 | S3, S4 | R1 | US-0302, US-0303 | TC-0302-* | Summary totals reconcile with statement lines |
| FR-13 | Chronological customer statement | M | Must (refinements: Should) | D-10 | ISO, PRIV | M3, M4 | S3, S4 | R1 | US-0302, US-0303 | TC-0302-* | Statement lists invoices, debts, payments, reversals and returns in date order |
| FR-14 | Customer outstanding debts | IU | Must | — | ISO | M3, M4, M5 | S3–S5 | R1 | US-0302, US-0303, US-0705 | TC-0302-*, TC-0705-* | Outstanding list equals Σ remaining |
| FR-15 | Product creation (price, stock, threshold, barcode) | M | Must | CR-13 | ISO | M2, M4 | S2, S4 | R1 | US-0401, US-0405 | TC-0401-* | Barcode unique per store; validation enforced |
| FR-16 | Product management, activate/deactivate | M | Must | FR-15 | ISO | M2, M4 | S2, S4 | R1 | US-0401, US-0405 | TC-0401-* | Product used in sales cannot be hard-deleted (BR-04) |
| FR-17 | Camera barcode scanning (mobile) | M / B (no Flutter) | Must | FR-15, US-1301 | — | M2, M5 | S2 (spike), S5 | R1 | US-0401, US-1301, US-0505 | TC-0505-* | AC-01 on the reference Android device |
| FR-18 | Repeated scan increments quantity | M / B | Must | FR-17 | — | M5 | S5 | R1 | US-0505 | TC-0505-02 | AC-02 widget test + device demo |
| FR-19 | Maintain current stock | M | Must | FR-15 | ATOM | M2, M5 | S2, S5 | R1 | US-0402, US-0406 | TC-0402-* | `current_stock` = Σ movements (invariant test) |
| FR-20 | Controlled stock adjustment | M | Must | FR-19 | AUD, AUTHZ | M2, M4 (web); M10 (mobile) | S2, S4, S10 | R1 (web), R2 (mobile) | US-0402, US-0405, US-0407 | TC-0402-* | Adjustment requires a reason; audited |
| FR-21 | Stock movement history | M | Must (UI: Should) | FR-19 | AUD | M2, M4 | S2, S4 | R1 | US-0402, US-0405 | TC-0402-* | Every quantity change has a movement with source |
| FR-22 | Low-stock detection (default 5) | M | Must | FR-19 | — | M2, M4, M5 | S2, S4, S5 | R1 | US-0403, US-0405, US-0406 | TC-0403-* | `stock ≤ minimum_stock` flagged; default 5 |
| FR-23 | Create invoice with ≥1 items | P (free-text items) | Must | FR-15, D-07 | ISO, ATOM, IDEM | M2, M5 | S2, S5 | R1 | US-0501, US-0506 | TC-0501-* | Items reference store products; prices from DB |
| FR-24 | Cash sale | IV (no stock, no product link) | Must | FR-23 | ATOM, IDEM | M2, M5 | S2, S5 | R1 | US-0501, US-0506 | TC-0501-* | Paid in full; stock deducted; idempotent |
| FR-25 | Credit sale | P (100%-debt only) | Must | FR-26 | ATOM | M2, M5 | S2, S5 | R1 | US-0502, US-0506 | TC-0502-* | AC-03 |
| FR-26 | Partial payment at invoice creation | M | Must | D-08 | ATOM, MONEY | M2, M5 | S2, S5 | R1 | US-0502, US-0506 | TC-0502-* | `paid_amount` + debt = total exactly |
| FR-27 | Automatic debt for unpaid amount | P | Must | FR-26 | ATOM | M2 | S2 | R1 | US-0502 | TC-0502-* | Debt created atomically with invoice |
| FR-28 | Stock updated with sale (one transaction) | M | Must | FR-19 | ATOM | M2 | S2 | R1 | US-0501 | TC-0501-03 | Failure mid-sale leaves no invoice, debt or movement |
| FR-29 | Invoice list and details | IU | Must | — | ISO | M4 | S4 | R1 | US-0504 | TC-0504-* | List/detail screens; isolation |
| FR-30 | Invoice modification obeys integrity | P (DEF-05, DEF-11) | Must | D-06, CR-03 | AUD, AUTHZ | M2 | S2 | R1 | US-0503 | TC-0503-* | Financial fields immutable; correction via void/return |
| FR-31 | No hard delete of historical invoices | P (DEF-01, DEF-06) | Must | D-06 | AUD | M2 | S2 | R1 | US-0503 | TC-0503-* | Void instead of delete; no HTTP 500 |
| FR-32 | Item-level sale return | M | Must | FR-23, D-05 | ATOM, IDEM | M3, M4 (web); M8 (mobile) | S3, S4, S8 | R1 (web), R1.1 (mobile) | US-0601, US-0602, US-0603 | TC-0601-* | Returnable quantity enforced |
| FR-33 | Return restores stock + adjusts balance | M / A (rule undefined) | Must | D-05, CR-05 | ATOM, MONEY | M3 | S3 | R1 | US-0601 | TC-0601-* | AC-04 |
| FR-34 | Record existing (old) debts | IV | Must | — | ISO | M2, M4 | S2, S4 | R1 | US-0701, US-0704 | TC-0701-* | Opening debt with optional due date |
| FR-35 | Debt details | P | Must | D-10 | ISO | M2, M4 | S2, S4 | R1 | US-0701, US-0704 | TC-0701-* | Shows original, paid, returned, remaining, customer, invoice, dates, status |
| FR-36 | Debt due date | M | Must | D-10 | — | M2 | S2 | R1 | US-0701, US-0502 | TC-0701-* | Due date stored and validated |
| FR-37 | Overdue detection | M | Must | FR-36, D-23 | — | M3 | S3 | R1 | US-0702 | TC-0702-* | Computed in store timezone |
| FR-38 | Record full/partial payments | IV | Must | D-04 | ATOM, IDEM, MONEY | M3, M4, M5 | S3–S5 | R1 | US-0703, US-0704, US-0705 | TC-0703-* | Idempotent; 2-dp exact |
| FR-39 | Payment reversal with auditability | IV (single); group untested; DEF-10 | Must | D-11 | AUD, AUTHZ | M3, M4 | S3, S4 | R1 | US-0703, US-0704 | TC-0703-* | `reversed_by` recorded; group-only reversal for grouped payments |
| FR-40 | Payment history (customer, debt, invoice, shop) | P | Must | D-10 | ISO | M3, M4 | S3, S4 | R1 | US-0703, US-0704 | TC-0703-* | Filters by customer and invoice |
| FR-41 | Total outstanding debt | IV | Must | — | — | M3 | S3 | R1 | US-0702, US-0801 | TC-0801-* | Equals Σ debt remaining |
| FR-42 | Due-today / this-week / overdue / highest-balance lists | M | Must | FR-37 | — | M3, M4 | S3, S4 | R1 | US-0702, US-0704 | TC-0702-* | Four lists correct at boundary dates |
| FR-43 | Secure UUID debt link, 30-day expiry | M | Should | D-17, CR-07 | PRIV, AUTHZ | M8 | S8 | R1.1 | US-0901, US-0902 | TC-0901-* | AC-05; revoked/expired links rejected |
| FR-44 | WhatsApp share | M | Should | FR-43 | PRIV | M8 | S8 | R1.1 | US-0903 | TC-0903-* | Opens the share sheet / `wa.me` with link + text |
| FR-45 | Unified NIS currency | P (implicit only) | Must | D-09 | MONEY | M1 | S1 | R1 | US-0102, US-0106 | TC-0102-* | API meta `currency=ILS`; UI shows ₪ |
| FR-46 | Dashboard summary | P (v0.2: "new debt" metric missing; added to US-0801) | Must | D-08, FR-22 | ISO | M3, M5 | S3, S5 | R1 | US-0801, US-0802, US-0803 | TC-0801-* | AC-10; TC-0801-05 new debt |
| FR-47 | Today / week / month / year filters | IV (UTC: DEF-07) | Must | D-23 | — | M1, M3 | S1, S3 | R1 | US-0107, US-0801 | TC-0107-* | Boundaries correct in store timezone |
| FR-48 | Actionable insights | M | Must (stronger cards: Should) | FR-22, FR-37 | — | M3 | S3 | R1 | US-0801, US-0802 | TC-0801-* | Overdue, due-today, low-stock, high-balance cards |
| FR-49 | AI assistant interface | M | Must | D-15 | AUTHZ | M7 | S7 | R1.1 | US-1001, US-1005, US-1006 | TC-1001-*, TC-1005-*, TC-1006-* | Chat on web + mobile |
| FR-50 | AI understands supported questions | M | Must | FR-51 | ISO | M7 | S7 | R1.1 | US-1002 | TC-1002-* | Evaluation set ≥ agreed accuracy |
| FR-51 | AI read tools (sales, total debt, customer balance, low stock) | M | Must | FR-22, FR-41 | ISO, AUTHZ | M7 | S7 | R1.1 | US-1002 | TC-1002-* | AC-09 |
| FR-52 | AI daily summary from real data | M | Must (richer: Should) | FR-51 | ISO | M7 | S7 | R1.1 | US-1002 | TC-1002-05 | Summary numbers equal dashboard numbers |
| FR-53 | AI recognizes invoice/payment actions | M | Must | D-29 | AUTHZ | M7 | S7 | R1.1 | US-1003, US-1004 | TC-1003-*, TC-1004-* | Intent test set |
| FR-54 | AI structured drafts | M | Must | FR-53 | — | M7 | S7 | R1.1 | US-1003, US-1004 | TC-1003-*, TC-1004-* | Draft JSON schema validated |
| FR-55 | Backend validates AI drafts | M | Must | FR-54 | ATOM | M7 | S7 | R1.1 | US-1003, US-1004 | TC-1003-*, TC-1004-* | Same validators as manual flow; re-validated on confirm |
| FR-56 | Exact preview before write | M | Must | FR-55 | — | M7 | S7 | R1.1 | US-1003–US-1006 | TC-1005-*, TC-1006-* | Preview fields equal executed record |
| FR-57 | Explicit confirmation | M | Must | FR-56 | AUTHZ, IDEM | M7 | S7 | R1.1 | US-1003–US-1006 | TC-1003-*, TC-1004-* | No write without confirm; double confirm = one write |
| FR-58 | AI invoice via normal path | M | Must | US-0501/0502 | ATOM | M7 | S7 | R1.1 | US-1004 | TC-1004-* | AC-08 |
| FR-59 | AI payment via normal path | M | Must | US-0703 | ATOM | M7 | S7 | R1.1 | US-1003 | TC-1003-* | Same service; idempotent |
| FR-60 | Voice-to-text for AI | M | Unclear (§1.8 in scope; not in §6.1) | FR-49, D-16, CR-12 | PRIV | M8 (mobile), M10 (web, optional) | S8, S10 | R1.1 / R2 | US-1007, US-1008 | TC-1007-* | Voice transcript feeds the same endpoint as text |
| FR-61 | AI only uses allowed tools | M | Must | D-29 | AUTHZ | M7 | S7 | R1.1 | US-1001, US-1002 | TC-1002-*, TC-1001-* | Tool allow-list test; unknown tool rejected |
| FR-62 | AI never invents data | M | Must | FR-51 | — | M7 | S7 | R1.1 | US-1002, US-1004 | TC-1004-* | Prices/balances come from DB; unknown entity yields a question |
| FR-63 | AI failure → no partial records, retry | M | Must | FR-57 | ATOM, IDEM | M7 | S7 | R1.1 | US-1001, US-1003, US-1004 | TC-1001-* | Provider timeout leaves no record |
| FR-64 | Offline local transactions | M / B | Must (**narrowed by CR-02**: returns and opening debts never offline) | US-0101, D-02, D-19, CR-02 | IDEM | M9 | S9 | R2 | US-1102, US-1103 | TC-1103-* | AC-06 (sales + payments) |
| FR-65 | FIFO sync order | M / B | Must | FR-64 | IDEM | M9, M10 | S9, S10 | R2 | US-1101, US-1104 | TC-1104-* | AC-07 |
| FR-66 | Idempotent resubmission | M (server part in R1) | Must | D-04 | IDEM | M1, M9 | S1, S9 | R1 (server), R2 (sync) | US-0101, US-1101 | TC-0101-*, TC-1101-* | Same key → same result, one record |
| FR-67 | Sync indicator | M / B | Must | FR-65 | — | M10 | S10 | R2 | US-1104 | TC-1104-* | Three states visible |
| FR-68 | Queue limit 1000 | M / B | Must | FR-64, D-18 | — | M10 | S10 | R2 | US-1105 | TC-1105-* | Warn at 800, block at 1000 |
| FR-69 | Optional location / time | M | Could ("where enabled") | FR-64 | PRIV | M10 | S10 | R2 | US-1107 | TC-1107-* | Captured only when enabled and permitted |
| FR-70 | Critical audit logging | P | Must | — | AUD | M1 (+ each story) | S1+ | R1 | US-0103 + critical stories | TC-0103-* | Actor + timestamp for AI writes, reversals, role changes, voids, adjustments |

---

## 3. Non-Functional Requirements (NFR-01 – NFR-16)

| ID | Requirement | Status | Priority | Depends on | MS | Sprint | Rel | Stories | Tests | Acceptance evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| NFR-01 | API ≤ 3 s (excl. AI) | B (no perf test) | Must | Deployment | M6 | S6 | R1 | US-1404 | TC-1404-01 | p95 < 3 s on staging with a seeded store |
| NFR-02 | Barcode → product ≤ 1.5 s | B | Must | FR-17 | M5, M6 | S5, S6 | R1 | US-0505, US-1404 | TC-1404-02 | Stopwatch run of 20 scans on the reference device |
| NFR-03 | Local search ≤ 0.5 s for 10 k items | B | Must | US-1102 | M9, M10 | S9, S10 | R2 | US-1102, US-1405 | TC-1405-01 | Benchmark on the reference device |
| NFR-04 | Offline readiness | M | Must | FR-64 | M9 | S9 | R2 | US-1103 | TC-1103-* | Airplane-mode sale + payment |
| NFR-05 | Local commit ≤ 200 ms | B | Must | FR-64 | M9, M10 | S9, S10 | R2 | US-1103, US-1405 | TC-1405-02 | Timed integration test |
| NFR-06 | Sync ≤ 60 s at ≥ 1 Mbps | M | Must | US-1101 batch endpoint | M10 | S10 | R2 | US-1104, US-1405 | TC-1405-03 | 100- and 1000-item queues under throttled network |
| NFR-07 | Statement page ≤ 3 s on 4G | M | Should | FR-43 | M8 | S8 | R1.1 | US-0902 | TC-0902-03 | Lighthouse, 4G throttling |
| NFR-08 | Security baseline | P (DEF-08, DEF-15) | Must | — | M1, M6 | S1, S6 | R1 | US-0104, US-0106, US-1401 | TC-0104-*, TC-1401-* | Throttle, expiry, HTTPS, secure errors, CORS allow-list |
| NFR-09 | Non-sequential expiring link token | M | Should | D-17 | M8 | S8 | R1.1 | US-0901 | TC-0901-* | AC-05 |
| NFR-10 | Atomic and retry-safe financial operations | P (atomic yes, retry-safe no) | Must | D-04 | M1, M2 | S1, S2 | R1 | US-0101, US-0501–0503 | TC-0101-*, TC-0501-03 | Fault-injection + replay tests |
| NFR-11 | Data integrity | P (DEF-03, DEF-16) | Must | D-09, D-24 | M1 | S1 | R1 | US-0102, US-0108 | TC-0102-*, TC-0108-* | MySQL-parity suite green; invariants hold |
| NFR-12 | Mobile usability | B | Must | Flutter | M5, M6 | S2, S5, S6 | R1 | US-1502, US-0505, US-0506, US-1403 | TC-1403-* | Task-based checks: sale ≤ 4 taps after scan |
| NFR-13 | Maintainable Flutter architecture | B | Must | D-20 | M1, M2 | S1, S2 | R1 | US-1302, US-1301 | TC-1302-*, TC-1301-* | `flutter analyze` clean; folder template; pinned deps; gate G-FL |
| NFR-14 | Web accessibility | M | Should | — | M1, M3, M6 | S1, S3, S6 | R1 | US-1501, US-1201, US-1403 | TC-1201-*, TC-1403-* | Checklist in [06 §8](06-ui-ux-and-screen-plan.md) |
| NFR-15 | Privacy | P | Must | D-15, D-17 | M1, M7, M8 | S1, S7, S8 | R1–R1.1 | US-0105, US-1001, US-0901 | TC-0901-*, TC-1001-* | No cross-store or unauthorized exposure; AI data minimization |
| NFR-16 | Backup and recovery | B (no hosting) | Must | D-25 | M6 | S6 | R1 | US-1402 | TC-1402-01 | Restore drill on staging documented |

---

## 4. Business Rules (BR-01 – BR-14)

| ID | Rule | Status | Depends on | MS | Sprint | Rel | Stories | Tests | Acceptance evidence |
|---|---|---|---|---|---|---|---|---|---|
| BR-01 | Credit limit (when enabled) | M | D-26 | M2 | S2 | R1 | US-0305, US-0502 | TC-0305-*, TC-0502-04 | Over-limit credit sale rejected (422) |
| BR-02 | No AI financial write before confirmation | M | D-29 | M7 | S7 | R1.1 | US-1003, US-1004 | TC-1003-02, TC-1004-02 | Draft with no confirm → zero records |
| BR-03 | NIS unified currency | P | D-09 | M1 | S1 | R1 | US-0102 | TC-0102-* | Currency metadata + formatting |
| BR-04 | Products with sales not hard-deleted | M | FR-15 | M2 | S2 | R1 | US-0401 | TC-0401-04 | DELETE refused; deactivate allowed |
| BR-05 | FIFO for offline queue | M | FR-64 | M10 | S10 | R2 | US-1104 | TC-1104-01 | AC-07 |
| BR-06 | Secure link: no explicit IDs | M | D-17 | M8 | S8 | R1.1 | US-0901 | TC-0901-02 | URL contains only the token |
| BR-07 | Closed invoice → corrections via controlled workflows | P / A | D-06, CR-03 | M2 | S2 | R1 | US-0503 | TC-0503-* | Edit endpoint rejects financial fields |
| BR-08 | Local time retained; location optional | P (server timestamps only) | FR-64 | M9, M10 | S9, S10 | R2 | US-1103, US-1107 | TC-1103-03 | `occurred_at` preserved through sync |
| BR-09 | OTP for store activation | M | D-14 | M6 | S6 | R1 | US-0203 | TC-0203-* | Unverified store cannot operate |
| BR-10 | Never discard local financial transactions; conflict state | M | D-03 | M9, M10 | S9, S10 | R2 | US-1101, US-1106 | TC-1101-*, TC-1106-* | Conflict items persisted and resolvable |
| BR-11 | Low-stock default 5 | M | FR-22 | M2 | S2 | R1 | US-0403 | TC-0403-01 | Default applied when not configured |
| BR-12 | Queue ≤ 1000 without recovery action | M | D-18 | M10 | S10 | R2 | US-1105 | TC-1105-* | Block at limit |
| BR-13 | AI cannot exceed user permissions | M | D-12 | M7 | S7 | R1.1 | US-1002, US-1003, US-1004 | TC-1002-04 | An employee AI request for a manager-only action is denied |
| BR-14 | DB and backend are the source of truth | M | D-29 | M7 | S7 | R1.1 | US-1002, US-1004 | TC-1004-03 | Model-supplied price ignored |

---

## 5. Use Cases (UC-01 – UC-22)

| UC | Name | Status | MS | Sprint | Rel | Stories |
|---|---|---|---|---|---|---|
| UC-01 | Register owner and store | P (API only; no OTP) | M3, M6 | S3, S6 | R1 | US-0201, US-0203 |
| UC-02 | Verify store by OTP | M | M6 | S6 | R1 | US-0203 |
| UC-03 | Login / logout | P (React broken; no mobile) | M3, M5 | S3, S5 | R1 | US-0202, US-0205 |
| UC-04 | Manage staff and roles | P (API only) | M1, M4 | S1, S4 | R1 | US-0105, US-0204 |
| UC-05 | Manage customers | P (API only) | M4, M5 | S4, S5 | R1 | US-0301, US-0304 |
| UC-06 | View customer statement | M | M3, M4 (internal); M8 (public) | S3, S4, S8 | R1 / R1.1 | US-0302, US-0303, US-0902 |
| UC-07 | Manage products | M | M2, M4 | S2, S4 | R1 | US-0401, US-0405 |
| UC-08 | Scan product by barcode | M / B | M5 | S2, S5 | R1 | US-1301, US-0505 |
| UC-09 | Manage inventory | M | M2, M4 | S2, S4 | R1 | US-0402, US-0405 |
| UC-10 | Create cash sale | P | M2, M5 | S2, S5 | R1 | US-0501, US-0506 |
| UC-11 | Credit or partial sale | P | M2, M5 | S2, S5 | R1 | US-0502, US-0506 |
| UC-12 | Process sale return | M | M3, M4 (web); M8 (mobile) | S3, S4, S8 | R1 / R1.1 | US-0601, US-0602, US-0603 |
| UC-13 | Record payment | P (API only) | M3–M5 | S3–S5 | R1 | US-0703, US-0704, US-0705 |
| UC-14 | Reverse payment | P (API only) | M3, M4 | S3, S4 | R1 | US-0703, US-0704 |
| UC-15 | Manage debts | P | M2–M4 | S2–S4 | R1 | US-0701, US-0702, US-0704 |
| UC-16 | Generate and share secure link | M | M8 | S8 | R1.1 | US-0901, US-0903 |
| UC-17 | Dashboard and alerts | P | M3, M5 | S3, S5 | R1 | US-0801, US-0802, US-0803 |
| UC-18 | Ask AI business question | M | M7 | S7 | R1.1 | US-1002, US-1005, US-1006 |
| UC-19 | Create invoice using AI | M | M7 | S7 | R1.1 | US-1004 |
| UC-20 | Record payment using AI | M | M7 | S7 | R1.1 | US-1003 |
| UC-21 | Use voice input | M | M8 | S8 | R1.1 | US-1007 |
| UC-22 | Synchronize offline transactions | M | M9, M10 | S9, S10 | R2 | US-1101, US-1104, US-1105, US-1106 |

---

## 6. MVP Acceptance Criteria (AC-01 – AC-10)

| AC | Criterion (short) | Release | Verifying stories | Test cases |
|---|---|---|---|---|
| AC-01 | Barcode scan adds product within target | R1 | US-0505, US-1404 | TC-0505-01, TC-1404-02 |
| AC-02 | Repeat scan increments quantity | R1 | US-0505 | TC-0505-02 |
| AC-03 | Credit invoice updates total, payment, debt and stock | R1 | US-0502 | TC-0502-01 – 03 |
| AC-04 | Return restores stock and recalculates balance | R1 | US-0601 | TC-0601-01 – 04 |
| AC-05 | Link has no sequential ID and expires in 30 days | R1.1 | US-0901 | TC-0901-01 – 03 |
| AC-06 | Offline transaction synced exactly once | **Server idempotency part: R1**; offline part: R2 | US-0101, US-1103, US-1104 | TC-0101-01, TC-1104-02 |
| AC-07 | 10 queued items sync FIFO without duplicates | R2 | US-1104 | TC-1104-01 |
| AC-08 | AI invoice preview, execute only after confirm | R1.1 | US-1004 | TC-1004-01, 02 |
| AC-09 | AI tool cannot read another store | R1.1 | US-1002 | TC-1002-03 |
| AC-10 | Dashboard shows sales, collections, debt, low stock per period | R1 | US-0801, US-0802 | TC-0801-01 – 04 |

---

## 7. Gap Summary

| Category | Count | IDs |
|---|---|---|
| FR implemented and verified (IV) — API level | 12 | FR-01, 03, 04, 07, 08, 10, 24, 34, 38, 39, 41, 47 |
| FR implemented, unverified (IU) | 3 | FR-05, 14, 29 |
| FR partial (P) | 14 | FR-06, 09, 11, 12, 23, 25, 27, 30, 31, 35, 40, 45, 46, 70 (v0.2: FR-11 moved from IV) |
| FR missing / blocked (M / B), including ambiguous | 41 | All remaining FRs. FR-33 is also **ambiguous** (return rule, D-05). |
| **Total** | **70** | |

> Several "IV" items still have client gaps (React or Flutter) or known defects, which are listed in their rows. "IV" refers only to the backend behaviour covered by the passing tests on 2026-10-12. The per-row status above is authoritative.

### 7.1 Missing functionality, grouped by module

| Module | Missing items |
|---|---|
| Catalog | products, barcode, stock movements, adjustments, low stock |
| Sales | product-linked items, partial payment at sale, stock deduction, walk-in sales, void |
| Returns | entire module |
| Debts | customer link, due dates, overdue, lists, return credit, statement |
| Security / ops | idempotency, audit log, throttling, token expiry, deactivation, timezone, CI, deployment |
| Accounts | OTP, store status |
| Sharing | secure link, public statement, WhatsApp |
| AI | everything |
| Offline | everything |
| React | everything except landing/login/register shells |
| Flutter | everything |

### 7.2 Defects

See [00 §5](00-project-baseline.md#5-defect-register-baseline): DEF-01 – DEF-18, each mapped to a fixing story.

### 7.3 Ambiguities and contradictions

Each is resolved by a decision or change request in [03](03-decision-log-and-change-requests.md).

| Ambiguity | Resolved by |
|---|---|
| Return rule | D-05 / CR-05 |
| "Finalized" invoice | D-06 / CR-03 |
| Walk-in customer | D-07 / CR-04 |
| Collections | D-08 / CR-09 |
| Offline validation | D-03 |
| Queue limit behaviour | D-18 |
| OTP identity | D-14 / CR-08 |
| Permission grants | D-12 / CR-10 |
| UUID access control | D-17 / CR-07 |
| Voice on web | D-16 / CR-12 |
| Local storage technology | D-19 / CR-11 |
| Units of measure | CR-13 |
| Timezone | D-23 / CR-14 |
| Voice priority (§1.8 vs §6.1) | Flagged as "Unclear"; TL to confirm with CR-01 |

---

## 8. SRS Requirements Not in R1 (v0.2)

> R1 is the **first launchable increment**, not the SRS-defined MVP.
>
> - SRS chapter 10 (MVP Acceptance Boundary) requires Offline, Sync, AI Read, AI Action, Voice and Secure Link.
> - These are delivered in R1.1 and R2.
> - Naming R1 "MVP" requires CR-01 **and** an SRS amendment under the SRS Change Rule.

### 8.1 Deferred to R1.1 (each item has a release)

| Group | IDs |
|---|---|
| FR | FR-43, FR-44, FR-49 – FR-59, FR-61 – FR-63, FR-60 (mobile part), FR-32 (mobile part) |
| BR | BR-02, BR-06, BR-13, BR-14 |
| NFR | NFR-07, NFR-09 |
| UC | UC-16, UC-18, UC-19, UC-20, UC-21, UC-06 (public part), UC-12 (mobile part) |
| AC | AC-05, AC-08, AC-09 |

### 8.2 Deferred to R2

| Group | IDs |
|---|---|
| FR | FR-64 (sales and payments), FR-65, FR-66 (sync part), FR-67, FR-68, FR-69 (Could), FR-20 (mobile part) |
| NFR | NFR-03, NFR-04, NFR-05, NFR-06 |
| BR | BR-05, BR-08 (local time), BR-10, BR-12 |
| UC | UC-22 |
| AC | AC-06 (offline part), AC-07 |
| Other SRS responsibilities | §9.2 (Hive, queue, sync indicator), §9.4 (sync status), §1.5 objective "continue locally when internet is unavailable" |

### 8.3 Reduced or narrowed — not deferred; each needs an explicit CR decision

| Item | What is lost | CR |
|---|---|---|
| FR-64 | Returns and opening-debt operations are **never** available offline (Must requirement reduced) | CR-02 |
| FR-60 | Web voice is optional (Could) and may never be built ("approved web clients" = none) | CR-12 |
| FR-08 | Only the owner invites staff, instead of "authorized users" | CR-10 |
| §3.2 | No per-user grants ("unless explicitly authorized") | CR-10 |
| ERD PaymentGroup | A UUID column instead of a table (data-model deviation; no behaviour lost) | CR-06 (documentation) |
| Units of measure | Integer quantities only; no selling by weight | CR-13 |

### 8.4 Gaps inside R1 (to be built, not deferred)

| Requirement | Gap | Covered by |
|---|---|---|
| FR-11 | Deactivation of customers with financial history | US-0301, D-33 |
| FR-46 | "New debt" metric | US-0801 AC 5 |

### 8.5 Is deferring Offline to R2 acceptable?

- **Technically:** yes. It is the highest-risk part, it depends on idempotency (S1) and a stable data model, and deferring it saves ≈ 9.5–11 dd in R1.
- **Against the SRS:** no, unless CR-01 is approved. Offline, FIFO sync and idempotent sync are Must (§6.1) and part of chapter 10.
- **Commercially:** only if the pilot shops have reliable connectivity (D-35, SRS §1.2). Otherwise offline sales and payments must move into R1.
