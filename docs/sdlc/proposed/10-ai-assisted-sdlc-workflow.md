# 10 — AI-Assisted SDLC Workflow

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL**

## 0. The Governing Rule

> **AI-generated work is not complete until the relevant tests, build checks and acceptance criteria have been verified, and a human has reviewed it.**

AI accelerates drafting. It does not replace verification. No prompt may modify the whole system at once. Every AI-assisted change is a **small, traceable unit**: one story, or one technical task (`T-xxxx-n`) from [08](08-user-stories-and-technical-tasks.md).

---

## 1. Tools: What Is Actually Available

| Tool | Status in this workspace | Use it for | Do not use it for |
|---|---|---|---|
| **Claude Code** (VS Code extension, CLI) | **Verified available** (this planning session) | Requirements analysis, planning, code reading, bounded implementation, test writing, running tests and builds, reviews, documentation | Unbounded "build feature X everywhere" requests; changes without a story ID |
| Claude Code subagents / code-review commands | Available in Claude Code | Independent second-pass review of a finished diff | Replacing the developer's own line-by-line read |
| Figma / design-generation tools | **Not connected or verified** | First-draft frames (see [06 §9](06-ui-ux-and-screen-plan.md#9-proposed-figma-screen-generation-workflow)) | Final designs without checking against the component library |
| GitHub Actions | Not configured yet (US-0108) | Objective checks: tests, lint, build | — |
| External AI provider for the product (Hisbah assistant) | Not selected (D-15) | The in-product assistant only | Development tasks (keep the product key separate from development tools) |
| Flutter tooling | **Not installed** (A-05) | — | — |

> Do not assume any other tool, MCP server or integration exists until it is verified in the session that uses it.

---

## 2. AI Use by SDLC Phase

### 2.1 Requirements and planning

| Activity | AI does | Human verifies |
|---|---|---|
| SRS analysis and ambiguity detection | Extracts IDs and finds contradictions (as in [03](03-decision-log-and-change-requests.md)) | The TL decides each D-xx and CR-xx |
| Traceability | Maintains [01](01-requirements-gap-analysis.md) when stories change | Spot-checks 10% of rows per sprint |
| Acceptance criteria | Drafts Given/When/Then statements | Each AC is testable and matches the SRS wording |
| Story decomposition and estimation | Proposes splits and estimates | The TL compares actuals to estimates every sprint and recalibrates |
| Risk analysis | Proposes risks and mitigations | The TL owns the register ([11](11-risk-register-and-feasibility.md)) |

### 2.2 UX/UI

| Activity | AI does | Human verifies |
|---|---|---|
| User-flow analysis | Proposes flows from UCs | The flow covers every exception listed in the UC |
| Wireframe and component planning | Drafts frame descriptions and states | Frames use the library; checked against UI-AC-xx |
| Consistency review | Compares screens against tokens and components | A visual check on a real device or browser |
| Accessibility review | Checks labels, contrast and focus order from code | Keyboard-only run; screen-reader spot check |
| Screen-to-requirement mapping | Keeps [06 §3](06-ui-ux-and-screen-plan.md#3-screen-inventory) in sync | Each screen has a story |

### 2.3 Architecture

| Activity | AI does | Human verifies |
|---|---|---|
| Architecture proposals and ADR drafting | Drafts ADR-001 to ADR-008 ([04 §7](04-system-architecture.md#7-architecture-decision-records-adr-to-draft-at-approval)) | The TL approves each ADR |
| Data-model review | Checks migrations against [05 §1.3](05-data-model-and-api-contracts.md#13-integrity-rules) integrity rules | Migration test + backfill assertion |
| API contract generation | Writes and updates `openapi.yaml` from code or spec | Contract tests pass; both clients match |
| Failure-mode analysis | "What if this fails between step X and Y?" for each service | A fault-injection test exists |
| Security review | Runs the §5 checklist on the diff | The developer confirms each item |

### 2.4 Implementation

Use the **bounded prompt template** in §3. Rules:

1. **One story or task per session.** Start each session by reading the story in [08](08-user-stories-and-technical-tasks.md) and the files listed in the prompt.
2. **Reuse first.** The prompt names the existing patterns to reuse, for example `BelongsToStore`, `DB::transaction` + `lockForUpdate`, `AuthService` hashed tokens, and the reversal recompute pattern.
3. **Change boundaries.** The prompt lists **allowed files and directories**. Any change outside them must be explained and approved before it is made.
4. **Tests come with the code.** The AI writes the TC tests in the same session and **runs** them. A red suite means not done.
5. **No dependency changes** without the decision ID that approved them (D-20, D-21).
6. **No migrations edited.** New migrations only.
7. **Commits:** small, with a message `US-xxxx: <what>`, and the SRS IDs in the body.

### 2.5 Quality assurance

| Activity | AI does | Human verifies |
|---|---|---|
| Test-case generation | Writes TCs from the ACs | Each AC maps to at least one test; assertions check outcomes, not only status codes |
| Test execution | Runs PHPUnit (sqlite + MySQL), lint, build, `flutter analyze/test` | Reads the output; never accepts "tests should pass" without a run |
| Failure analysis | Explains failures; proposes a minimal fix | The fix addresses the root cause, not the test |
| Regression | Runs the §10 regression pack of [09](09-testing-and-definition-of-done.md) | Pack results are recorded per release |
| Security and authorization review | Runs the §5 checklist; tries cross-store and role probes | Probe results recorded |
| Cross-platform UI verification | Lists screens to check | Manual check in a browser and on the device |
| Manual acceptance | Generates the UAT script | The TL executes and signs |

### 2.6 Release and maintenance

| Activity | AI does | Human verifies |
|---|---|---|
| Deployment checklist and environment checks | Generates and validates the configuration (no secret values) | The TL performs production steps |
| Migration safeguards | Generates `--pretend` SQL output for review | The TL confirms a backup was taken before migrating |
| Smoke tests | Runs the scripted smoke test against staging | Results recorded |
| Release notes and known limitations | Drafts them from merged stories | The TL edits and approves |
| Post-release defects | Triages, reproduces with a failing test, proposes a fix | Priority assigned by the TL (P0–P3) |

---

## 3. Bounded Implementation Prompt Template

```text
STORY: US-0501 — Product-linked cash sale with stock deduction
SRS: FR-23, FR-24, FR-28, NFR-10, UC-10 · Decisions: D-07, D-08, D-27 (approved on <date>)

READ FIRST:
  docs/sdlc/proposed/08-user-stories-and-technical-tasks.md (US-0501 section)
  docs/sdlc/proposed/05-data-model-and-api-contracts.md (§1.1 invoices, §3.1)
  docs/sdlc/proposed/04-system-architecture.md (§3.2)
  backend/app/Http/Controllers/Api/InvoiceController.php (existing logic to replace)
  backend/app/Traits/BelongsToStore.php, backend/app/Services/* (patterns to reuse)

ALLOWED CHANGES:
  backend/app/Services/SaleService.php (new)
  backend/app/Http/Controllers/Api/SaleController.php (new)
  backend/app/Http/Requests/StoreSaleRequest.php (new)
  backend/app/Http/Resources/SaleResource.php (new)
  backend/database/migrations/<new timestamp>_*.php (new files only)
  backend/routes/api.php (sales routes only)
  backend/tests/Feature/SalesFeatureTest.php (new); existing tests only where AC requires (list them)

NOT ALLOWED: existing migrations, composer/package files, unrelated controllers, frontend/, any secret.

REUSE: DB::transaction + lockForUpdate (see PaymentController::store), Money helper (US-0102),
       IdempotencyService (US-0101), AuditService (US-0103), BelongsToStore.

ACCEPTANCE CRITERIA: (paste AC 1–6 from the story)
TESTS TO WRITE AND RUN: TC-0501-01 … TC-0501-06
VERIFY: php vendor/bin/phpunit (sqlite) AND -c phpunit.mysql.xml — both green.

REPORT BACK:
  - files changed (with reason)
  - test command output summary
  - any deviation from the story or contract, and why
  - open questions (do not guess business rules)
```

---

## 4. Human Review: When It Is Mandatory

Human review is **always** required, and AI output must never be merged on its own, for:

1. Any change to money arithmetic, debt/payment/stock services, or invoice state transitions.
2. Authorization policies, middleware, store-scoping, token or OTP handling.
3. Migrations and backfills, especially anything that touches existing rows.
4. AI tool definitions, system prompts, and the draft/confirm flow.
5. Public endpoints (secure link) and anything returning customer data.
6. Deployment configuration and environment variables.
7. Any change that makes an existing test assert **different** behaviour.

---

## 5. Security and Financial Review Checklist (per PR)

- [ ] Every new query on a store-owned table is scoped by the authenticated `store_id`, and route binding uses `BelongsToStore`.
- [ ] Every new endpoint has a policy check **and** a cross-store 404 test.
- [ ] Financial writes: idempotency key required; a single DB transaction; consistent lock order; arithmetic via `Money`.
- [ ] Derived balances are **recomputed from facts**, not incremented blindly.
- [ ] No hard delete of financial history; corrections create new records (void, return, reversal) plus an audit entry.
- [ ] Validation: `decimal:0,2` for money, integer quantities ≥ 1, store-scoped `exists` rules; `store_id` is never accepted from input.
- [ ] Error responses leak no stack traces, SQL or other stores' data.
- [ ] No secrets in code, tests, logs, fixtures or documentation.
- [ ] Public or AI-facing output contains only the fields listed in [05](05-data-model-and-api-contracts.md).
- [ ] Rate limits on new public or auth endpoints.
- [ ] Audit log entry for critical actions ([04 §3.7](04-system-architecture.md#37-audit-trail--us-0103)).

---

## 6. Known AI Failure Modes to Watch For

| Failure mode | Countermeasure |
|---|---|
| Inventing business rules to fill gaps | The prompt says "do not guess business rules"; open questions go to the decision log |
| Writing tests that assert the implementation instead of the requirement | Tests are derived from the ACs; reviewers compare them against the story |
| Silently changing unrelated files | The allowed-files list plus a `git diff --stat` review |
| Claiming tests pass without running them | Test output is required in the report |
| Over-engineering (extra abstractions, packages) | "Reuse first" plus the dependency-approval rule |
| Weakening validation to make tests pass | Reviewer checks each relaxed rule against the SRS |
| Flutter code copied from outdated APIs | `flutter analyze` gate; pinned package versions; check against the package docs |
