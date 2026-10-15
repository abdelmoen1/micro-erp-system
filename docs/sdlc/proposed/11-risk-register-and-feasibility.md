# 11 — Risk Register, Estimation and Feasibility

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL**
> Owner codes: **TL** = Team Leader (decisions, external accounts, sign-off) · **DEV** = primary developer. These are currently the same person; they are kept separate to make responsibilities explicit.

## 1. Risk Register

Severity and likelihood are rated **H**igh, **M**edium or **L**ow.

| ID | Risk | Sev | Lik | Mitigation | Owner | Linked items |
|---|---|---|---|---|---|---|
| R-01 | Offline sync produces duplicate, lost or misordered financial records | H | M | Idempotency from S1 (US-0101); per-item results; conflicts held, never discarded; FIFO tests; field test before R2 (G-R2) | DEV | D-03, US-1101–1104 |
| R-02 | Flutter learning curve slows mobile delivery (limited experience) | H | **H** | Early walking skeleton (S2); fixed folder template; widely documented packages; small stories; a 0.75 dd hardening buffer in S5; option of a Flutter contributor (§6) | TL / DEV | US-1301, S5 |
| R-03 | Barcode scanning too slow or unreliable on low-end devices or in poor light | M | M | Choose the reference device early; spike in S2; manual search fallback always available; measure NFR-02 | DEV | US-0505, US-1404 |
| R-04 | Hardening the existing financial code breaks working behaviour | H | M | 13 passing feature tests kept; probes converted into tests first; behaviour changes only through approved decisions; MySQL parity | DEV | S1 |
| R-05 | Backfill migrations (debts `customer_id`, payments `store_id`) assign wrong data | H | L | Migration tests assert a 100% match; run on a copy first; backup before migrating; reversible `down()` | DEV | US-0701, US-0703 |
| R-06 | Return rule disputed after implementation | M | M | Explicit decision D-05 before S3; preview shown to the user before confirm | TL | CR-05 |
| R-07 | AI provider cost or latency is unacceptable | M | M | Evaluation spike measures both; cap tokens; cache tool results; text-only fallback | TL | D-15, US-1001 |
| R-08 | Arabic dialect misunderstood → wrong drafts | H | M | Drafts only; mandatory preview + confirm; disambiguation; evaluation set threshold | DEV | D-29, US-1002–1004 |
| R-09 | OTP provider onboarding, sender ID or coverage delays activation | M | **H** | Start the account in S1; `log` driver keeps development unblocked; fallback provider shortlist | TL | D-14, US-0203 |
| R-10 | UI scope creep (extra screens, polish) consumes the schedule | M | M | Screen inventory is closed; additions require a change request; component reuse | TL | [06](06-ui-ux-and-screen-plan.md) |
| R-11 | Hosting not ready or unsuitable (no queue worker, no SSH) | M | M | Decide by the end of S4 against the checklist ([12](12-release-and-deployment-plan.md)) | TL | D-25 |
| R-12 | MySQL test environment setup delays S1 | L | M | XAMPP MySQL is present locally; CI service container as an alternative | DEV | US-0108 |
| R-13 | Secure link leaks customer data (enumeration, oversharing) | H | L | Hashed UUIDv4; minimal payload; rate limit; expiry and revoke; security checklist | DEV | D-17, US-0901 |
| R-14 | Local storage choice (Hive) is unsuitable or unmaintained | M | M | Benchmark and maintenance check at the R2 start (D-19); CR-11 fallback | TL | D-19 |
| R-15 | Android device fragmentation (camera, permissions, OS versions) | M | M | Name one reference device plus one low-end device for checks | TL | US-1404, US-1405 |
| R-16 | Single developer is unavailable or overloaded (bus factor = 1) | H | M | Small stories; documentation per story; CI as an objective check; progress notes | TL | — |
| R-17 | Stale worktree `backend-features-testing` with uncommitted edits causes confusion or accidental merge | L | L | TL reviews and discards or archives it before S1 | TL | [00 §2](00-project-baseline.md) |
| R-18 | Estimates are optimistic (AI-assisted speed overestimated) | M | M | 15–25% contingency; compare actual to estimate after each sprint; re-plan at each G-S gate | TL | §5 |
| R-19 | Requirements change mid-flight without updating the SRS or plan | M | M | Change-request rule (SRS change control); traceability maintained in [01](01-requirements-gap-analysis.md) | TL | — |
| R-20 | SQLite-only green tests mask MySQL behaviour | M | M (proven by DEF-16) | MySQL suite as a gate (D-24) | DEV | US-0108 |
| R-21 *(v0.2)* | Pilot shops have unreliable internet, so the online-only R1 cannot be used in practice | H | M (unverified) | TL surveys the pilot shops before the end of S4 (D-35); fallback is R1-Offline (+≈ 9.5 dd) | TL | D-02, D-35 |
| R-22 *(v0.2)* | Shops need to sell by weight, which the integer-only quantity model cannot support | M | M | Decide CR-13 before S2 (product schema); +1.0–1.5 dd if needed | TL | CR-13 |
| R-23 *(v0.2)* | The approved SRS is not pinned in the repo, so the plan may trace to the wrong version | M | L | D-28 + US-0109 in S1; matrix marked PROVISIONAL until then | TL | D-28, US-0109 |

---

## 2. Technical Dependency Register

| Dependency | Needed by | Status | Action owner |
|---|---|---|---|
| TL decisions D-04, 09, 12/CR-10, 13, 22, 23/CR-14, 24 (v0.2) | S1 | Pending | TL |\n| SRS v1.1 committed + SHA-256 recorded (D-28) | S1 (US-0109) | Pending | TL |\n| PDF text-extraction tool (developer tool, not a project dependency) for US-0109 | S1 | Not installed | TL / DEV |
| Disposable MySQL test DB | S1 | XAMPP present; DB not created | DEV |
| GitHub Actions enabled on the repository | S1 | Unverified | TL |
| Flutter SDK + Android SDK + reference **and** low-end phones | **S1** (US-1302) | **Not installed** | TL / DEV |
| D-05 return rule | S3 | Pending | TL |
| D-21 TanStack Query dependency | S3 | Pending | TL |
| Hosting account (D-25) | S6 | Pending | TL |
| OTP provider account and credentials (D-14) | S6 | Pending; lead time unknown | TL |
| AI provider account and key (D-15) | S7 | Pending | TL |
| Local storage benchmark (D-19) | S9 | R2 | DEV |

---

## 3. Open Decisions

See [03 Part 3](03-decision-log-and-change-requests.md#part-3--decision-status-tracker).

Blocking S1 (corrected in v0.2): **D-04, D-09, D-12/CR-10, D-13, D-22, D-23/CR-14, D-24, D-28.** D-01 and D-02 no longer block S1; they must be decided before S5–S6 release planning (D-02 together with D-35 by the end of S4).

---

## 4. Scope Trade-off Register

| Trade-off | Option chosen (proposed) | What is given up | What is gained | Reversible? |
|---|---|---|---|---|
| Offline timing | R2 | Selling during outages in R1 | ~11 dd earlier first release; offline built on a stable API | Yes |
| AI timing | R1.1 | AI differentiator absent from R1 | AI built on final services; no tool rework | Yes (swap S5 and S7) |
| Web POS | Not built | Desktop selling | ~0.75 dd | Yes (CR) |
| Mobile returns and adjustments | R1.1 / R2 | Counter returns on the phone in R1 | ~1.25 dd in R1 | Yes |
| Offline returns | Online only (CR-02) | Returns during outages | Large reduction in conflict surface | Yes, at higher cost |
| Integer quantities | CR-13 | Weighted goods | ~1 dd of unit-of-measure design | Yes |
| Chart library | None (CSS bars) | Rich charts | No dependency; less maintenance | Yes |
| Per-user permissions | Fixed matrix | Fine-grained grants | Simpler, testable RBAC | Yes |
| Web voice | Optional R2 | Voice on the desktop | Browser compatibility issues avoided | Yes |

---

## 5. Effort Estimates and Assumptions

> **v0.2 changes:**
> - Figures are recomputed from the stories in [08](08-user-stories-and-technical-tasks.md): R1 +2.0 dd.
> - The v0.1 "breakdown by effort type" was a **top-down allocation**, not derived from the stories. It is replaced by a **story-derived breakdown by platform**.
> - Contingency is now differentiated and applied identically to both scenarios.

### 5.1 Assumptions

| Assumption | Detail |
|---|---|
| A-01 / A-07 | One developer, ~6 productive h/day, full-time 5 days/week, AI-assisted. **Confirm (D-34).** |
| Other | A-02 to A-09 from [00 §7](00-project-baseline.md#7-assumptions-used-by-this-package) |
| What an estimate includes | Tests (≈ 30–40% of each story, per the DoD), integration, debugging and verification; not just first-draft code |
| Backend | Reuses the existing isolation, locking and reversal patterns. A CRUD resource with tests ≈ 0.75 dd. Financial services with atomicity and idempotency tests ≈ 1.0–1.5 dd. |
| React | No UI kit; 0.5–0.75 dd per screen including all states; the API exists before the screen; no automated component tests unless D-32 is approved |
| Flutter | Developer with limited Flutter experience. **Calibrated by the pace factor k at gate G-FL (end of S2).** Includes environment setup (US-1302) and spikes (US-1301). |
| Decisions | Approved before their blocking sprint. A late decision causes idle or rework time that is **not** included. |
| Excluded | Waiting time for external providers (OTP, AI, hosting) and SDK/Gradle download time (runs in the background) |
| SRS | No change during R1 |

### 5.2 Breakdown by platform — derived from the stories (R1, base dd)

| Platform | dd | Derivation |
|---|---|---|
| Backend (Laravel + tests) | 15.5 | S1: 5.25 (US-0101–0108) + S2: 5.0 + S3: 4.25 + US-0203 OTP: 1.0 |
| React | 7.0 | S3: 1.75 (US-1201, 0202, 0201, 0802) + S4: 5.25 |
| Flutter | 8.5 | US-1302: 0.5 + US-1301: 1.5 + S5: 6.5 |
| UX / design | 1.5 | US-1501, US-1502, US-1503 |
| Release, ops, QA, documentation | 3.25 | US-0109: 0.25 + S6 without OTP: 3.0 |
| **R1 total** | **35.75** | |
| R1.1 | 8.25 | S7: 4.75 + S8: 3.5 |
| R2 | 11.0 | S9: 5.5 + S10: 5.5 |
| **Scenario A total** | **55.0** | |

### 5.3 Contingency — method

Contingency = base dd × the rate for the work's uncertainty, summed per release.

| Work | Base dd | Rate | Contingency | Rationale |
|---|---|---|---|---|
| R1 Flutter | 8.5 | 30% | 2.55 | Limited experience; not yet calibrated (lowered to 15% after G-FL if k ≤ 1.0) |
| R1 other | 27.25 | 15% | 4.09 | Reuses proven patterns |
| **R1** | **35.75** | | **6.64** | **≈ 42.4** |
| R1.1 | 8.25 | 15% | 1.24 | Cumulative ≈ 51.9 |
| R2 | 11.0 | 25% | 2.75 | Offline sync is untried; cumulative ≈ 65.6 |
| Scenario B extra (+2.5 base) | 2.5 | 15% | 0.38 | B ≈ 57.5 base / ≈ 68.5 |

### 5.4 Sensitivity

| If… | R1 impact |
|---|---|
| Flutter pace k = 1.5 (instead of 1.0) | S5 becomes 9.75 → R1 ≈ 39 dd base |
| OTP provider blocked at S6 | R1 cannot release (BR-09 is Must). It waits, or the TL approves a temporary CR. |
| Decision D-05 or D-06 late by 2 days | S2/S3 stall; re-order (web shell earlier) to absorb about 1 dd |
| Weighted goods needed (CR-13) | +1.0–1.5 dd in S2 |
| D-27 changed to allow-with-flag | +0.25 dd in S2 |
| Pilot shops need offline (D-35) | R1 ≈ 45 dd base (≈ 54 with contingency) |
| AI evaluation fails its threshold | R1.1 delayed: switch provider (+0.5–1 dd) or narrow the intents |

### 5.5 First launchable increment vs full SRS

| Scope | Base dd | With contingency | Calendar: full-time 5 d/week | Calendar: half-time |
|---|---|---|---|---|
| R1 (first launchable increment; **not** the SRS MVP) | 35.75 | ≈ 42.4 | ≈ 7–8.5 weeks | ≈ 14–17 weeks |
| R1 + R1.1 | 44.0 | ≈ 51.9 | ≈ 9–10.5 weeks | ≈ 18–21 weeks |
| R1 + R1.1 + R2 = **SRS MVP** (staged) | 55.0 | ≈ 65.6 | ≈ 11–13 weeks | ≈ 22–26 weeks |
| Scenario B (single release) | 57.5 | ≈ 68.5 | ≈ 11.5–14 weeks, with no release before the end | ≈ 23–27 weeks |

**History of these figures:**

- The Phase 0 estimate (36–52 dd for the full scope) was preliminary.
- v0.1 of this plan gave 53 / 56 dd.
- v0.2 adds the uncounted Flutter setup, the spikes, the SRS verification, two regression tests and two requirement gaps, and corrects the contingency method.

---

## 6. What Would Make 20 Days Feasible

**Finding:** With **one developer**, a financially safe web + mobile first release is **not feasible in 20 dd**. R1 needs 35.75 dd base.

**At base pace, day 20 = the end of S3.** That gives:

- the complete R1 API;
- the S1–S3 defects closed by permanent tests;
- the React foundation;
- Flutter readiness proven and calibrated.

With 15% slippage, it is late S3. Day 20 is an internal milestone, not a release.

| Option | Effect | Assessment |
|---|---|---|
| **1. Add two contributors:** one React and one Flutter developer, working from the frozen API contracts from about day 7 | The TL/backend path becomes S1 without US-1302 (6.0) + S2 without US-1301 (5.5) + S3 without the React stories (4.75) + S6 (4.0) ≈ 20.25 dd, with web and mobile built in parallel | **Feasible for R1 in ≈ 20–22 calendar days**, if the contributors are available and the contracts are frozen. Adds coordination and review overhead. |
| 2. Add one Flutter contributor only | The TL path is S1–S4 + S6 without the Flutter stories ≈ 27.25 dd | R1 in ≈ 27–29 days |
| 3. Treat day 20 as an **internal milestone**, not a release | See [02 §5](02-mvp-scope-and-release-strategy.md#5-what-is-demoable-at-day-20-scenario-a) | Honest and achievable; R1 lands at ≈ 36–42 dd |
| 4. Drop Flutter from R1 (web-only POS) | ≈ 27 dd | Violates the mobile-first SRS (§1.1); **not recommended** |
| 5. Skip S1 hardening, idempotency or tests | Saves ≈ 6–9 dd | **Rejected:** leaves P0 defects (DEF-02, DEF-05) open and makes offline unsafe later |

**Recommendation:** Option 3 by default. Option 1 if the TL can add contributors. **Never Option 5.**

---

## 7. Critical Path

See [07 §4](07-milestones-and-sprints.md#4-dependency-graph-and-critical-path). The external lead times (OTP provider, hosting, AI account, Flutter SDK and device) must be started by the TL **in S1** so they do not become the critical path.

---

## 8. Rollback and Backup Considerations

- **Additive changes:** every schema change is additive with a tested `down()`. Destructive column drops are deferred to a later clean-up release, after data is verified.
- **Backups:** a backup is taken immediately before each production migration (verified restorable, US-1402).
- **Feature flags:** risky behaviour (OTP enforcement, AI assistant, R2 sync) is controlled by configuration flags, so it can be disabled without redeploying.
- **Mobile releases:** use an internal testing track; keep the previous APK available. The `/api/v1` version stays backward-compatible across one mobile release.

Details are in [12](12-release-and-deployment-plan.md).

---

## 9. Deployment Prerequisites

| Prerequisite | Release |
|---|---|
| Hosting decision; staging + production environments | R1 |
| PHP 8.2+, MySQL 8, HTTPS certificate, queue worker, scheduler | R1 |
| Daily automated DB backups with verified restore | R1 |
| OTP provider credentials | R1 |
| Android signing key (stored securely, with a backup) | R1 |
| AI provider key, stored server-side only | R1.1 |

---

## 10. Progress Reporting

Use the weekly status format in [07 §5](07-milestones-and-sprints.md#5-progress-tracking-format), plus a risk delta (which R-xx changed and why) and a forecast against the R1 target.
