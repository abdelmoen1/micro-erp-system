# Hisbah Smart Shop — SDLC Planning Package

> **v0.4 (2026-10-13):** the TL approved the Sprint 1 plan ([14](14-sprint-1-execution-plan.md)) and the S1 decisions (recorded in [03](03-decision-log-and-change-requests.md) Part 3). Sprint 1 implementation is in progress on branch `sprint-1`. D-28 (SRS PDF) blocks only US-0109.

> # PROPOSED — AWAITING TEAM LEADER APPROVAL
> Package version **0.2** (2026-10-13; see [CHANGELOG](CHANGELOG.md)) · Code baseline `main @ 71c9d17` · Requirements baseline **SRS v1.1, not yet pinned in the repository** (D-28); the traceability matrix is PROVISIONAL
>
> Nothing in this folder is approved. Milestones, sprints, user stories, scope changes (CR-xx) and architectural decisions (D-xx) remain **proposals** until the Team Leader records a decision in [03 Part 3](03-decision-log-and-change-requests.md#part-3--decision-status-tracker).
> No application code, migration, dependency or SRS file was changed to produce this package.

## Documents

| # | Document | Purpose | Status |
|---|---|---|---|
| **13** | [**Final review and decision pack**](13-final-review-and-decision-pack.md) (Arabic) | **Start here.** Pre-Sprint-1 review: arithmetic audit, SRS items not in R1, defect closure, Flutter readiness, SRS pinning, classified decision list (A safe / B business / C evidence), revised executive summary | **Needs TL decisions** |
| **15** | [**Compressed delivery plan**](15-compressed-delivery-plan.md) | S2 close → S10 in 10 days (20–31 Oct 2026): calendar, tasks per role (BE / FE / FL / UX), weighted goods spec, UX delivery schedule, TL actions, pilot plan, cut-lines | **Approved direction (2026-10-19)** |
| **14** | [**Sprint 1 execution plan**](14-sprint-1-execution-plan.md) | Proposed Sprint 1 re-scope: backend foundations + Flutter app from scratch + mobile UI/UX, task tables, design reviews DR-1/DR-2, React kept working on `/api/v1`, 12.75 dd estimate, approval checklist | **Needs TL approval** |
| — | [CHANGELOG](CHANGELOG.md) | v0.1 → v0.2 corrections and additions | — |
| 00 | [Project baseline](00-project-baseline.md) | Verified current state: repos, toolchain, **test run (15/15 pass)**, defects DEF-01–18 with closure status (**18 open**), assumptions | Proposed |
| 01 | [Requirements gap analysis](01-requirements-gap-analysis.md) | Traceability matrix for all FR/NFR/BR/UC/AC; §8 lists what is not in R1 (deferred vs reduced) | Proposed · **PROVISIONAL** until US-0109 |
| 02 | [MVP scope and release strategy](02-mvp-scope-and-release-strategy.md) | R1 = first launchable increment (not the SRS MVP); Scenario A vs B; launchability (D-35); day-20 checkpoint | Proposed |
| 03 | [Decision log and change requests](03-decision-log-and-change-requests.md) | D-01 – D-35 with options and recommendations; CR-01 – CR-14; tracker with categories A/B/C | **Needs TL decisions** |
| 04 | [System architecture](04-system-architecture.md) | Existing vs proposed architecture; integrity designs (idempotency, sale, void, payments, returns, AI drafts, offline sync, secure link); Mermaid diagrams | Proposed |
| 05 | [Data model and API contracts](05-data-model-and-api-contracts.md) | ERD changes, integrity rules, `/api/v1` conventions, endpoint catalogue, idempotency/sync contract, AI tool contracts, authorization matrix | Proposed |
| 06 | [UI/UX and screen plan](06-ui-ux-and-screen-plan.md) | Information architecture, ranked screen inventory (SCR-M/SCR-W), flows, design system, wireframe specs, UI acceptance criteria, Figma workflow | Proposed |
| 07 | [Milestones and sprints](07-milestones-and-sprints.md) | M1–M10 / S1–S10, sprint contents by layer, dependency graph, critical path, progress format | Proposed |
| 08 | [User stories and technical tasks](08-user-stories-and-technical-tasks.md) | **Source of truth** for US-xxxx, acceptance criteria, tasks (T-), tests (TC-), estimates | Proposed |
| 09 | [Testing and Definition of Done](09-testing-and-definition-of-done.md) | Test strategy per layer, safety rules, DoD, release gates G-R1/G-R1.1/G-R2, regression pack | Proposed |
| 10 | [AI-assisted SDLC workflow](10-ai-assisted-sdlc-workflow.md) | How AI is used per phase, bounded prompt template, mandatory human review, security checklist | Proposed |
| 11 | [Risk register and feasibility](11-risk-register-and-feasibility.md) | R-01 – R-23, dependencies, trade-offs, story-derived effort breakdown, differentiated contingency, 20-day feasibility analysis | Proposed |
| 12 | [Release and deployment plan](12-release-and-deployment-plan.md) | Environments, configuration checklist, safe migrations, smoke tests, rollback, backups | Proposed |
| A | [Appendix A: Phase 0 audit report](appendix-a-phase0-audit-report.md) | Verbatim copy of the read-only audit, with superseded statements marked | Reference |

## Recommended Review Order

0. **13** (final review and decision pack) → **14** (Sprint 1 execution plan) and the **CHANGELOG**.
1. **00** (what is true today) → **02** (what to build first) → **03** (decide the S1 blockers).
2. **01** (confirm nothing from the SRS is lost) → **07** (sequence) → **11** (feasibility and risks).
3. **04 / 05** (architecture and contracts) → **06** (screens) → **08** (stories).
4. **09 / 10 / 12** (quality, AI workflow, release).

## ID Conventions

| Prefix | Meaning | Defined in |
|---|---|---|
| FR / NFR / BR / UC / AC | SRS v1.1 identifiers (unchanged) | SRS v1.1 |
| DEF-nn | Defect | 00 §5 |
| D-nn | Decision | 03 |
| CR-nn | Proposed SRS change request | 03 |
| A-nn | Planning assumption | 00 §7 |
| R / R1.1 / R2 (release) | Release | 02 |
| M1–M10 / S1–S10 | Milestone / sprint (1:1) | 07 |
| E01–E15 | Epic | 08 |
| US-eenn | User story (`ee` = epic number) | 08 |
| T-eenn-n | Technical task | 08 |
| TC-eenn-nn | Test case | 08 (strategy in 09) |
| SCR-M-nn / SCR-W-nn | Mobile / web screen | 06 |
| UI-AC-nn | UI acceptance criterion | 06 §7 |
| R-nn | Risk | 11 |
| G-S / G-R1 / G-R1.1 / G-R2 | Quality gates | 09 |

## How the Documents Link

```
SRS ID ──(01 matrix)──► Story US-xxxx ──(08)──► Tasks T-… + Tests TC-…
   │                         │                              │
   │                         ├──(07)──► Sprint / Milestone ──┴──(09)──► DoD & Release gate
   │                         └──(06)──► Screen SCR-…  ──► UI-AC-…
   └──(03)──► Decision D-xx / Change request CR-xx (when the SRS is ambiguous or staged)
```

## Before Implementation Can Start

1. The TL records decisions for the **S1 blockers (corrected in v0.2)**: D-04, D-09, D-12/CR-10, D-13, D-22, D-23/CR-14, D-24, and **D-28** (commit SRS v1.1 to the repo). D-01 and D-02 are decided before S5–S6 planning (D-02 with D-35 by the end of S4).
2. The TL accepts or rejects **CR-01** (release staging) and the CRs needed for S1–S3 (CR-03, CR-04, CR-05, CR-09, CR-10, CR-14).
3. The TL starts external lead-time items: Flutter SDK + two Android phones (US-1302 in S1), OTP provider account, hosting choice, AI provider account, and a pilot-shop connectivity check (D-35).
4. The TL reviews the stale worktree `micro-erp-system.worktrees/backend-features-testing` (R-17).
5. Once approved, change the package status from PROPOSED to APPROVED (with a date) and move or copy it from `docs/sdlc/proposed/` to `docs/sdlc/approved/`.
