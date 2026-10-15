# Planning Package — Change Log

> v0.1 – v0.3 rev. 1 were proposals; no decision was approved and no code changed in those versions.
> From v0.4 the TL approved Sprint 1 and its decisions (see v0.4). Code changes are tracked in git, not here.

## v0.4 — 2026-10-13 · Sprint 1 approved; documentation synchronized

- **Approved by the TL:** the Sprint 1 plan (14) at 12.75 dd base / ≈ 15.25 with contingency, and decisions D-04, D-09, D-12 (employees may record pay-all; write-offs need separate authorization and are never payments), D-13, D-20, D-22, D-23 / CR-14 (`Asia/Gaza` default, per-store), D-24, D-36 (`mobile/`), D-37 (`com.hisbah.smartshop`), D-38 (no OTP in S1). Recorded in 03 Part 3. CR-10 (SRS wording) stays open.
- **D-28 clarified:** the missing SRS v1.1 PDF blocks only US-0109 (final SRS verification). Independent Sprint 1 work proceeds; traceability is not claimed as verified.
- **Merged from 14 §12** into 08: US-1303 – US-1306, US-1505 – US-1508; T-0106-5 with TC-0106-04 / 05; US-1301 split (TC-1301-04 → TC-1305-01); US-0205, US-1502 moved to S1; US-1302, US-1501 re-estimated; reconciliation row S1 = 12.75.
- **07 updated:** S1 12.75, S2 5.25, S4 6.0, S5 6.0; R1 **40.5** (≈ 48.1), R1.1 48.75, R2 59.75; G-FL at the end of S1; day-20 line in early S3.
- **Not changed:** 02 and 11 still show the v0.2 R1 total in their narrative. 07 and 14 are authoritative for the figures until those files are revised.

## v0.3 rev. 1 — 2026-10-13 · TL review of the Sprint 1 plan

Only doc 14 changed, plus the README row and this entry.

- **React compatibility:** new task T-0106-5 updates the React base URL to `/api/v1` (`VITE_API_URL` with a default) in the same change set as the route move, fixes DEF-12 (one character), and adds a React lint/build CI job. New tests TC-0106-04 and TC-0106-05. Chosen over keeping the old `/api` paths, to avoid two live contracts.
- **Phase split** for UI/UX made explicit: US-1502 is P1 0.25 + P4 0.25; US-1507 is P1 0.125 + P2 0.125; revisions are P1 0.125 + P2 0.125.
- **Review timings:** DR-1 approved by ≈ 2.75 dd. DR-2 runs as one review in two touchpoints: direction pick ≈ 7.0, approved by ≈ 7.25.
- **Protected scope:** the two visual directions and both design reviews can no longer be cut. The new slip order is the prototype test, then US-0109, then the barcode spike.
- **Figures:** Sprint 1 12.5 → **12.75 dd** (≈ 15.25 with contingency); R1 40.25 → **40.5** (≈ 48.1); smallest coherent Sprint 1 = 11.75.

## v0.3 — 2026-10-13 · Sprint 1 execution proposal

- **Added** [14-sprint-1-execution-plan.md](14-sprint-1-execution-plan.md): a proposed Sprint 1 covering the backend foundations, the Flutter app from scratch and mobile UI/UX.
- **Proposed figures** (not applied to other files until approval):
  - Sprint 1: 6.5 → **12.5 dd** base (≈ 15 with contingency).
  - R1: 35.75 → **40.25 dd** base (≈ 47.8).
  - S2: 7.0 → 5.25; S4: 5.25 → 6.0 (new US-1508); S5: 6.5 → 6.0.
- **Proposed new IDs:** US-1303 – US-1306, US-1505 – US-1508, D-36 – D-38, UI-D4. US-1301 is split explicitly; TC-1301-04 is retired → TC-1305-01. All of this is listed in 14 §12, to be merged into 03 / 07 / 08 on approval.
- **Files changed:** README (index + review order) and this changelog only. 00 – 13 are unchanged. No code, Flutter project, package or migration was created.

## v0.2 — 2026-10-13 · Final pre-Sprint-1 review

Trigger: the TL requested a final review before Sprint 1 covering seven areas: arithmetic, SRS coverage, defect closure, Flutter readiness, SRS pinning, decision classification, and the executive summary. The full review is in [13](13-final-review-and-decision-pack.md).

### Corrections (errors in v0.1)

| # | v0.1 statement | Correction | Files |
|---|---|---|---|
| C-1 | R1 called the "Fastest Safe MVP" | R1 is the **first launchable increment**. The SRS MVP (chapter 10 boundary: Offline, Sync, AI, Voice, Secure Link) is reached when R2 completes, unless CR-01 is approved **and** the SRS is amended under its Change Rule. | 02, 03, 13 |
| C-2 | "Nothing marked Must Have is dropped" | Wrong. CR-02 permanently reduces FR-64 (no offline returns or opening debts). CR-12, CR-10 and CR-13 narrow other items. All are now listed as reduced/narrowed. | 01 §8, 02 §2.4, 03 |
| C-3 | Scenario B contingency was a flat 15%, while A used 15%/25% | Same differentiated rates for both. B = 57.5 base / ≈ 68.5. | 02 §3, 11 §5.3 |
| C-4 | "Staging costs ≈ 1–2 dd" | Derived explicitly: ≈ 0.5 dd (the R1.1 release step). B = A − 0.5 + 1.0 (UAT) + 2.0 (late-integration allowance, judgment). | 02 §3 |
| C-5 | "Breakdown by effort type" presented as an estimate | It was a top-down allocation. Replaced by a breakdown by platform derived from the stories. | 11 §5.2 |
| C-6 | Flutter setup listed only as a "lead time" | It is developer work: new story US-1302 (0.5 dd, S1). | 07, 08 |
| C-7 | D-01 and D-02 listed as S1 blockers; D-28 not blocking | D-01 and D-02 do not block S1 (S1 content is scenario-independent). D-28 blocks S1. D-06 was also removed from the S1 blockers in doc 00. | 00, 03, 07, 11, README |
| C-8 | "Advisory = applies unless the TL objects" | **Every decision needs an explicit TL decision**; nothing applies by default. | 03 |
| C-9 | Day-20 line "early S4" | At base pace, day 20 = end of S3 (20.0 dd); with 15% slippage, late S3. | 02 §5, 07 |

### Additions

| Item | Detail | dd |
|---|---|---|
| US-0109 | SRS baseline verification (closes DEF-18) | +0.25 (S1) |
| US-1302 | Flutter environment and device readiness (spike SP-01) | +0.5 (S1) |
| US-1301 | Extended with spikes SP-02 (barcode), SP-03 (auth/idempotency), SP-04 (pace calibration) and **gate G-FL** | +0.5 (S2) |
| TC-0101-07 | Replay test on every financial endpoint (DEF-02); DoD rule for new endpoints | +0.25 (S1) |
| TC-0703-06 | Financial invariant test after a randomized sequence (DEF-03, balance accuracy) | +0.25 (S3) |
| US-0301 AC 4 / TC-0301-03 | Customer deactivation (FR-11 gap, D-33) | +0.25 (S4) |
| US-0801 AC 5 / TC-0801-05 | "New debt" metric (FR-46 gap) | 0 |
| TC-0201-02 | Automated UI regression test for DEF-13, conditional on D-32 | 0 (+0.5 if D-32) |
| Decisions | D-31 (repeat-scan rule), D-32 (web UI test tool), D-33 (customer deactivation), D-34 (developer availability), D-35 (pilot-shop connectivity) | — |
| Risks | R-21 (pilot connectivity), R-22 (selling by weight), R-23 (unpinned SRS) | — |
| Assumptions | A-05 revised; A-07 (availability), A-08 (connectivity), A-09 (SRS not pinned) | — |
| Defect register | "Regression test", "Status" and "Closure evidence" columns; closure rule (probes never close a defect); 18 open, 0 closed | — |
| Stories | A "Regression for" line in every story that fixes a defect | — |
| Matrix | 01 marked **PROVISIONAL** until D-28 + US-0109; FR-11 status IV → P; FR-46 and FR-64 notes; NFR-13 adds US-1302; new §8 "Not in R1" | — |

### Figures

| | v0.1 | v0.2 |
|---|---|---|
| R1 base / with contingency | 33.75 / ≈ 39 | **35.75 / ≈ 42.4** |
| R1 + R1.1 | 42.0 / ≈ 48 | 44.0 / ≈ 51.9 |
| Full SRS, staged (A) | 53.0 / ≈ 62 | 55.0 / ≈ 65.6 |
| Single release (B) | 56 / ≈ 64 | 57.5 / ≈ 68.5 |
| Sprints S1 / S2 / S3 / S4 | 5.5 / 6.5 / 6.25 / 5.0 | 6.5 / 7.0 / 6.5 / 5.25 |

### Files changed

| File | Change |
|---|---|
| `00` | Header, defect register, assumptions, S1 blockers |
| `01` | PROVISIONAL header, FR-11/46/64 and NFR-13 rows, summary counts, new §8 |
| `02` | Rewritten to the v0.2 terminology and figures |
| `03` | Header, legend, D-01/02/27/28 notes, D-31–D-35, CR-01/02/13 notes, tracker with categories |
| `07` | Milestone names M4/M5 no longer say "MVP"; overview, contingency, day-20 line, sprint tables, M1/M2 durations, blockers, G-FL gate, lead times |
| `08` | US-0101, 0102, 0104–0108, 0201, 0202, 0301, 0503, 0703, 0801, 1201, 1301; new US-0109 and US-1302; epic index; reconciliation |
| `09` | Invariants and idempotency suites, lint gate, D-32 row, §12.1 closure rule, G-R1 item 3 |
| `11` | R-21–R-23, dependency register, S1 blockers, §5 and §6 rewritten |
| `README` | Version, review order, blockers |
| **New** | `13-final-review-and-decision-pack.md`, `CHANGELOG.md` |

**Not changed:** 04, 05, 06, 10, 12 and appendix A. No content in them was invalidated by this review.

## v0.1 — 2026-10-12 · Initial planning package

- Documents 00–12, README and Appendix A created from the Phase 0 audit and SRS v1.1 (as provided in session).
- Baseline test run: 15/15 pass.
- Defects DEF-01 – DEF-18 recorded.
