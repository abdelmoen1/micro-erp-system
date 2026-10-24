# 15 — Compressed Delivery Plan (S2 close → S10), 20–31 October 2026

> **Status: APPROVED DIRECTION (TL, 2026-10-19)** · supersedes the calendar in [07](07-milestones-and-sprints.md); the sprint *scope* in 07 and the stories in [08](08-user-stories-and-technical-tasks.md) still apply.
> Decisions behind this plan: [03 v0.5](03-decision-log-and-change-requests.md) (all open decisions approved on 2026-10-19).
> Readers: Backend (BE), Web front end / React (FE), Flutter (FL), UI/UX (UX), and the Team Leader (TL).

---

## 1. Goal and the honest picture

**Goal:** finish the remaining work of S2–S10 by **31 October 2026**, then pilot in one or two real shops before the product is handed over or sold.

**What has to be true for this to work:**

| Fact | Consequence |
|---|---|
| The remaining scope was estimated at **≈ 45 developer-days** for one developer (07). | 10 calendar days is only possible with **four tracks in parallel** (BE, FE, FL, UX), AI assistance on BE and FL, and no idle waiting between tracks. |
| FE and FL cannot start a screen before its API and its design exist. | **Contract first:** BE publishes the `.http` contract for an endpoint the morning it starts it. **Design first:** UX delivers each screen **one day before** it is built (§6). |
| The pilot is the real acceptance test. | **R1 (core shop) ships on Day 6** so the first pilot shop starts on Day 7, while R1.1 (AI, sharing) and R2 (offline) are built. |
| Offline sync (S9–S10) is the highest-risk work. | It is last, with an explicit cut-line (§9). If the pilot shops have unreliable internet (D-35), S9–S10 move **before** S7 (§2, note). |

---

## 2. Calendar

| Day | Date | Sprint(s) | Milestone | End-of-day gate |
|---|---|---|---|---|
| D1 | Tue 20 Oct | **S2 close** | M2 Catalog & Sales Core | Sale API (cash / credit / partial / void, weighted goods) merged, tests green |
| D2 | Wed 21 Oct | **S3** (API) · S5 starts (FL) | M3 | Returns, debt lists, payments v1 merged |
| D3 | Thu 22 Oct | **S3** close · **S4** starts (FE) | M3 | Statement + dashboard v2 merged; React shell + login + dashboard working |
| D4 | Fri 23 Oct | **S4** + **S5** | M4, M5 | Half the web admin screens; mobile cart + checkout on a phone |
| D5 | Sat 24 Oct | **S4** + **S5** close | M4, M5 | All R1 screens done; full-day walkthrough on web + phone |
| D6 | Sun 25 Oct | **S6** | M6 **R1 release** | Production up, OTP, backups, UAT pass → **R1 released** |
| D7 | Mon 26 Oct | **S7** · *Pilot shop 1 starts* | M7 AI | AI read tools + drafts with confirmation |
| D8 | Tue 27 Oct | **S8** | M8 **R1.1 release** | Secure link, WhatsApp, voice, mobile return → **R1.1 released** |
| D9 | Wed 28 Oct | **S9** | M9 Offline | Offline sale + payment captured and kept across restarts |
| D10 | Thu 29 Oct | **S10** | M10 | FIFO sync, conflicts, queue limit → **R2 release candidate** |
| B1–B2 | Fri 30 – Sat 31 Oct | Buffer | — | Pilot fixes; pilot shop 2; R2 go / no-go |

> **Swap rule (D-35):** if the pilot-shop survey (§7) shows frequent internet outages, run S9 on D7 and S10 on D8, and move S7/S8 to D9/D10.
> **Daily rhythm:** 09:00 stand-up (15 min, blockers only) · contracts and designs for the day are already in the repo · 18:00 merge window + CI green · 19:00 demo of the day's gate to the TL.

---

## 3. Working rules (all tracks)

1. **Branch per story** (`feat/us-XXXX-...`), PR into `main`, CI green before merge. No direct pushes to `main`.
2. **API contract first:** every new endpoint gets a section in `docs/api/*.http` and its error codes in `docs/api/error-codes.md` **before** FE/FL use it. `ErrorCodeContractTest` keeps them honest.
3. **Money** stays a 2-decimal string (D-09); **quantities** become decimal strings with up to 3 decimals (§4).
4. **Every financial write** keeps `Idempotency-Key`, store isolation (404 for other stores), an audit-log entry, and one DB transaction.
5. **Definition of Done** = [09](09-testing-and-definition-of-done.md): story ACs tested, isolation case, role case, RTL/Arabic checked, docs updated.
6. **Mobile delivery:** Dart-only changes ship to pilot phones as **Shorebird OTA patches**; native plugin changes need a **full release**. To keep R1.1 and R2 patchable, the **R1 build (D6) already includes** the native plugins planned for later (speech-to-text, local database).
7. **Design source of truth:** `docs/design/` (Direction A · Ledger, IBM Plex Sans Arabic, Western digits — DR-2).

---

## 4. Weighted goods (CR-13, modified) — shared spec

The TL decided that shops sell **both pieces and weighed goods** (nuts, spices). This is the design all tracks build against.

| Topic | Rule |
|---|---|
| Product unit | `products.unit` = `piece` (default) or `kg`. Prices (`selling_price`, `cost_price`) are **per unit** (per piece or per kg). |
| Quantity storage | `DECIMAL(12,3)` for `products.current_stock`, `minimum_stock`, `stock_movements.quantity`, `invoice_items.quantity` / `returned_quantity`, return items. |
| Validation | `piece` → whole numbers only. `kg` → `> 0`, at most 3 decimals (1 g precision). |
| Line total | `round_half_up(quantity × unit_price, 2)` with bcmath; `unit_price` and `line_total` are snapshotted on the line. |
| API format | Quantities are strings: `"3"` for pieces, `"0.750"` for kg. **Contract change** for `current_stock` / `minimum_stock` (was integer): FL updates `Product` in the same PR. |
| POS (mobile) | Scanning or picking a `piece` product adds 1 (repeat scan +1, 1.5 s cooldown, D-31). A `kg` product opens the **weight sheet** (enter kg / g); repeat scan opens the sheet again instead of +1. |
| Receipts / statements | Show `0.750 كغم × 60.00 ₪ = 45.00 ₪`. |
| Low stock | Threshold in the product's unit (e.g. 2.5 kg). |
| Open questions (TL) | See §10: "sell by amount" (₪ 10 of almonds) and label-printing scale barcodes. Not built until answered. |

---

## 5. Sprint-by-sprint tasks per role

Story IDs refer to [08](08-user-stories-and-technical-tasks.md); screen IDs to [06](06-ui-ux-and-screen-plan.md).

### S2 close — Catalog & Sales Core · **D1 (Tue 20 Oct)**

**Goal:** one atomic, product-based sale path with an immutable history. **SRS:** FR-15–28, 30, 31, 34–36; BR-01, 04, 07, 11; AC-03.

| Role | Tasks |
|---|---|
| **BE** | • **CR-13** migration: `products.unit`, decimal quantities (§4); update product API, `StockService`, tests.<br>• **US-0701** debts: `customer_id` (backfilled), `due_date`, `return_credit`; backfill test = 100 % match (D-10).<br>• **US-0501** cash sale: product-linked lines, prices from the DB, stock deduction via `StockService::move()`, `invoices.paid_amount` (D-08), `customer_id` nullable when fully paid (D-07). **Stock shortfall → sale allowed with warning + `NEGATIVE_STOCK` flag** (D-27).<br>• **US-0502** credit / partial sale: debt = total − paid, atomic; credit limit (D-26): Employee refused, Owner/Manager override with `confirm_over_limit=true` (audited).<br>• **US-0503** invoice final at creation (D-06): remove financial `PATCH` and `DELETE`; `POST /invoices/{id}/void` (reason, no live payments or returns) restores stock, cancels debt, audits.<br>• Rewrite the old invoice tests; `docs/api/sales.http`; merge PR #7 (credit limit) first. |
| **FL** | • Install release **1.0.0+2** on the reference phone; run the **US-1305 scanner spike** with ~20 real barcodes (timing for NFR-02 ≤ 1.5 s).<br>• Start **US-0505** cart state (Riverpod): lines, repeat-scan cooldown, weight sheet, totals with exact money; against the D1 contract. |
| **FE** | • **US-1201** start: `apiClient` (envelope, errors, `Idempotency-Key`), TanStack Query, RTL layout skeleton.<br>• Fix register wiring (DEF-13).<br>• **D-32** Playwright proof: one login flow test in CI. |
| **UX** | Hi-fi for D2–D3 builds: **SCR-M-02** cart (+ weight sheet), **M-04** checkout (cash / credit / partial, credit-limit warning, negative-stock warning), **M-05** customer picker, **M-06** receipt; **SCR-W-01** login, **W-02** register, **W-04** shell, **W-05** dashboard. |
| **TL** | See §7 (merge PRs, run the release workflow, hosting, pilot survey). |

**Demo:** create a weighed product → sell 0.75 kg + 3 pieces with a partial payment → stock and debt correct → void → stock restored, debt cancelled, audit entry.

### S3 — Debts, Returns & Insights + Web Foundation · **D2–D3 (Wed 21 – Thu 22 Oct)**

**Goal:** complete the R1 API and the React foundation. **SRS:** FR-12–14, 32, 33, 37–42, 46–48; AC-04, AC-10.

| Role | Tasks |
|---|---|
| **BE** | D2: • **US-0601** returns (D-05 debt-first, then cash refund; decimal quantities; not on voided invoices).<br>• **US-0702** due today / this week / overdue / highest balance (store timezone).<br>• **US-0703** payments v1: `store_id`, `customer_id`, `reversed_by` backfill; group-only reversal (D-11); invariant test TC-0703-06.<br>D3: • **US-0302** customer summary + chronological statement.<br>• **US-0801** dashboard v2: collections split (at sale vs debt repayments), new-debt metric, insight cards (overdue, due today, low stock, negative-stock review, high balance).<br>• **DEF-19** Arabic validation messages (`lang/ar`). |
| **FE** | D2: • **US-1201** app shell: RTL sidebar, store / role header, role-aware routes, logout.<br>• **US-0202** login / session; **US-0201** registration wired to the API.<br>D3: • **US-0802** dashboard (period filter, KPI cards, insight cards, simple charts).<br>• Shared components: `MoneyText`, `QtyText` (unit-aware), `StatusBadge`, `DataTable`, `ConfirmSummary`, `ReasonDialog`. |
| **FL** | **S5 starts:** • **US-0505** cart + scanner integration (scan → lookup → cart line).<br>• **US-0506** checkout against the D1 sale API (cash / credit / partial, due-date chips +7 / +30, warnings, idempotent retry). |
| **UX** | D2: web admin hi-fi **SCR-W-06 → W-15** (customers, customer detail + statement, products + product form with unit and movements, sales list / detail with void, return dialog, debts tabs, payments, staff).<br>D3: mobile hi-fi **SCR-M-07 → M-11** (customers, customer detail, record payment, home, products + low stock) = **US-1508**. |

**Demo (D3):** a return on a partially paid sale reduces the debt and refunds the excess; the web dashboard shows real KPIs after a real login.

### S4 — Web Admin (R1) · **D3–D5 (Thu 22 – Sat 24 Oct)**

**Goal:** the back office on the web. **SRS:** FR-08–16, 20–22, 29–42 (UI side).

| Role | Tasks |
|---|---|
| **FE** | • **US-0301** customers list + create / edit + deactivate (D-33).<br>• **US-0303** customer detail + statement.<br>• **US-0405** products + stock: list, low-stock filter, **negative-stock review list** (D-27), product form with **unit**, movements history, stock adjustment with reason.<br>• **US-0504** sales list / detail + void; **US-0602** return dialog with preview (debt reduction / refund).<br>• **US-0704** debts (tabs) + opening debt; payments history, record, reverse (single / group).<br>• **US-0204** staff: invite, role, deactivate.<br>• **US-0408 (new, +0.5 dd)** product **CSV import** — needed to onboard a pilot shop with hundreds of products in minutes. |
| **BE** | • **D-33** `customers.status` + endpoints.<br>• **US-0408** import endpoint (validate all rows, then import atomically; report row errors).<br>• Integration fixes for FE/FL.<br>• **US-0203** OTP backend with the `log` driver (store `pending_verification` → `active`). |
| **QA / TL** | Role checks (UI-AC-07), keyboard-only check (UI-AC-11), web regression checklist. |

**Demo (D5):** a full back-office day: import products, adjust stock, view a sale, return, record and reverse a payment, invite an employee.

### S5 — Mobile POS (R1) · **D2–D5 (Wed 21 – Sat 24 Oct)**

**Goal:** the daily till on Android. **SRS:** FR-17, 18, 23–27, 38; AC-01, AC-02, AC-03; NFR-02, NFR-12.

| Role | Tasks |
|---|---|
| **FL** | • **US-0505** cart (done D2–D3) + **US-0506** checkout (D3).<br>• **US-0304** customer search + quick-create inside checkout (D4).<br>• **US-0705** customer detail, open debts, record payment (D4).<br>• **US-0406** product search + low stock (D5); **US-0803** home dashboard v2 numbers (D5).<br>• Hardening: loading / empty / error states, 130 % text, session-expiry sheet that keeps the cart (DR-1 Q2), logout confirmation with a cart (Q3). |
| **QA** | Device tests AC-01 (scan → product ≤ 1.5 s), AC-02 (repeat scan +1), AC-03 (credit sale updates total, payment, debt, stock); network-retry no-duplicate test. |

**Demo (D5):** a real phone: scan → partial sale → customer balance → collect payment → dashboard; the web shows the same numbers.

### S6 — R1 Release · **D6 (Sun 25 Oct)**

**Goal:** ship R1 safely to production. **SRS:** FR-02, BR-09; NFR-01, 08, 16.

| Role | Tasks |
|---|---|
| **BE / Ops** | • **US-1401** production on the **paid** host chosen by the TL (D-25): HTTPS, queue worker, scheduler, `APP_DEBUG=false`, CORS allow-list.<br>• **US-0203** OTP production driver (fallback if the provider is not ready: TL activates pilot stores manually; logged).<br>• **US-1402** daily backup + one restore drill (evidence in the repo).<br>• **US-1404** performance: p95 < 3 s on a seeded store. |
| **FE** | **SCR-W-03** OTP screen; production build + deploy of the web admin. |
| **FL** | **Full release 1.1.0** (includes the later native plugins, rule 3.6); install on the pilot phones; set `MOBILE_OTA_RELEASE_VERSION=1.1.0+N` and `MOBILE_OTA_ENABLED=true`. |
| **QA / TL** | UAT of AC-01–04 and AC-10; G-R1 checklist; go / no-go. |

### S7 — Controlled AI Assistant (R1.1) · **D7 (Mon 26 Oct)**

**Goal:** Arabic questions answered from real data; payment and invoice **drafts** that execute only after confirmation. **SRS:** FR-49–59, 61–63; BR-02, 13, 14; AC-08, AC-09.

| Role | Tasks |
|---|---|
| **BE** | • **US-1001** provider-agnostic `AiClient` + evaluation spike (30 Arabic utterances; pick the provider by score, D-15).<br>• **US-1002** read tools (sales, total debt, customer balance, low stock) + daily summary — store-scoped, permission-checked.<br>• **US-1003** payment draft, **US-1004** invoice draft (weighted lines included) → same services as the manual path, re-validated on confirm, idempotent. |
| **FE** | **US-1005** web AI chat (**SCR-W-16**) with preview / confirm. |
| **FL** | **US-1006** mobile AI chat (**SCR-M-12**) + draft preview sheet (**M-13**). |
| **UX** | (Delivered D6) M-12, M-13, W-16. |

### S8 — Secure Sharing & Mobile Completion · **D8 (Tue 27 Oct)** → **R1.1**

| Role | Tasks |
|---|---|
| **BE** | **US-0901** secure link (UUIDv4, hashed at rest, 30-day expiry, one active link per customer, revocable — CR-07); public statement endpoint (**US-0902** API). |
| **FE** | **SCR-W-17** public statement page `/s/:token` (fast on 4G, NFR-07). |
| **FL** | **US-0903** share via WhatsApp (**SCR-M-14**); **US-1007** voice input → same AI endpoint; **US-0603** mobile return (**SCR-M-15**). Ship as an **OTA patch** if rule 3.6 held. |
| **UX** | (Delivered D7) M-14, M-15, W-17. |

### S9 — Offline Foundations (R2) · **D9 (Wed 28 Oct)**

**Goal:** sales and payments can be captured with no internet (CR-02: returns and opening debts stay online-only). **SRS:** FR-64, 66; NFR-04, 05; BR-08, BR-10.

| Role | Tasks |
|---|---|
| **BE** | **US-1101** batch sync API: client transaction IDs, per-item result, conflict state, never discards an item (BR-10). |
| **FL** | **US-1102** local cache (products, customers, balances; D-19 benchmark ≤ 0.5 s search on 10 k items); **US-1103** offline sale + payment capture, local commit ≤ 200 ms, survives kill / restart. |
| **UX** | (Delivered D8) **SCR-M-16** sync status, **SCR-W-18** conflicts, **SCR-M-17** stock adjustment. |

### S10 — Sync, Conflicts & R2 · **D10 (Thu 29 Oct)** → **R2 candidate**

| Role | Tasks |
|---|---|
| **FL** | **US-1104** FIFO sync engine + indicator (pending / synchronizing / synced / needs review); **US-1105** queue limit (warn 800, block 1000); **US-0407** mobile stock adjustment. |
| **FE** | **US-1106** conflict review and resolution (**SCR-W-18**). |
| **BE** | Conflict resolution endpoints; **US-1405** offline performance (100 and 1000 queued items sync ≤ 60 s at 1 Mbps). |
| **QA** | AC-06, AC-07 (10 queued items sync FIFO exactly once). **US-1107** location capture is *Could* — first to cut. |

---

## 6. UX delivery schedule (designs one day ahead)

| Due (end of day) | Screens | Built on |
|---|---|---|
| **D1 – Tue 20 Oct, 12:00** | M-02 cart + weight sheet, M-04 checkout, M-05 customer picker, M-06 receipt (FL builds D1 afternoon on the low-fi frames until then) | D1–D3 (FL) |
| **D1 – Tue 20 Oct** | W-01 login, W-02 register, W-04 shell, W-05 dashboard | D2–D3 (FE) |
| **D2 – Wed 21 Oct** | W-06 → W-15 web admin + CSV import dialog + negative-stock review list | D3–D5 (FE) |
| **D3 – Thu 22 Oct** | M-07 → M-11 mobile (US-1508) | D4–D5 (FL) |
| **D5 – Sat 24 Oct** | W-03 OTP | D6 |
| **D6 – Sun 25 Oct** | M-12 AI chat, M-13 draft preview, W-16 web AI | D7 |
| **D7 – Mon 26 Oct** | M-14 share link, M-15 mobile return, W-17 public statement | D8 |
| **D8 – Tue 27 Oct** | M-16 sync status, M-17 stock adjustment, W-18 conflicts | D9–D10 |

Each delivery: every state (loading, empty, error, success), RTL, 130 % text, colour-independent status cues (UI-AC-05).

---

## 7. TL actions and external inputs (with deadlines)

| # | Action | Deadline | Why |
|---|---|---|---|
| 1 | Run **Mobile release** (Actions → *Mobile release (Shorebird, Android)* → Run workflow on `main`), install the APK, then set `MOBILE_OTA_RELEASE_VERSION=1.0.0+2` | **D1 morning** | The patch run of 19 Oct failed by design: `main` is 1.0.0+2 (scanner = native plugins), which needs a full release. |
| 2 | Merge PR #2 (deploy), #4 (BOM-safe secrets), #7 (credit limit); close #6 (already in `main`); point Render at `main` and redeploy | D1 | The live API lacks `/products/lookup`; the scanner needs it. |
| 3 | Register the owner on the live API (`backend/tool/deploy/register_owner.ps1`) | D1 | The live database has no users. |
| 4 | **Pilot-shop survey** (2–3 shops): internet reliability during trading hours, number of products, weighed goods, staff count, phones | **D2** | Decides the swap rule (§2) and the onboarding import. |
| 5 | **Paid hosting** choice (D-25) — the free tier sleeps and the free DB powers off when idle, which a real shop cannot accept | **D4** | Needed for S6. |
| 6 | **OTP provider** account (D-14), sender ID for +970 / +972 | **D4** | S6; fallback = manual activation. |
| 7 | **AI provider** API key for the evaluation spike (D-15) | **D6** | S7. |
| 8 | ~~Commit SRS v1.1~~ **Done** 2026-10-19 (`docs/Hisbah_Smart_Shop_SRS_v1.1.pdf`); BE runs the US-0109 check on D1 | D1 | Final traceability check (US-0109). |
| 9 | ~20 real barcodes + the reference phone available to FL | D1 | Scanner spike (US-1305). |

---

## 8. Pilot plan (before any sale)

1. **Shop 1 from D7 (26 Oct):** onboarding visit — CSV import of products, opening debts entered, staff invited, phones installed. The team is on call; fixes ship daily as OTA patches.
2. **Shop 2 from B1 (30 Oct)** on R1.1 (or R2 if offline passed).
3. **Daily pilot log:** sales count, average time per sale, errors / crashes, sync issues, cash count vs dashboard total, owner feedback.
4. **Go / no-go to hand over or sell:** **7 consecutive trading days** in each shop with **zero financial discrepancies** (cash count = dashboard collections), no open P0 / P1 defect, and the owner would keep using it. Realistically this puts the hand-over in the **first half of November**, after the 10-day build.

---

## 9. Risks and cut-lines

| Risk | Signal | Response |
|---|---|---|
| R1 not green at the end of D6 | G-R1 checklist fails | Delay S7; everyone fixes R1. **The pilot never starts on a red R1.** |
| Offline (S9–S10) slips | D9 gate missed | Ship R1.1 to the pilot; R2 continues after 31 Oct. Cut US-1107 first, then the web conflict UI (resolve via support). |
| AI quality in Arabic dialect | Spike score below target | Keep read-only questions; drafts behind a feature flag. |
| Weighted goods edge cases | Rounding complaints in the pilot | Exact bcmath rules (§4) + tests; amount-based entry only after the TL answers §10. |
| Hosting / OTP accounts late | Not ready by D4 | Manual store activation; temporary paid tier on the current provider. |
| One track blocked waiting for another | Stand-up shows a wait | Contract-first and design-first rules (§3); the waiting track takes the next story. |

---

## 10. Open questions for the TL (weighted goods)

1. **Sell by amount:** does the cashier need "₪ 10 of almonds" (system computes the weight), or always the weight from the scale?
2. **Label-printing scales:** do the pilot shops have scales that print barcodes with the weight or price inside (EAN-13 starting with 2)? If yes, the scanner can read the weight directly.
3. **Units:** is `kg` enough, or do shops also price per 100 g / per litre?

Until answered, the build uses weight entry in kg with gram precision.
