# 14 — Sprint 1 Execution Plan

> **Status: PROPOSED — AWAITING TEAM LEADER APPROVAL** · Package v0.3 rev. 1 · 2026-10-13
>
> **rev. 1:**
> - React compatibility with `/api/v1` added to S1 (T-0106-5).
> - Phase-by-phase effort for the split UI/UX tasks made explicit; DR-1 and DR-2 timings recomputed.
> - The visual-direction work is no longer a cut option.
> - S1 = **12.75 dd** base.
>
> - This is a planning document only. No Flutter project, package, migration or code has been created or changed. **No story is started or completed.**
> - It **re-scopes Sprint 1** of [07](07-milestones-and-sprints.md) to cover three connected workstreams: backend, the Flutter app created from scratch, and mobile UI/UX.
> - New IDs introduced here are listed in §12 and are **to be merged into 03 / 07 / 08 only after approval**. Until then, 07 and 08 still describe the v0.2 Sprint 1.
> - **Repository state at writing (read-only check):**
>   - `main @ 71c9d17`; only `docs/` is untracked.
>   - No decision is recorded in 03.
>   - No `docs/srs/` (D-28 not done).
>   - No Flutter SDK and no Flutter project.
>   - The backend is unchanged since the baseline: auth at `/api/login|logout|me`; 78 `/api/` path references in the tests; `bootstrap/app.php` `withExceptions` is empty.
>   - React `api.js` hard-codes the base URL `/api`.
>   - The GitHub remote exists; whether Actions is enabled is unverified.

---

## 1. Sprint Title, Goal and Definition of Success

**Title:** S1 — *Trustworthy core + mobile foundation*

**Goal:**

1. Make the existing financial API safe, exact and correctly authorized.
2. Stand up a real Flutter app that signs in against that API on real Android phones.
3. Approve the mobile design foundation and the first critical flow (quick sale) **before** any visual implementation.

**Sprint 1 succeeds when all of the following are true:**

| # | Success criterion | Evidence |
|---|---|---|
| S-1 | DEF-02, 04, 07, 08, 09, **12**, 14, 15 (boot guard), 16 are **closed** by in-repo regression tests, green on sqlite **and** MySQL (DEF-12 by the React lint job, T-0106-5). DEF-18 is closed if D-28 is done. DEF-05 is **contained** (employees can no longer edit invoices; full fix in S2). **The existing React web login keeps working against `/api/v1`.** | CI run; defect register "Closure evidence"; TC-0106-05 smoke record |
| S-2 | The Flutter app runs on **two real Android phones** in Arabic RTL. Login, session restore and logout work against `/api/v1`. Every auth error state is handled. The integration test passes on a phone. | `integration_test` output; release APK installed on both phones |
| S-3 | Design reviews **DR-1** (structure and flows) and **DR-2** (visual direction and design system) are approved by the TL. | Signed DR notes in `docs/design/reviews/` |
| S-4 | The barcode camera spike report and the pace factor **k** are recorded, and gate **G-FL** is decided. | `docs/mobile/spikes.md`; S1 status note |

---

## 2. Scope

### 2.1 In scope

| Workstream | Stories (existing IDs reused; **new** marked) | dd |
|---|---|---|
| A — Backend (+ React compatibility) | US-0106 (incl. **T-0106-5** React → `/api/v1`), US-0108, US-0101, US-0102, US-0103, US-0104, US-0105, US-0107, US-0109 | 5.75 |
| B — Flutter | US-1302, **US-1303**, **US-1304**, US-0205 *(moved from S5)*, **US-1305** *(split from US-1301)*, **US-1306** | 4.0 |
| C — Mobile UI/UX | **US-1505**, US-1501 *(re-scoped mobile-first)*, **US-1506**, **US-1507**, US-1502 *(moved from S2)*, review revisions | 2.5 |
| Cross-cutting | Sprint regression, demo, status note, G-FL decision | 0.5 |
| **Total** | | **12.75** |

### 2.2 Out of scope (and why)

| Item | Where it goes | Reason |
|---|---|---|
| Products / catalog API, so barcode → `/products/lookup` integration | S2 (US-0401; US-1301 remainder) | The product model does not exist yet |
| POS, checkout, customers, payments screens in Flutter | S5 | Need the S2/S3 APIs and US-1508 hi-fi designs |
| OTP (US-0203) | S6 | Provider undecided (D-14); mobile does not register stores. Optional foundation add-on: **D-38**, recommended **no** |
| Remaining React work (US-0202 auth context / logout / header; US-0201 register wiring; US-1201 shell) | S3 | **Not** the `/api/v1` switch. The base URL change and the one-character DEF-12 fix are done in S1 (T-0106-5), so the web never points at a removed path. |
| Hi-fi designs for customers, payments, products, home, and POS hi-fi | S4 (**new US-1508**) | S1 validates structure and the POS flow in low-fi; hi-fi follows the approved direction |
| Offline, AI, secure link | R1.1 / R2 | Unchanged roadmap |

---

## 3. Workstream A — Backend

**Order:** US-0106 → US-0108 → US-0101 → US-0102 → US-0103 → US-0104 → US-0105 → US-0107 → US-0109.

US-0108 comes second so that every later story is verified on MySQL from the start. The full acceptance criteria are in [08](08-user-stories-and-technical-tasks.md) and are unchanged.

| ID | Pri | Reuse | Required change | API / DB impact | Acceptance (summary) | Tests | Deps / blocked by | dd |
|---|---|---|---|---|---|---|---|---|
| US-0106 API v1 + error envelope | Must | Route groups in `routes/api.php` | `v1` prefix; exception rendering in `bootstrap/app.php` (`withExceptions`); remove the `catch (\Exception)` swallow in `InvoiceController::store`; correlation ID; **`docs/api/auth.http` + envelope code list = auth contract freeze for mobile** | All paths → `/api/v1`; 78 test path references updated; React base URL stale until S3 | v1 routes serve; old prefix 404; envelope shape; 500 logged with correlation ID | TC-0106-01–03 | D-22 | 0.5 |
| **T-0106-5** React compatibility with `/api/v1` (new task under US-0106; done in the **same change set** as the route move) | Must | Existing `frontend/src/services/api.js` and its `loginUser` call | One file only: the base URL becomes `import.meta.env.VITE_API_URL` with default `http://127.0.0.1:8000/api/v1`, plus the one-character DEF-12 fix (`json.stringify` → `JSON.stringify`); `frontend/.env.example` documents `VITE_API_URL`; a React job (`npm ci`, `oxlint -D no-undef`, `vite build`) added to the US-0108 CI workflow. No other React change: register wiring, auth context and the shell stay in S3. | Web calls `/api/v1/*`; no backend change | Web login from the browser reaches `/dashboard` against the local `/api/v1` with the token stored; no console error; lint (`no-undef`) and build green in CI | **TC-0106-04** CI: `oxlint -D no-undef` + `vite build` · **TC-0106-05** manual smoke: browser login against `/api/v1`, Network tab shows `/api/v1/login` → 200, lands on `/dashboard` | US-0106, US-0108 (CI) | 0.25 |
| US-0108 MySQL parity, CI, isolation sweep | Must | XAMPP MySQL (present); `phpunit.xml` | `phpunit.mysql.xml`; `.env.testing` (no secrets); `_test` DB-name guard in `TestCase`; `.github/workflows/ci.yml` (sqlite + MySQL jobs); route sweep test | None | Both suites green in CI; foreign IDs → 404 on every model route; guard aborts on a non-test DB | TC-0108-01–03 | D-24; **GitHub Actions enabled (TL to verify; local MySQL fallback)** | 0.5 |
| US-0101 Duplicate-safe financial writes | Must · P0 | `DB::transaction` + `lockForUpdate` in `PaymentController::store`, `CustomerDebtController::payAll` | `idempotency_keys` migration; `EnsureIdempotency` middleware; `IdempotencyService`; applied to payments, pay-all, opening debt, single + group reversal, legacy invoice create | New table; `Idempotency-Key` required (428 missing, 409 reuse) | Replay = one record + identical response; data-provider replay over every financial endpoint | TC-0101-01–07 | US-0106, D-04 | 1.5 |
| US-0102 Exact money | Must · P1 | Recompute pattern in `PaymentController::is_reverse` / `reverseGroup` | `App\Support\Money` (bcmath, verified installed); `decimal:0,2` in money FormRequests; resources serialize money as strings | Money JSON number → string; `meta.currency = "ILS"` | 59.999 → 422; 0.10 + 0.20 exact; MySQL exactness | TC-0102-01–04 | D-09 | 0.75 |
| US-0103 Audit log | Must · P1 | — | `audit_logs` + `AuditService`; wired into reversals, role change, invitation, opening-debt create/update | New table (append-only) | Actor and timestamp on critical actions; rollback leaves no audit row; no mutation route | TC-0103-01–04 | — | 0.75 |
| US-0104 Auth hardening | Must · P1 | Laravel RateLimiter; `config/sanctum.php` | Throttle `/login` and `/register` (5/min per email + IP); token expiration 30 days; production debug boot guard (in the currently empty `AppServiceProvider::boot`) | 429 with `Retry-After`; 401 on expiry | 6th attempt → 429; expired token → 401; guard warns | TC-0104-01–03 | — | 0.25 |
| US-0105 Role matrix + deactivation | Must · P1 | `UserPolicy`, `User::hasRole` | Policies replace inline `abort_unless` checks; `UpdateUserRoleRequest` cannot assign `owner`; `users.status`; `POST /users/{id}/deactivate` replaces `DELETE`; active-user check at login and in middleware; token revoke; **employee blocked from invoice update (DEF-05 containment)** | Migration; `DELETE /users/{id}` removed; 403 `USER_INACTIVE` | Matrix test 100%; owner promotion rejected; deactivated user blocked; attribution intact | TC-0105-01–05 | US-0103; D-12 / CR-10 (+ employee pay-all question); D-13 | 0.75 |
| US-0107 Store timezone | Must | `DashboardService::periodBounds` | `stores.timezone` (default per D-23); `BusinessClock` helper | New column | A late-evening sale counts as "today"; week and month boundaries in the store timezone | TC-0107-01–02 | D-23 / CR-14 | 0.25 |
| US-0109 SRS baseline verification | Must | — | SHA-256 check + ID diff vs 01 | Docs only | Checksum matches; zero unexplained ID differences; 01 header → VERIFIED | TC-0109-01–02 | **Blocked by D-28** (TL commits the PDF) and a PDF text tool | 0.25 |
| **Backend total (incl. T-0106-5)** | | | | | | | | **5.75** |

**Why update React instead of keeping the old `/api` paths temporarily:**

- **The change is one file**, `api.js`. The same file already needs the DEF-12 fix.
- **Keeping both prefixes would create two live contracts:**
  - every hardening story (idempotency, roles, throttling) would have to be verified on both;
  - TC-0106-01 ("old prefix → 404") would have to be dropped;
  - a later removal step would be needed, which is a second breaking change.
- **Risk is lower with a single prefix.** The React change is verified by an automated lint/build job plus a recorded browser smoke test.

**Ready immediately** once D-04, D-09, D-12, D-13, D-22, D-23 and D-24 are approved: every story except US-0109.

**Partially blocked:** CI in US-0108 if Actions is unavailable. The local MySQL run still satisfies the DoD until CI exists.

---

## 4. Workstream B — Flutter From Scratch

### 4.1 Stack evaluation (D-20 — provisional adoption, validated at gate G-FL)

| Concern | Choice | Why it fits Hisbah | Considered and not chosen |
|---|---|---|---|
| State management | `flutter_riverpod`, **without code generation** | Testable dependency injection. The session state is readable by the router guard and the HTTP interceptor without `BuildContext`. Widely documented, which helps AI-assisted work. | Provider (weak structure for async session and errors); Bloc (verbose for a solo developer); `riverpod_generator` / `build_runner` (extra tooling for a first Flutter project) |
| Routing | `go_router` | Redirect guard on auth state; `ShellRoute` for the bottom navigation; deep links later (e.g., a sale receipt) | auto_route (code generation); raw Navigator 2.0 (complexity) |
| HTTP | `dio` | Interceptors for the bearer token, 401 handling and `Idempotency-Key`; timeouts; typed errors | `http` + hand-written wrapper (acceptable fallback, more code) |
| Token storage | `flutter_secure_storage` | Android Keystore-backed storage for the Sanctum token | `shared_preferences` (not secure) |
| Localization / RTL | SDK `flutter_localizations` + `gen-l10n` | Arabic default; layout direction from locale; no third-party package | — |
| Font | **Bundled font asset** (UI-D2) | Deterministic Arabic rendering; works offline later (R2) | `google_fonts` (runtime download) |
| Barcode scanning | **Not chosen yet.** At most two maintained camera plugins are compared in US-1305 | Evidence before commitment (D-31) | — |
| Not added in S1 | Hive / local DB (R2); freezed / json_serializable (few DTOs, hand-written); get_it (Riverpod covers DI); mocking libraries (use fakes) | — | — |

**Supporting choices:**

| Topic | Choice |
|---|---|
| Configuration | `--dart-define-from-file=env/dev.json` with `API_BASE_URL`. `env/*.json` with real hosts is git-ignored; `env/example.json` is committed. No native flavors in S1. |
| Project location — **D-36** | Monorepo folder `mobile/` at the repo root, beside `backend/` and `frontend/`. One CI, one contract folder, one history for a solo developer. |
| Android applicationId — **D-37** | The TL chooses (e.g., `com.hisbah.shop`). It is very costly to change after the first Play release, so it is decided before US-1303. |
| Versions | Pinned at creation via `pubspec.lock`; a maintenance note per package is recorded in `docs/mobile/environment.md` |

### 4.2 Flutter tasks

| ID | Pri | Deliverables | Acceptance criteria | Tests | Deps | dd |
|---|---|---|---|---|---|---|
| US-1302 Environment + devices (SP-01) | Must | Flutter SDK, Android Studio, licences; USB debugging on the reference **and** low-end phones; LAN access to Laravel (`php artisan serve --host=0.0.0.0`, Windows firewall rule, **debug-only** cleartext configuration); `docs/mobile/environment.md` | `flutter doctor -v` green; debug **and** release APK run on both phones; a phone request to the local API returns 200 | TC-1302-01–03 | Two phones (TL); downloads started on day 1 in the background | **0.75** (v0.2: 0.5) |
| **US-1303** Project foundation | Must | `mobile/` project; feature-first folders (`lib/core/`, `lib/features/auth/`…); `flutter_lints`; env files; `go_router` shell with the bottom-nav skeleton from US-1505; Riverpod root scope; theme wired to US-1501 tokens (**neutral until DR-2**); Arabic locale + RTL; shared loading, empty and error widgets; `mobile/README.md` (how to run) | App boots in Arabic RTL on both phones; navigation matches the approved DR-1 map; `flutter analyze` reports no issues | TC-1303-01 widget smoke; TC-1303-02 directionality RTL; TC-1303-03 analyze clean | US-1302, US-1505 (DR-1), D-20, D-36, D-37 | 1.0 |
| **US-1304** API client foundation | Must | `ApiClient` (dio): base URL from env, bearer header, timeouts; maps the v1 error envelope to typed failures (401, 403 `USER_INACTIVE`, 422 field errors, 428 / 409 idempotency, 429 + `Retry-After`, 5xx with `correlation_id`, network error); persistent `IdempotencyKeyStore` (SP-03) | Every envelope code in the frozen contract maps to a typed failure; a key created before an app kill is reused after restart | TC-1304-01 error mapping (fake adapter); TC-1304-02 key persistence | US-0106 contract freeze, US-1303 | 0.5 |
| US-0205 Mobile session (moved from S5) | Must | Login screen (functional first; visual styling only after DR-2); token in secure storage; session restore on launch; logout with server revoke; router redirect guard; screen states: invalid credentials, field validation, throttled (countdown from `Retry-After`), inactive account, session expired, network error | The AC of US-0205 in 08, plus every state above, matches the real API responses | TC-0205-01 (08) + widget tests for each state | US-1304; US-0104; US-0105; US-1507 (DR-2) for visuals | **0.75** (v0.2: 0.5) |
| **US-1305** Barcode camera spike (SP-02) | Must | Compare ≤ 2 maintained camera plugins (maintenance activity, licence, minSdk); p50/p90 scan-to-result on 20 real codes × 2 phones, including glossy, curved, damaged and low-light labels; document continuous-detection behaviour of the same code; `docs/mobile/spikes.md` | Report delivered with a plugin recommendation and evidence for **D-31** (repeat-scan rule). **No backend call** (the lookup API comes in S2). | TC-1305-01 spike report | US-1302 | 0.5 |
| **US-1306** Mobile ↔ Laravel integration + Flutter CI | Must | `integration_test` on a real phone against local `/api/v1`; `flutter analyze` + `flutter test` job added to CI | All six scenarios pass on the reference phone | TC-1306-01 login OK · 02 wrong password · 03 throttled 429 · 04 deactivated 403 · 05 logout then next call 401 · 06 session restore after app restart | US-0205, US-0104, US-0105, US-0108 | 0.5 |
| **Flutter total** | | | | | | **4.0** |

### 4.3 Pace calibration and gate G-FL (moved from S2 to S1)

- **SP-04:** the pace factor **k = actual dd ÷ estimated dd** is measured on US-1303, US-1304 and US-0205. These are real deliverables, which replaces the separate search screen proposed in v0.2 (there is no product API in S1).
- **G-FL at the end of S1:**
  - If US-1302 or US-1305 fails, or **k > 1.3**, then S5 is re-estimated as 6.0 × k.
  - The TL then decides: re-plan, add a Flutter contributor, or reduce the mobile scope.
  - If k ≤ 1.0, the R1 Flutter contingency drops from 30% to 15%.
- **US-1301 remainder (S2, 0.25 dd):** scan → `/products/lookup` integration once US-0401 exists. US-1301's other S2 tasks move into US-1303, US-1304, US-1305 and US-1306 (§12).

---

## 5. Workstream C — Mobile UI/UX

### 5.1 Tooling limitation and alternative

**Limitation:** no Figma integration is connected or verified in this workspace, and no design file exists. **No mockup has been created.**

**Proposed approach (decision UI-D4):**

| Artifact | Format |
|---|---|
| Low-fi wireframes | Excalidraw sources + PNG exports in `docs/design/wireframes/` |
| Design tokens | `docs/design/tokens.json` + `docs/design/design-system.md` |
| Visual-direction and hi-fi samples | Static HTML/CSS mockups at 360 × 800, `dir="rtl"`, in `docs/design/mockups/`. They can be opened on the phones' browsers to judge real Arabic rendering. Each is labelled "PROPOSAL". |
| Alternative | Figma or Penpot, if the TL provides an account. The same deliverables apply. |

### 5.2 Design principles for a production-quality shop interface

1. **Speed first:** the till is used hundreds of times a day.
   - One primary action per screen, in a sticky bottom bar within thumb reach.
   - No confirmation dialog when a summary screen already confirms.
2. **Money is the hero:**
   - Totals, prices, quantities and balances use the largest, tabular figures.
   - Labels are secondary.
3. **Meaning, not decoration:**
   - Colour is used only for state (paid, debt, partial, return, voided, low stock, pending).
   - Each state also has an icon and a text label.
4. **Different screens may look different.** They share tokens and components, not a single card template.
5. **Anti-patterns rejected at review:**
   - decorative gradients;
   - card-for-everything dashboards;
   - colour-only status;
   - tap targets under 48 dp;
   - two competing primary buttons;
   - placeholder-only form labels;
   - English-first layouts mirrored as an afterthought.

### 5.3 Information architecture and navigation (US-1505)

**Bottom navigation (5 tabs, from 06):** الرئيسية Home · **بيع POS (primary, visually emphasised)** · الزبائن Customers · المنتجات Products · المزيد More.

| Rule | Detail |
|---|---|
| Role-based landing (SRS §3.2 roles) | Employee → POS. Owner / Manager → Home. |
| Global elements | Offline banner (R1: "sales need internet"); session-expired interrupt that returns the user to the same place after re-login |
| More tab (R1) | Profile and logout. AI, returns and sync are added in later releases. |

### 5.4 Prioritised R1 mobile screen inventory

| Rank | Screen (06 IDs) | Why this rank | Designed in |
|---|---|---|---|
| 1 | SCR-M-02 POS cart, SCR-M-03 scanner | Highest frequency and money impact | S1 low-fi (US-1502); hi-fi S4 (US-1508) |
| 2 | SCR-M-04 checkout, SCR-M-05 customer picker, SCR-M-06 receipt | Cash / credit / partial separation is decided here | S1 low-fi (US-1502); hi-fi S4 |
| 3 | SCR-M-01 login + auth states + app shell | Implemented in S1 | **S1 low-fi + hi-fi** (US-1507) |
| 4 | SCR-M-07 customers, SCR-M-08 customer detail, SCR-M-09 record payment | Daily collections | S4 (US-1508) |
| 5 | SCR-M-10 home, SCR-M-11 products + low stock | Informational | S4 (US-1508) |

No screen outside 06's R1 inventory is added.

### 5.5 Primary flows

| Flow | Purpose in S1 |
|---|---|
| **F-1 Quick sale (first flow to design and validate):** scan → cart (repeat scan +1) → checkout (cash default; credit / partial variant) → receipt | Designed low-fi and tested as a clickable prototype with 2–3 shop staff (US-1502). Validates speed (≤ 4 taps after the last scan for walk-in cash) and the visual separation of cash / credit / partial before any POS code exists. |
| **F-0 Sign-in and session** | Implemented in S1 (US-0205), so it is designed first in hi-fi (US-1507) |

### 5.6 Design-system foundation (US-1501, re-scoped mobile-first)

| Area | Foundation defined in S1 |
|---|---|
| Typography | Arabic font chosen at DR-2 (UI-D2 candidates: IBM Plex Sans Arabic, Noto Sans Arabic); mobile type scale (body ≥ 16); money display style; tabular figures |
| Colour roles | action, surface, surface-raised, text-primary, text-secondary, border, focus. Semantic: **cash / paid**, **credit / debt** (deliberately distinct from "error"), **partial**, **return / refund**, **voided**, **low stock**, **pending / offline**, **error**. Roles first, palette second (palette from the chosen direction). AA contrast verified. |
| Spacing and size | 4-pt scale; touch targets ≥ 48 dp; primary bar 56 dp; list row heights for one-handed scanning |
| Components (behaviour + states) | MoneyText, QuantityStepper, StatusChip, ConfirmSummary sheet, ListRow with balance, TextField with inline validation, PrimaryBar, OfflineBanner, Empty / Error / Skeleton. States: default, pressed, focused, disabled, loading, success, error. |
| RTL rules | Mirrored layout. Directional icons are mirrored; non-directional ones (barcode, check, camera) are not. Numbers, money and phone numbers are rendered as isolated LTR runs inside RTL text. Western digits proposed (UI-D1). |
| Accessibility | Text scale 130% without clipping; screen-reader labels on icon buttons; visible focus |
| Feedback | Scan accepted: haptic + short sound + line highlight. Errors: inline, never only a toast. |

### 5.7 UX tasks

| ID | Pri | Deliverable | Acceptance criteria | Tests / evidence | Deps | dd |
|---|---|---|---|---|---|---|
| **US-1505** IA, navigation, R1 screen inventory | Must | Navigation map, role landing rule, ranked inventory (§5.4), a **state matrix** per S1 screen listing every real API response from the US-0106 contract | Approved at DR-1; every auth API response appears in the state matrix | TC-1505-01 DR-1 sign-off | US-0106 (contract list) | 0.25 |
| US-1502 POS & checkout flow (moved from S2) | Must | Low-fi SCR-M-02 – M-06, including cash / credit / partial / return separation cues; a clickable prototype of F-1; a hallway test with 2–3 shop staff and recorded findings | AC of US-1502 in 08 (the M-07 – M-11 part moves to US-1508). **The test may slip to S2** if participants are unavailable; the low-fi must not. | TC-1502-01 | US-1505 | 0.5 = **P1** low-fi 0.25 + **P4** prototype and test 0.25 |
| **US-1507** Auth and shell screens | Must | Low-fi, then hi-fi in the chosen direction: login, field validation, invalid credentials, throttled with countdown, inactive account, session expired, network error, shell with bottom navigation, offline banner | Every US-0205 state has a design; approved at DR-2 | TC-1507-01 DR-2 sign-off | US-1505, US-1506 (direction picked at DR-2 part 1) | 0.25 = **P1** low-fi 0.125 + **P2** hi-fi 0.125 |
| US-1501 Design-system foundation (re-scoped) | Must | `tokens.json`, `design-system.md`, component state sheet, RTL/bidi sample sheet, contrast report | AA contrast on all text pairs; every component has all its states; approved at DR-2 | TC-1501-01 contrast report; TC-1501-02 TL review | US-1505 | **0.75** (v0.2: 0.5) |
| **US-1506** Visual direction | Must | **Two** distinct directions applied to the same two screens (login and POS cart), with a written rationale for each against §5.2 | The TL selects one direction at DR-2 (or asks for a revision) | TC-1506-01 DR-2 decision recorded | US-1501 draft | 0.5 |
| Review revisions | — | Fixes after DR-1 and DR-2 | — | — | — | 0.25 = **P1** after DR-1 0.125 + **P2** after DR-2 0.125 |
| **UX total** | | | | | | **2.5** (P1 0.75 · P2 1.5 · P4 0.25) |

**The two visual directions (US-1506) and both design reviews are protected scope.** They are not cut under time pressure (see §10.4).

### 5.8 Design review checkpoints

| Checkpoint | When (≈ dd into S1) | Reviewed | Unblocks |
|---|---|---|---|
| **DR-1 — Structure** | Held at ≈ 2.625; approved after revisions by ≈ 2.75 | Navigation map, role landing, screen inventory, flows F-0 / F-1, low-fi SCR-M-01 – M-06, state matrix | US-1303 navigation skeleton |
| **DR-2 — Visual foundation**, one review in two touchpoints | **Part 1 — direction pick** at ≈ 7.0 (after US-1501 draft + US-1506). **Part 2 — sign-off** held at ≈ 7.125 (after US-1507 hi-fi in the chosen direction); approved after revisions by ≈ 7.25. | Part 1: the two directions on login + POS cart; the TL picks one. Part 2: design-system foundation, hi-fi auth and shell screens in the chosen direction, accessibility checks (contrast, 130% text, RTL/bidi sheet viewed on a phone). | **Any visual styling in Flutter.** Before DR-2 sign-off, Flutter screens may only use a neutral default theme for functional scaffolding. |
| DR-3 — Prototype findings (optional) | End of S1 | Hallway-test findings for F-1 | Feeds US-0401 (S2) and US-1508 (S4) |

Each review is recorded in `docs/design/reviews/DR-n.md` with **approve / revise** and the TL's notes. A "revise" outcome uses the 0.25 dd revision allowance; a second revision is re-planned.

---

## 6. How the Workstreams Connect

| From | To | Rule |
|---|---|---|
| US-0106 contract freeze (`docs/api/auth.http` + the envelope code list) | US-1304, US-0205, US-1505 state matrix | Flutter and the designs use the **real** v1 auth contract. No invented mock endpoints. Any later contract change updates the `.http` file, the Flutter mapping and the state matrix together. |
| US-0104 (429 + `Retry-After`, token expiry) | US-0205 states, US-1306 tests | The throttled and expired states are designed and implemented from real responses |
| US-0105 (`USER_INACTIVE`) | US-0205, US-1306 | Inactive-account state tested end to end |
| US-1505 → DR-1 | US-1303 | Navigation is built from the approved map |
| US-1501 + US-1506 + US-1507 → DR-2 | US-0205 visual styling | No visual implementation before approval |
| US-0106 (route move) | T-0106-5 (React base URL) | Same change set. The web is never left pointing at a removed path. |
| US-1302 | US-1303, US-1305 | Toolchain proven on both phones first |
| US-0108 | US-1306 CI | The Flutter job joins the same workflow |

**No mutual dependency** (single developer, so this means flexible ordering, not simultaneous work):

- US-1302 downloads (background);
- US-1305 (camera only);
- the UX tasks relative to the backend integrity stories (US-0101, US-0102, US-0103).

---

## 7. Execution Sequence (logical, 12.75 dd)

**P0 — before day 1 (no developer effort counted):**

- The TL records the S1 blocker decisions.
- Phones and cables are ready.
- Flutter SDK + Android Studio downloads are started.
- GitHub Actions is checked.
- 2–3 shop staff are scheduled for the prototype test.
- The SRS PDF is committed (D-28).

| Phase | Task (in order) | dd | Cumulative dd | Checkpoint |
|---|---|---|---|---|
| **P1 — Contracts and structure** | US-0106 (contract freeze) | 0.5 | 0.5 | |
| | T-0106-5 React → `/api/v1` | 0.25 | 0.75 | |
| | US-0108 (MySQL + CI) | 0.5 | 1.25 | |
| | US-1302 (setup; downloads already running) | 0.75 | 2.0 | |
| | US-1505 IA / inventory / state matrix | 0.25 | 2.25 | |
| | US-1502 **part 1**: low-fi POS flow | 0.25 | 2.5 | |
| | US-1507 **part 1**: low-fi auth / shell | 0.125 | 2.625 | **DR-1 held** |
| | Revisions after DR-1 | 0.125 | **2.75** | **DR-1 approved** |
| **P2 — Integrity and visual foundation** | US-0101 | 1.5 | 4.25 | |
| | US-0102 | 0.75 | 5.0 | |
| | US-0103 | 0.75 | 5.75 | |
| | US-1501 design-system foundation | 0.75 | 6.5 | |
| | US-1506 two visual directions | 0.5 | 7.0 | **DR-2 part 1: direction pick** |
| | US-1507 **part 2**: hi-fi auth / shell in the chosen direction | 0.125 | 7.125 | **DR-2 part 2 held** |
| | Revisions after DR-2 | 0.125 | **7.25** | **DR-2 approved** |
| **P3 — Auth hardening and app foundation** | US-0104 | 0.25 | 7.5 | |
| | US-0105 | 0.75 | 8.25 | |
| | US-0107 | 0.25 | 8.5 | |
| | US-1303 (navigation from DR-1, theme from DR-2) | 1.0 | 9.5 | |
| | US-1304 | 0.5 | **10.0** | |
| **P4 — Mobile session, spike, integration** | US-0205 (styled per DR-2) | 0.75 | 10.75 | |
| | US-1305 barcode spike | 0.5 | 11.25 | |
| | US-1306 integration + Flutter CI | 0.5 | 11.75 | |
| | US-1502 **part 2**: clickable prototype + hallway test | 0.25 | 12.0 | DR-3 (optional) |
| | US-0109 (if D-28 done) | 0.25 | 12.25 | |
| | Sprint regression, demo, status note, **G-FL** | 0.5 | **12.75** | Sprint review |

**Phase totals:**

| Phase | Backend | Flutter | UI/UX | Wrap | Total |
|---|---|---|---|---|---|
| P1 | 1.25 (incl. React 0.25) | 0.75 | 0.75 | — | 2.75 |
| P2 | 3.0 | — | 1.5 | — | 4.5 |
| P3 | 1.25 | 1.5 | — | — | 2.75 |
| P4 | 0.25 | 1.75 | 0.25 | 0.5 | 2.75 |
| **Sprint 1** | **5.75** | **4.0** | **2.5** | **0.5** | **12.75** |

**Ordering consistency:**

- DR-1 precedes US-1303 navigation (P3).
- DR-2 sign-off precedes any Flutter visual styling (US-1303 theme in P3, US-0205 in P4).
- The direction pick (DR-2 part 1) precedes the US-1507 hi-fi, so the auth hi-fi is drawn once, in the chosen direction.

Cumulative points are planning estimates; actuals are recorded and feed k.

---

## 8. Testing and Definition of Done

**Standard DoD:** [09 §8](09-testing-and-definition-of-done.md#8-definition-of-done). **Defect closure rule:** [09 §12.1](09-testing-and-definition-of-done.md).

| Area | Sprint 1 evidence required |
|---|---|
| Backend | Full suite green on sqlite **and** MySQL (CI or a recorded local MySQL run). The 13 existing feature tests are kept, edited only where D-22 (paths), D-09 (money strings) or D-12 (roles) change behaviour, with the change noted in the commit. A regression test for each S1 defect. |
| Web (React) | TC-0106-04 green in CI (`oxlint -D no-undef` + `vite build`); TC-0106-05 browser smoke recorded (login against `/api/v1` lands on `/dashboard`). Lint warnings (DEF-17) may remain until S3; errors may not. |
| Flutter | `flutter analyze` clean. Unit tests: error mapping, idempotency key store, session controller. Widget tests: login validation and every error state; RTL directionality. `integration_test` TC-1306-01 – 06 on the **reference phone** against the local API. Release APK installed and launched on **both** phones. |
| Design | DR-1 and DR-2 recorded as approved. State matrix covered for every S1 screen. Contrast report. 130% text-scale check. RTL/bidi sample sheet viewed on a phone. |
| Integration | The auth contract file, the Flutter error mapping and the state matrix agree (checked at DR-2 and again at the sprint review) |
| Sprint | Demo performed; status note with actual vs estimate per story; G-FL decision recorded; no open P0 in scope; defect register updated with closure evidence |

---

## 9. Open Decisions and Genuine Blockers

### 9.1 Must be decided before Sprint 1 starts

| ID | Question | Recommendation | Impact of rejection |
|---|---|---|---|
| D-04, D-09, D-13, D-22, D-24 | Category A foundations (see [13 §6](13-final-review-and-decision-pack.md)) | Approve | The corresponding backend stories cannot start |
| D-12 / CR-10 | Role matrix. **Open question:** may employees use pay-all? | Fixed matrix, single owner, owner-only invitations | US-0105 blocked |
| D-23 / CR-14 | Store timezone value | `Asia/Hebron` (or `Asia/Gaza`) | US-0107 blocked |
| D-20 | Flutter stack (§4.1). **Moved from S2 to S1 start.** | Adopt provisionally; validate at G-FL | US-1303 blocked |
| **D-36** (new) | Location of the Flutter project | Monorepo `mobile/` | A separate repo means separate CI and contract sync |
| **D-37** (new) | Android applicationId | TL chooses, e.g. `com.hisbah.shop` | US-1303 blocked; changing it later is costly |

### 9.2 Needed during the sprint

| ID | Needed by | Recommendation |
|---|---|---|
| UI-D4 design tool | Day 1 of design work | HTML/CSS mockups + Excalidraw, unless Figma or Penpot access is provided |
| UI-D1 digits · UI-D2 font | DR-2 | Western digits; IBM Plex Sans Arabic (the TL confirms after seeing samples) |
| Visual direction | DR-2 | The TL picks one of the two from US-1506 |
| D-31 repeat-scan rule | G-FL (end of S1) | Decided from the US-1305 evidence |
| D-34 developer availability | Calendar commitment | Confirm full-time or part-time |
| D-28 SRS committed | US-0109 | Blocks US-0109 only |

### 9.3 Optional

| ID | Question | Recommendation |
|---|---|---|
| **D-38** (new) | Add an OTP foundation to S1 (`OtpSender` interface, `log` driver, `otp_verifications` table, no registration gating), +0.5 dd? | **No.** The provider is undecided (D-14), mobile does not register stores, and S1 is already 12.75 dd. Keep US-0203 in S6. |

### 9.4 External prerequisites (genuine blockers if missing)

| Item | Needed by | Blocks |
|---|---|---|
| Two Android phones (mid-range, Android ≥ 10; low-end, Android 8–9, 2–3 GB RAM) with USB cables and developer options | P1 | US-1302, US-1305, US-1306 |
| Bandwidth for the SDK, Android SDK and Gradle downloads (several GB) | P0 | US-1302 timing |
| GitHub Actions enabled on `abdelmoen1/debt-management-system` | P1 | CI part of US-0108 and US-1306 (local fallback exists) |
| 2–3 shop staff for a 15-minute prototype test | P4 | US-1502 test (can slip to S2) |
| A PDF text-extraction tool (developer tool, not a project dependency) | P4 | US-0109 |
| 20 real product barcodes (+ printed Code128 samples) | P4 | US-1305 |

---

## 10. Revised Effort and Duration

### 10.1 Effort by category (developer-days, base)

| Category | dd | Notes |
|---|---|---|
| Backend | 5.5 | ≈ 2.0 of it is tests (embedded per the DoD; indicative) |
| Web compatibility (T-0106-5) | 0.25 | React → `/api/v1`, DEF-12 fix, CI lint/build job, smoke test |
| Flutter | 4.0 | Includes the integration tests and CI job (US-1306, 0.5) |
| UI/UX | 2.5 | Including 0.25 review revisions; P1 0.75 · P2 1.5 · P4 0.25 |
| Sprint integration, regression, demo, G-FL | 0.5 | — |
| **Sprint 1 base** | **12.75** | v0.2 Sprint 1 was 6.5. rev. 0 of this plan was 12.5; +0.25 for T-0106-5. |

**Contingency** (same method as [11 §5.3](11-risk-register-and-feasibility.md)): Flutter 30% × 4.0 = 1.2; the rest 15% × 8.75 = 1.31. **Sprint 1 with contingency ≈ 15.25 dd.**

### 10.2 Calendar duration (effort ≠ calendar)

| Availability (D-34, unconfirmed) | Sprint 1 duration |
|---|---|
| Full-time, 5 days/week (A-07) | ≈ 2.5 weeks base (12.75 dd), ≈ 3 weeks with contingency (≈ 15.25 dd) |
| Half-time | ≈ 5–6 weeks |

**Not included:** waiting time for decisions, phones, test participants and downloads.

### 10.3 Estimation assumptions

- ≈ 6 productive hours per developer-day.
- AI-assisted implementation, with verification time included.
- Backend stories keep the v0.2 estimates (they reuse proven patterns).
- Flutter estimates assume a first Flutter project by a developer with limited experience and are **re-calibrated at G-FL**.
- UX estimates assume low-fi + targeted hi-fi, not a full hi-fi app.
- **These are planning estimates, not guarantees.**

### 10.4 What may slip under time pressure (rev. 1)

**Protected scope (never cut):**

- US-0101 – US-0108 and T-0106-5 (financial integrity and a working web);
- US-1302 (toolchain proof);
- **DR-1, DR-2 and the two visual directions (US-1506);**
- US-1501, US-1505, US-1507 and the US-1502 low-fi.

Mobile design quality is a priority, not a buffer.

| Order | May slip to S2 | Saving | Consequence |
|---|---|---|---|
| 1 | US-1502 part 2: prototype + hallway test (the low-fi stays in S1) | −0.25 | F-1 is validated with real staff in S2, still before any POS code (S5) |
| 2 | US-0109 (automatically, if D-28 is not done) | −0.25 | The matrix stays PROVISIONAL |
| 3 | US-1305 barcode spike | −0.5 | G-FL is decided on k only; the barcode evidence for D-31 arrives in S2, still before S5 |

**Smallest coherent Sprint 1 = 11.75 dd** (12.75 − 1.0).

**Recommendation:** approve the full 12.75 dd scope.

### 10.5 Downstream roadmap adjustment

| Sprint | v0.2 | Proposed | Reason |
|---|---|---|---|
| S1 | 6.5 | **12.75** | Flutter foundation, mobile UX and integration made explicit; React compatibility with `/api/v1` (T-0106-5) |
| S2 | 7.0 | 5.25 | US-1301 (1.5) and US-1502 (0.5) moved to S1; the US-1301 lookup remainder (0.25) stays |
| S4 | 5.25 | 6.0 | **New US-1508**: mobile hi-fi designs (POS, checkout, customers, payment, home, products) before S5, 0.75 |
| S5 | 6.5 | 6.0 | US-0205 moved to S1 |
| S3, S6 – S10 | — | Unchanged | — |
| **R1 total** | 35.75 (≈ 42.4) | **40.5 (≈ 48.1 with contingency)** | +4.75 = Flutter foundation realism +1.75, mobile UX +2.25, sprint wrap +0.5, React compatibility +0.25. S3's US-0202 estimate is left unchanged (conservative), although its `api.js` fix is now done in S1. |

**Consequences:**

- The day-20 line now falls in early S3.
- G-FL moves from the end of S2 to the end of S1, so the S5 estimate is calibrated about one sprint earlier.
- If approved, 07, 08, 11 and 02 are updated to these figures in a follow-up documentation change.

---

## 11. Approval Checklist

| # | Item | Approve | Change requested |
|---|---|---|---|
| 1 | Sprint goal and success criteria S-1 – S-4 (§1) | ☐ | ☐ |
| 2 | In-scope / out-of-scope lists (§2), including **D-38 = no OTP in S1** | ☐ | ☐ |
| 3 | Backend task list and order (§3), including **T-0106-5: React updated to `/api/v1` in S1** (rather than keeping the old paths) | ☐ | ☐ |
| 4 | Flutter stack D-20 (§4.1), project location **D-36**, applicationId **D-37** (value: ________) | ☐ | ☐ |
| 5 | Flutter tasks, and G-FL moved to the end of S1 (§4.2 – §4.3) | ☐ | ☐ |
| 6 | Design principles and anti-patterns (§5.2) | ☐ | ☐ |
| 7 | IA, role landing and screen inventory (§5.3 – §5.4) | ☐ | ☐ |
| 8 | First flow to validate = Quick sale F-1 (§5.5) | ☐ | ☐ |
| 9 | Design tool **UI-D4** (§5.1) | ☐ | ☐ |
| 10 | DR-1 / DR-2 rules and timings (§5.8, §7): DR-1 approved by ≈ 2.75 dd; DR-2 direction pick ≈ 7.0, approved by ≈ 7.25 dd; no visual styling before DR-2 | ☐ | ☐ |
| 11 | Estimate: **12.75 dd** base / ≈ 15.25 with contingency; calendar per D-34; protected design scope and slip order (§10) | ☐ | ☐ |
| 12 | Roadmap adjustment: R1 = **40.5** base (≈ 48.1), new US-1508 in S4 (§10.5) | ☐ | ☐ |
| 13 | S1 blocker decisions recorded in 03 (§9.1) | ☐ | ☐ |
| 14 | External prerequisites ready (§9.4) | ☐ | ☐ |

Implementation starts only after this checklist is approved **and** a separate implementation prompt is issued.

**TL approval received (2026-10-13):** the plan is approved at 12.75 dd base / ≈ 15.25 with contingency, with D-04, D-09, D-12, D-13, D-20, D-22, D-23 / CR-14 (`Asia/Gaza`), D-24, D-36, D-37 (`com.hisbah.smartshop`) and D-38 approved, and the implementation prompt issued. UI-D4: HTML/CSS prototypes under `docs/design/` (no other design tool available). Item 14 (external prerequisites) is **not** confirmed and is tracked in the progress report. Calendar assumption: 5 working days/week, 6 productive hours/dd; actual effort is tracked and estimates recalibrated at G-FL.

---

## 12. New and Changed IDs (to be merged into 03 / 07 / 08 on approval)

### 12.1 New stories

#### US-1303 · Flutter project foundation (E13, S1, 1.0 dd)

- Deliverables, acceptance and tests as in §4.2.
- Replaces tasks T-1301-1 (project and template), T-1301-2 (packages) and part of T-1301-5 of US-1301.
- **Tests:** TC-1303-01 widget smoke · TC-1303-02 RTL directionality · TC-1303-03 analyze clean.

#### US-1304 · Mobile API client foundation (E13, S1, 0.5 dd)

- As in §4.2.
- Replaces T-1301-3 (key persistence part, SP-03).
- **Tests:** TC-1304-01 error mapping · TC-1304-02 key persistence across app restart.

#### US-1305 · Barcode camera spike, SP-02 (E13, S1, 0.5 dd)

- As in §4.2.
- Replaces T-1301-4 and test TC-1301-04 (renamed TC-1305-01; the old ID is retired, not reused).
- **Tests:** TC-1305-01 spike report.

#### US-1306 · Mobile ↔ Laravel auth integration and Flutter CI (E13, S1, 0.5 dd)

- As in §4.2.
- Replaces the CI part of T-1301-5.
- **Tests:** TC-1306-01 login OK · TC-1306-02 wrong password · TC-1306-03 throttled 429 · TC-1306-04 deactivated 403 · TC-1306-05 logout then 401 · TC-1306-06 session restore.

#### US-1505 · Mobile IA, navigation and R1 screen inventory (E15, S1, 0.25 dd)

- As in §5.7.
- **Tests:** TC-1505-01 DR-1 sign-off.

#### US-1506 · Mobile visual direction (E15, S1, 0.5 dd)

- As in §5.7.
- **Tests:** TC-1506-01 DR-2 decision recorded.

#### US-1507 · Auth and app-shell screen designs (E15, S1, 0.25 dd)

- As in §5.7.
- **Tests:** TC-1507-01 DR-2 sign-off.

#### US-1508 · Mobile hi-fi designs for R1 screens (E15, S4, 0.75 dd)

- **Role / Story:** As the TL, I want hi-fi designs of the POS, checkout, customer, payment, home and product screens in the approved direction before S5, so that mobile implementation does not invent UI.
- **Trace:** NFR-12, §9.4; SCR-M-02 – M-11.
- **AC:**
  1. Every SCR-M-02 – M-11 screen has a hi-fi design with its state matrix, using only design-system components.
  2. The designs incorporate the DR-3 prototype findings.
  3. They are approved at a design review before S5 starts.
- **Tests:** TC-1508-01 design-review sign-off.
- **Deps:** US-1501, US-1506 (DR-2), US-1502.

### 12.2 Changed stories (explicit, not silent)

| ID | Change |
|---|---|
| US-1301 | **Split.** S1 parts → US-1303, US-1304, US-1305, US-1306. Remainder in S2: T-1301-7 scan → `/products/lookup` integration (0.25 dd). The SP-04 calibration is done on US-1303, US-1304 and US-0205 instead of a search screen. Gate G-FL moves to the end of S1. |
| US-0106 | **New task T-0106-5** (rev. 1): React base URL → `VITE_API_URL` / `/api/v1` + DEF-12 one-character fix + React CI job; new tests **TC-0106-04** (CI lint/build) and **TC-0106-05** (browser smoke). US-0106 itself stays 0.5; T-0106-5 adds 0.25. |
| US-0202 | Its task T-0202-1 ("Fix `api.js`") is done in S1 by T-0106-5. The rest of US-0202 stays in S3, with its estimate unchanged. DEF-12 regression evidence becomes TC-0106-04 (S1) + TC-1201-01 (S3). |
| US-1302 | Estimate 0.5 → 0.75 (first-time Windows setup with two phones) |
| US-0205 | Moved S5 → S1; estimate 0.5 → 0.75 (all auth error states, styled after DR-2) |
| US-1501 | Re-scoped mobile-first (adds RTL/bidi sheet and colour roles for payment states); 0.5 → 0.75 |
| US-1502 | Moved S2 → S1; scope narrowed to SCR-M-02 – M-06 + prototype test (SCR-M-07 – M-11 move to US-1508) |
| Test IDs | TC-1301-04 is retired → TC-1305-01. TC-1301-01 – 03 and 05 stay for the US-1301 remainder only if still applicable; they are confirmed at merge time. |

### 12.3 New decisions

| ID | Topic |
|---|---|
| D-36 | Flutter project location |
| D-37 | Android applicationId |
| D-38 | OTP foundation in S1 (recommended **no**) |

Existing decisions D-20 (now needed at S1 start) and D-31 (evidence produced in S1) change only in timing.

### 12.4 Design and UX decision IDs

| ID | Topic | Status |
|---|---|---|
| UI-D4 | Design tooling | New |
| UI-D1 | Digits | Existing (06 §10), now needed at DR-2 |
| UI-D2 | Font | Existing (06 §10), now needed at DR-2 |
