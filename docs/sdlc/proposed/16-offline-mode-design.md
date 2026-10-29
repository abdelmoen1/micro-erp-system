# 16 · Offline Mode Design (R2) — for approval

**Status:** Approved 2026-10-29 (decisions A–D as recommended) and implemented, see §9 · **Scope:** [02 §2.3](02-mvp-scope-and-release-strategy.md) — FR-64–68, NFR-03–06, BR-05/08/10/12, UC-22, AC-06/07, US-1101–US-1106 · **Builds on:** D-02, D-03, D-04, D-18, D-19, D-26, D-27, CR-02

Why now: the team is in Gaza, where internet and power cuts are daily. Today a sale is saved on the server at confirmation and retried with the same `Idempotency-Key` if the line drops, but nothing works without a connection. This design keeps that online path unchanged and adds a local commit plus a sync queue.

---

## 1. What works offline (and what does not)

| Works offline | Stays online-only |
|---|---|
| Product search and barcode lookup (local catalog) | Returns, voids, opening (legacy) debts — CR-02 |
| Customer search with balance and credit limit | Creating or editing customers and products |
| Cash, partial and credit sales, with any payment method (`cash`, `palpay`, `jawwal_pay`, `bank_of_palestine`) | Stock adjustments, staff, settings, subscription |
| Customer payments (amount allocated oldest debt first, as online) | Sales history from the server (local pending sales are listed separately) |
| Receipt with a local reference; dashboard shows pending totals | |

A cold start without internet already works with the cached user (`SessionController._restore`). Logout is refused while the queue holds unsynced items, so another account can never send them.

## 2. Local database: `sqflite` (raises CR-11)

D-19 defaulted to Hive unless a check failed. It fails on the transaction requirement, so I recommend SQLite:

- **Atomic local commit.** A sale must write the queue row and its stock/balance effect together. Hive has no multi-box transaction; a power cut between two writes would leave the cache and the queue disagreeing. SQLite does it in one `BEGIN … COMMIT`.
- **Ordered queue.** `seq INTEGER PRIMARY KEY AUTOINCREMENT` gives strict FIFO for free (BR-05).
- **Search (NFR-03).** Indexed `LIKE` over a normalised name column on 10 k rows is tens of ms on a Galaxy A01-class phone, well inside 0.5 s.
- **APK size.** `sqflite` uses the SQLite already in Android, so it adds a small Java plugin (≈ 50–100 KB), not a bundled native library. `drift` would need `sqlite3_flutter_libs` (≈ 1–2 MB per ABI) plus code generation. `hive_ce` is pure Dart but fails the first point.
- **No other new plugin.** Connectivity comes from the API client's existing reachability signal plus a probe (§5); no `connectivity_plus`, no `path_provider`.

Because `sqflite` is a native plugin, this ships as a **full Shorebird release (1.3.0)**, not a patch. Tests use an in-memory implementation of the same store interface, plus `sqflite_common_ffi` for the SQL itself where the host allows it.

### Local tables

| Table | Holds |
|---|---|
| `products` | Active and inactive products: price, carton, unit, server stock, `search_key` |
| `customers` | Name, phone, server balance, credit limit, overdue, status |
| `outbox` | `seq`, `client_transaction_id` (UUID), `type` (`sale`/`payment`), `payload` (exact `POST` body), `occurred_at`, `charged` (prices the cashier used), `state` (`pending`/`done`/`review`), `attempts`, `last_error`, `server_id`, `result` |
| `meta` | `device_id`, `since` cursor from the server, last full refresh time |

**Local effects are an overlay, not an edit of the cache.** Shown stock = server stock − Σ pending sale quantities; shown balance = server balance + Σ pending debts − Σ pending payments. An item's overlay is dropped only after a delta refresh that started after the item synced, so its effect is never counted twice or lost in between.

## 3. Sync protocol

### 3.1 Down: `GET /api/v1/sync/bootstrap?since=&cursor=`

- First run (no `since`): all products and customers of the store, 1000 rows a page by id cursor.
- Later: only rows changed since `since`. A customer counts as changed when the customer row, any of their debts or any of their payments changed (that is what moves the balance).
- Response carries `server_time`; the device stores it as the next `since`, so phone clock drift does not matter.
- Runs at sign-in, after each successful sync, on app resume, and every 5 minutes while online.

### 3.2 Up: `POST /api/v1/sync/batch`

```json
{ "device_id": "uuid",
  "items": [ { "client_transaction_id": "uuid", "seq": 41, "type": "sale",
               "occurred_at": "2026-10-29T09:00:00+02:00",
               "payload": { "...exact POST /sales body..." },
               "charged": [ { "product_id": 7, "sale_unit": null, "unit_price": "6.50" } ] } ] }
```

- Up to 50 items, in `seq` order. Response: one result per item, `applied | duplicate | flagged | conflict | rejected_validation`, with `server_id`, `flags` and `error` (05 §4.2).
- **It reuses the existing idempotency layer, not a copy of it.** Each item runs through `IdempotencyService::run` with key = `client_transaction_id`, the same `method_path` (`POST /api/v1/sales` or `POST /api/v1/customers/{id}/debts/pay-all`) and the same fingerprint function as `EnsureIdempotency` (moved to one shared method). Validation uses the same `StoreSaleRequest` / `PayAllDebtsRequest` rules, and the write uses the same `SaleService::create` / `PaymentService::payCustomer`.
- Consequence: a checkout whose online attempt timed out ("uncertain") moves into the queue **with its original key and body**. Whether the server got the first attempt or not, the sale exists exactly once (AC-06).
- Each item commits in its own transaction. A technical failure (5xx, timeout) stops the batch; the device retries from that item. Business outcomes never stop the batch.
- Payments are sent customer-level (as the mobile app does today), never against a debt id, so a payment queued after an offline credit sale needs no server id from it: FIFO guarantees the debt exists first.
- **Engine:** drains when the server is reachable, oldest first; backoff 5 s → 15 s → 60 s → 5 min on technical failures. A 401 keeps the queue and asks to sign in again (same account). An item failing technically more than 10 times is listed as "stuck" (D-18).

## 4. Conflict rules (server-authoritative, D-03)

An offline sale **happened** — the goods left the shop — so it is always recorded and flagged when something does not match. An offline payment that no longer fits is **held**, never applied blindly and never discarded (BR-10).

| Situation at sync | Result | What the manager sees on the web |
|---|---|---|
| Stock goes below zero | Sale recorded, `flagged` `NEGATIVE_STOCK` (same as online, D-27) | Flag to acknowledge; already in the negative-stock list |
| Credit limit exceeded, owner/manager confirmed the override offline | Sale recorded; `sale.credit_limit_overridden` audited with `offline: true` | Nothing extra (as online) |
| Credit limit exceeded but **not** confirmed (another till added debt meanwhile, or an employee sold within the limit the phone knew) | Sale recorded, `flagged` `CREDIT_LIMIT_EXCEEDED` | Flag to acknowledge |
| Price changed on the server after the phone's last refresh | **Decision A below** | Flag `PRICE_CHANGED` with both prices |
| Product deactivated after the phone's last refresh | Sale recorded, `flagged` `PRODUCT_INACTIVE` | Flag to acknowledge |
| Customer deactivated meanwhile | Sale recorded, `flagged` `CUSTOMER_INACTIVE` | Flag to acknowledge |
| Payment ≤ customer's current balance | Payment applied (oldest debt first), `paid_at` = `occurred_at` | — |
| Payment > current balance (paid elsewhere, or its sale was rejected) | `conflict`, stored in `sync_conflicts`, **not applied** | Resolve: apply to the customer's open debts / record as refund / void with reason |
| Invalid item (unknown product, malformed body, `occurred_at` outside the window) | `rejected_validation`, stored in `sync_conflicts` | Resolve: void with reason (re-enter by hand if it was real) |

**Offline checks on the phone mirror the online ones**, using cached data plus pending effects: an employee over the limit is blocked; an owner/manager gets the explicit override sheet (D-26); a walk-in sale must be fully paid (D-07); a payment cannot exceed the shown balance.

**Time (BR-08).** `occurred_at` becomes the invoice's `created_at` and the payment's `paid_at`, so dashboards and day totals count the sale on the day it happened. The arrival time is kept in a new `synced_at` column. The server accepts `occurred_at` from 30 days ago (the idempotency-key retention) to 10 minutes ahead; a due date is checked against the `occurred_at` day, not the sync day.

**Server tables.** New `sync_conflicts` (05 §1: `kind` `flagged`/`conflict`/`rejected`, `payload`, `reason`, `status` `open`/`resolved`, `resolution`, `resolved_by`, `resolved_at`, `UNIQUE(store_id, client_transaction_id)`). New nullable `invoices.synced_at`, `invoices.device_id`, `payments.synced_at`. A replay of a held item returns its stored result from `sync_conflicts`, so it is idempotent too.

## 5. Indicator and queue limit (FR-67, FR-68)

- **Indicator** on the app shell, always visible: «متزامن» (synced) · «جارٍ المزامنة…» (syncing) · «بانتظار المزامنة (n)» (pending n), plus «يحتاج مراجعة (n)» when items were held. It replaces today's plain offline banner; tapping it opens the sync screen (SCR-M-16): pending list, held items (read-only, resolved on the web), stuck items, "Sync now".
- **Reachability:** today's `serverReachableProvider` (set by every API call) plus a light probe with backoff while offline, and on app resume.
- **Limit:** at 800 unsynced items a persistent warning with "Sync now"; at 1000, new offline sales and payments are blocked with an explanation; reading and searching still work. The queue is never truncated.
- **Online behaviour:** with an empty queue and a reachable server, checkout and payment post directly as today (server receipt, same messages). While the queue is not empty, new writes join the queue behind it so the order stays FIFO, and the engine sends them at once.

## 6. Web: conflict review (SCR-W-18, US-1106)

A «المزامنة» page for owners and managers: open items first, filter by kind. Each row shows the device, cashier, `occurred_at`, the customer, the amount and the reason.

- Flagged sale → «تم الاطلاع» (acknowledge), with a link to the sale.
- Held payment → apply to the customer's open debts (only if it now fits), record as refund (the cash was handed back), or void with a reason.
- Rejected item → void with a reason.

Every resolution is audited as `sync.conflict_resolved`. Employees get a 403 on the endpoints and do not see the page. A count badge appears in the web navigation when open items exist.

## 7. Decisions needed

| # | Question | Recommendation |
|---|---|---|
| **A** | When the price changed after the phone's last refresh, which price does the offline sale record? | **The price the cashier charged**, sent in `charged`, flagged `PRICE_CHANGED` with both prices for review. Using the new server price would change the total after the customer paid, creating a debt on a walk-in sale or a wrong cash total. Only offline items may send prices; online `POST /sales` keeps ignoring them. |
| **B** | Local database | **`sqflite`** (CR-11), for the reasons in §2. |
| **C** | Held payment resolutions | The three from D-03, with "apply" meaning allocate to the customer's open debts oldest first (payments are customer-level). |
| **D** | Release | Full Shorebird release **1.3.0** (new native plugin); APK growth target ≤ 150 KB. |

## 8. Delivery and tests

| Part | Tests |
|---|---|
| Backend: `sync_conflicts` + columns, `/sync/bootstrap`, `/sync/batch`, conflict list and resolve endpoints, policy | TC-1101-01..04 (order, duplicate, payment conflict held, negative-stock flag), online-uncertain-then-batch exactly once, price/limit/inactive flags, `occurred_at` window, each resolution with audit, Employee 403 |
| Mobile: local store, bootstrap/delta, offline checkout and payment, engine, indicator, limit, sync screen | TC-1102-01, TC-1103-01..03, TC-1104-01..03 (10 items FIFO exactly once, interrupted sync, indicator states), TC-1105-01..02, local commit timing |
| Web: SCR-W-18 | Each resolution path, role hiding |

Out of this change: NFR-06 throttled-network measurement and the 10 k-product search benchmark on the real phone (they need the device; scripts are added for them), FR-69 location, FR-20 mobile stock adjustment.

## 9. Implementation (2026-10-29)

| Part | Where |
|---|---|
| Server: batch, bootstrap / delta, review list, resolutions | `SyncService`, `SyncController`, `sync_conflicts` migration; offline rules in `SaleService::create(…, OfflineSale)` |
| Phone: local store, overlay, queue limit | `mobile/lib/core/offline/offline_store.dart` (sqflite, one transaction per local commit) |
| Phone: engine, indicator, sync screen | `mobile/lib/features/sync/` (FIFO batches of 50, backoff, delta refresh), header pill, offline banner, SCR-M-16 |
| Phone: offline checkout and payment | `CheckoutController._queue`, `RecordPaymentScreen._queue`; logout refused while items wait |
| Web: SCR-W-18 | `frontend/src/pages/SyncReview.jsx`, «مراجعة المزامنة» in the sidebar with the open count |

Two details settled while building:

- **Online pay-all without an amount.** Offline, a "pay all" is queued with the amount the customer handed over, so a balance that grew on another till is never paid off with money nobody received. An attempt that may already have reached the server keeps its original body, so it still dedupes.
- **The cache on another account.** The catalog and customers are cleared at logout and when another store signs in; the queue stays, and logout is refused while it holds items.

Still to do before the release decision: the D-19 search benchmark with 10 k products and the NFR-06 throttled-network sync timing on the reference phone, and the APK size measured on a signed release build (expected growth: the sqflite Java plugin only, it uses Android's own SQLite).
