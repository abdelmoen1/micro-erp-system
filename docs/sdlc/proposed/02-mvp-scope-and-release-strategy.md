# 02 — MVP Scope and Release Strategy

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL** (decision D-01, change request CR-01) · Package v0.2
>
> **v0.2 corrections:**
> - R1 is renamed the **first launchable increment**. It is **not** the SRS-defined MVP (see §0).
> - The claim "nothing Must Have is dropped" was wrong (§2.4).
> - The Scenario B derivation is now explicit, and staging overhead is corrected to ≈ 0.5 dd (§3).
> - Contingency is differentiated and applied consistently to both scenarios.
> - Figures are updated: R1 = 35.75 dd base.
> - Launchability now depends on D-35 (§2.5).

## 0. Terminology: R1 vs the SRS "MVP"

**SRS chapter 10 (MVP Acceptance Boundary)** lists, among others:

- **Offline** — "core approved local operations work without internet";
- **Sync** — "FIFO and idempotency";
- **AI Read**, **AI Action**, **Voice**;
- **Secure Link**.

Therefore:

- **R1 does not meet the SRS MVP boundary.** It is the *first launchable increment* (Core Shop).
- **The SRS-defined MVP is reached when R2 completes**, unless the TL approves CR-01 **and** amends the SRS under its Change Rule ("Major requirement changes must be reflected in this SRS before becoming part of the MVP baseline").
- This package does not amend the SRS.

## 1. Planning Constraint

The SRS targets a **20-day MVP** ("approximately 20 development days", §1.7) delivered by one primary developer using AI assistance. That target is treated as a constraint to investigate, not as a guarantee.

**Units:**

- All estimates are in **developer-days (dd)** of about 6 productive hours (A-01).
- Calendar time depends on availability (A-07, D-34). Full-time, 5 days/week: weeks = dd ÷ 5.

**Each estimate covers:**

- coding;
- integration;
- verification and test writing;
- debugging;
- design time.

They are **not** first-draft code-generation times.

**Not included:** waiting time for TL decisions and for external providers (OTP, AI, hosting). Details are in [11](11-risk-register-and-feasibility.md) and [13 §1](13-final-review-and-decision-pack.md).

---

## 2. Scenario A — Staged Delivery (recommended)

### 2.1 Release R1 "Core Shop": the first launchable increment

**Business flow delivered end to end:**

```
Owner registers (OTP) → adds products & stock (web) → staff sells on mobile (barcode, cash / credit / partial)
→ stock and debt update atomically → payments recorded and reversible → returns processed (web)
→ dashboard shows sales, collections, new debt, outstanding debt, overdue, low stock (web + mobile)
```

**Financial safety included:**

| Safeguard | Story |
|---|---|
| Idempotent writes, replay-tested on every financial endpoint | US-0101 |
| Exact money arithmetic | US-0102 |
| Audit log | US-0103 |
| Immutable invoices with void | US-0503 |
| Role matrix + deactivation | US-0105 |
| Store-timezone boundaries | US-0107 |
| MySQL-parity tests | US-0108 |
| Financial invariant test | US-0703 |
| Login throttling and token expiry | US-0104 |

| Area | Included in R1 | Requirements |
|---|---|---|
| Accounts | Registration (web), OTP activation, login/logout on web and mobile, staff invite/role/deactivate (web) | FR-01–09, BR-09, UC-01–04 |
| Customers | CRUD + **deactivation** (web), quick lookup/create (mobile), summary + chronological statement (web), credit limit | FR-10–14, BR-01, UC-05, UC-06 (internal) |
| Products & inventory | Catalog, barcode, adjustments, movement history, low stock (web); search + low-stock view (mobile) | FR-15–22, BR-04, BR-11, UC-07, UC-09 |
| Sales | Mobile POS with camera barcode + repeat-scan increment; cash / credit / partial; walk-in cash; stock deduction; void (web) | FR-17, FR-18, FR-23–31, BR-07, UC-08, UC-10, UC-11, AC-01–03 |
| Returns | Item-level returns with debt-first rule (web) | FR-32, FR-33, UC-12, AC-04 |
| Debts & payments | Due dates, overdue / due / highest-balance lists, opening debts, payments, group-safe reversals, history (web); record payment (mobile) | FR-34–42, UC-13–15 |
| Dashboard | Extended metrics including new debt + insight cards (web); summary (mobile) | FR-41, FR-46–48, UC-17, AC-10 |
| Currency | NIS (`ILS`) everywhere | FR-45, BR-03 |
| Platform & quality | Idempotent API v1, audit log, throttling, CI on sqlite + MySQL, SRS pinned and verified, Flutter readiness gate, staging + production deployment, backups, smoke/UAT | FR-66 (server), FR-70, NFR-01, 02, 08, 10–14, 16 |

**Estimate:** **35.75 dd base → ≈ 42.4 dd with contingency.** Contingency is 30% on the 8.5 dd of Flutter work until gate G-FL calibrates it, and 15% on the remaining 27.25 dd. R1 spans six sprints, S1–S6 ([07](07-milestones-and-sprints.md)).

### 2.2 Release R1.1 "AI & Sharing"

| Area | Included | Requirements |
|---|---|---|
| AI assistant | Provider adapter + evaluation spike; read tools (daily sales, total debt, customer balance, low stock); daily summary; payment and invoice drafts with preview → confirm; chat on web and mobile | FR-49–59, FR-61–63, BR-02, BR-13, BR-14, UC-18–20, AC-08, AC-09 |
| Voice | Mobile on-device speech-to-text into the same AI endpoint | FR-60 (mobile), UC-21 |
| Secure debt link | Hashed UUIDv4 token, 30-day expiry, revocation, public statement page, WhatsApp share | FR-43, FR-44, BR-06, NFR-07, NFR-09, UC-16, AC-05 |
| Mobile returns | Return flow on mobile | FR-32 (mobile), UC-12 |

**Estimate:** 8.25 dd base (S7–S8), 15% contingency. **Cumulative 44.0 dd base / ≈ 51.9 dd with contingency.**

### 2.3 Release R2 "Offline" — completes the SRS MVP boundary

| Area | Included | Requirements |
|---|---|---|
| Offline | Local catalog/customer cache; offline sales and payments with local commit; FIFO batch sync with idempotency; sync indicator; queue limit; conflict review (web) | FR-64–68, NFR-03–06, BR-05, BR-08, BR-10, BR-12, UC-22, AC-06, AC-07 |
| Mobile completion | Stock adjustment on mobile; optional location capture | FR-20 (mobile), FR-69 |
| Optional | Web voice input on supporting browsers | FR-60 (web) |

**Estimate:** 11 dd base (S9–S10), 25% contingency for the uncertainty. **Cumulative 55.0 dd base / ≈ 65.6 dd with contingency.**

### 2.4 Requirements not in R1: deferred vs reduced

The full lists are in [01 §8](01-requirements-gap-analysis.md#8-srs-requirements-not-in-r1-v02).

| Requirement(s) | Status | Release | Reason |
|---|---|---|---|
| FR-49–59, 61–63, BR-02/13/14, UC-18–20, AC-08/09 (AI) | Deferred | R1.1 | Needs the stable catalog, sale and payment services from R1. Building AI first would mean reworking its tools. |
| FR-60, UC-21 (voice, mobile) | Deferred | R1.1 | Depends on the AI endpoint |
| FR-43, 44, BR-06, NFR-07, NFR-09, UC-16, AC-05 (secure link, WhatsApp) | Deferred | R1.1 | SRS "Should Have"; depends on the statement (US-0302) |
| FR-32 mobile part | Deferred | R1.1 | Returns are an Owner/Manager action, which the web covers in R1 |
| FR-64–68, NFR-03–06, BR-05/08/10/12, UC-22, AC-06 (offline part), AC-07 | Deferred | R2 | Highest technical risk; needs the idempotent API and a stable data model. **Requires CR-01; launchability also depends on D-35.** |
| FR-20 mobile part | Deferred | R2 | Web covers it in R1 |
| FR-69 location | Deferred | R2 | SRS "where enabled"; Could Have |
| **FR-64: returns and opening debts offline** | **Reduced, never delivered** | — | CR-02 |
| **FR-60: web voice** | **Optional; may never be delivered** | R2 (Could) | CR-12 |
| **FR-08 / §3.2: who may invite; per-user grants** | **Narrowed** | — | CR-10 |
| **Selling by weight** | **Not supported** | — | CR-13 (business question) |
| Web sale creation | Not an SRS requirement | R1.1 on request | D-30 |

> **Correction (v0.2):** v0.1 stated "nothing marked Must Have is dropped". **That was wrong.** CR-02 permanently reduces FR-64, which is a Must requirement. Every reduction above needs an explicit TL decision on its CR.

### 2.5 Is R1 launchable?

| Condition | R1 (online-only) launchable? |
|---|---|
| Pilot shops have reliable internet during trading hours (D-35 = yes) **and** CR-01 approved | **Yes**, as a first increment (not "MVP") |
| Pilot shops have frequent outages (D-35 = no) | **No.** SRS §1.2 requires selling to continue during outages. **R1-Offline** = R1 + US-1101–US-1106 + device tests ≈ **45 dd base (≈ 54 with contingency)** |
| CR-01 rejected | R1 can still ship internally, but it is not an SRS release. The SRS MVP = R2 completion |

**Optional R1 trims** (≈ −1 dd in total; each needs TL approval):

- mobile dashboard (the web covers it) −0.5 dd;
- CSS charts −0.25 dd;
- lighter web wireframes −0.25 dd.

---

## 3. Scenario B — Full SRS v1.1 in one release

| Workstream | dd (base) | Basis |
|---|---|---|
| All Scenario A work (R1 + R1.1 + R2) | 55.0 | Sum of the stories in [08](08-user-stories-and-technical-tasks.md) |
| − Intermediate R1.1 release step not needed | −0.5 | S8 "release 0.5" |
| + One larger UAT/regression covering AC-01 – AC-10 at once | +1.0 | Single acceptance run over all features |
| + Late-integration rework allowance | +2.0 | **Judgment, not measured**: AI + offline + returns integrated together, with no earlier field feedback |
| **Total base** | **57.5 dd** | |
| **With the same differentiated contingency as A** | **≈ 68.5 dd** | 65.6 (A) + 2.5 base + 0.4 contingency |

> **Correction (v0.2):** v0.1 gave B as 56 dd base with a flat 15% (≈ 64) and claimed staging costs "≈ 1–2 dd". Applying the same contingency rates as A, and deriving the overhead explicitly, gives the figures above. **The real extra cost of staging is ≈ 0.5 dd**: the R1.1 release step.

**Main dependencies:**

- Flutter SDK and two reference phones (A-05, US-1302);
- AI provider account (D-15);
- OTP provider (D-14);
- hosting (D-25);
- Hive/SQLite benchmark (D-19).

---

## 4. Comparison

| Criterion | Scenario A (staged) | Scenario B (single release) |
|---|---|---|
| Time to first launchable release | **35.75 dd base (≈ 42.4 with contingency)** | 57.5 dd base (≈ 68.5) |
| Time to full SRS scope (= SRS MVP) | 55.0 dd base (≈ 65.6) | 57.5 dd base (≈ 68.5) |
| Product value at first release | Full daily shop cycle on web + mobile; no AI, no offline | Everything, but much later |
| Technical risk | Spread out; offline built last on proven APIs | Concentrated at the end |
| Financial / data-integrity risk | **Lower**: integrity foundation first; each release validated | Higher: more simultaneous moving parts before first validation |
| Testing burden per release | Moderate, incremental regression | One very large UAT |
| Integration complexity | Incremental (API → web → mobile → AI → offline) | All at once |
| Demo quality | A real demo every sprint; real shop pilot possible after R1 (if D-35 = yes) | Partial demos until the end |
| Remaining work after first release | R1.1 (8.25 dd) + R2 (11 dd) | None |
| Risk to SRS fidelity | Requires CR-01; R1 is not the SRS MVP | None |

### Recommendation: **Scenario A**, with the R1 scope finalised after D-35.

- It reaches a launchable, financially safe product about 22 dd (≈ 4–5 weeks full-time) before Scenario B.
- Its total effort is ≈ 2.5 dd lower.
- Its only extra cost is ≈ 0.5 dd of intermediate release work.
- It produces real user feedback before the two highest-risk features (AI actions and offline sync) are built.

**Alternative considered and rejected:** moving AI into R1 ahead of mobile.

- This would better showcase the differentiator (SRS §1.6) to the mentor.
- However, it would put AI on top of APIs that are still changing, and delay the mobile POS (the primary platform) by about 5 dd.
- If the TL prioritises a mentor demo of AI over a usable mobile POS, swap S5 and S7. The dependencies allow it, because AI needs only the API.

---

## 5. What Is Demoable at Day 20 (Scenario A)

**At base pace:** the end of S3 falls exactly at 20.0 dd. **With 15% slippage:** ≈ 17.4 dd of planned work is done, which is late S3.

| Area | Ready at day 20 (base pace) | At risk with slippage |
|---|---|---|
| Backend R1 APIs | **All** complete and tested on sqlite + MySQL (except OTP): products, stock, cash/credit/partial sales, returns, due dates, overdue, statements, payments, dashboard | Dashboard v2 / statement may slip |
| Defects | DEF-01 – DEF-11, DEF-14, DEF-16 closed by permanent in-repo regression tests; DEF-12 closed via the CI lint job | — |
| React | Shell, login fixed, registration, dashboard | Dashboard page |
| Flutter | Toolchain and both phones proven (SP-01); skeleton + barcode/API/pace spikes done; **gate G-FL decided; S5 estimate calibrated** | — |
| SRS | v1.1 pinned and the matrix verified (US-0109), if D-28 is done | — |
| **Not ready** | Web admin screens (S4), mobile POS (S5), OTP, deployment, AI, secure links, offline | |

> **Honest feasibility statement:**
>
> - **Day 20 is an internal milestone, not a launchable release.** With one developer, no configuration delivers a financially safe web + mobile first release in 20 dd.
> - The ways to change this are described in [11 §6](11-risk-register-and-feasibility.md#6-what-would-make-20-days-feasible).
