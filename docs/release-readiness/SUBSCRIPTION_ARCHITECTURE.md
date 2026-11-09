# Subscription architecture

Implemented on `chore/release-readiness` (2026-11-09). Uncommitted, not deployed, production not
migrated. Tests: `backend/tests/Feature/SubscriptionPlansAndOrdersTest.php` (13 tests).

## Model

```
Hisbah website  = sign-up, plan purchase (online provider when one exists, or a WhatsApp request)
Android (Play)  = sign-in and use of what the store already has (consumption-only: no purchase UI)
Laravel API     = the only place that decides access, entitlements, prices and activation
```

The subscription belongs to the **store**. The owner orders; every member gets what the store has.
No automatic renewal: the owner renews by hand before or after expiry.

## Data (migration `2026_11_09_000001_create_subscriptions_payments_and_deletion.php`)

| Table / column | Purpose |
|---|---|
| `subscription_plans` | `monthly` (1 month), `semiannual` (6), `annual` (12). `price` + `currency` NULL and `is_active` false until the platform admin sets them — **no prices were invented**. `features` (NULL = all), `limits` (`max_employees`, `max_products`; NULL = none), `description`, `sort_order` |
| `stores.subscription_plan_id` | the plan of the current paid period (NULL = trial, or activated by hand before plans existed → all features) |
| `stores.trial_started_at` / `trial_ends_at` | trial window (existing column `trial_ends_at` kept; start backfilled from `created_at`) |
| `stores.expiry_notice_for` | the expiry a notice was recorded for (one notice per period) |
| `trial_claims` | HMAC-SHA256 (keyed by `APP_KEY`) of each owner number that used its trial; survives store deletion. Backfilled for every existing owner |
| `subscription_orders` | one request: reference `HSB-XXXXXXXXXX`, store (nullable after deletion) + `store_name` snapshot, plan snapshot, **server price at request time**, channel `manual_whatsapp`/`online`, provider, status, reviewer, paid/activated timestamps, period start/end |
| `subscription_payments` | **append-only** (model refuses update/delete): kind `payment`/`refund`/`reversal`, source `manual`/`provider`, amount, currency, method, transaction reference, who recorded it. No card data |
| `subscription_order_events` | **append-only** history: created, status change, note, payment, activated, provider event; actor + time |

## Lifecycle

`GET /subscription` returns `state` (legacy: trial/active/expired/inactive), `lifecycle`, `days_left`,
`entitlements {features, limits, plan}`.

```
trial ──(≤ HISBAH_EXPIRING_DAYS left)──▶ expiring ──▶ expired
active ─(≤ HISBAH_EXPIRING_DAYS left)──▶ expiring ──▶ expired
any ──(platform admin suspends the store)──▶ suspended   (separate `stores.status`)
```

- **Trial:** 14 days (`HISBAH_TRIAL_DAYS`, default changed 7 → 14; `render.yaml` too). Once per owner
  number: deleting the store and registering again with the same number gives `has_access=false`
  immediately. Existing stores keep their current trial dates (nothing reset).
- **After expiry:** business routes return `403 SUBSCRIPTION_EXPIRED`; still open: `/me`, `/logout`,
  `/subscription`, `/subscription/plans|orders`, support tickets, password/phone change,
  `/me/deletion`, ownership transfer. Data is untouched.
- **Notices:** `php artisan hisbah:subscription-reminders` (scheduled hourly) records one
  `subscription.expiring_notice` audit row per store per period; clients show `lifecycle: expiring`.
  SMS/WhatsApp delivery is **not wired** (needs a gateway). ⚠ Render's free web service does not run
  Laravel's scheduler — see OWNER_ACTIONS.md.

## Ordering and activation

1. Owner → `POST /subscription/orders {plan_id, channel}` (owner only; 10/min; max 3 open orders; the
   same open request is returned if asked twice). Price/currency copied from the plan **on the server**.
2. `manual_whatsapp` → status `pending_contact`, response includes `whatsapp_url`:
   `https://wa.me/<WHATSAPP_BUSINESS_NUMBER>?text=` store name, plan, duration, price + currency,
   reference. No password, token or phone number. Without `WHATSAPP_BUSINESS_NUMBER` the request is
   still created and the page asks to quote the reference.
3. Platform admin → `/admin/subscriptions`: move `pending_contact ⇄ awaiting_payment ⇄
   payment_verification`, or `rejected` / `cancelled`; add notes. **None of these activates.**
4. `POST /admin/subscription-orders/{id}/confirm-payment` with method, transaction reference, amount,
   currency and `payment_verified: true` (the admin attests they checked the money arrived). Amount and
   currency must equal the order (`409 PAYMENT_AMOUNT_MISMATCH` otherwise). Inside one transaction with
   row locks: payment row → activation → events → audit.
5. **Renewal arithmetic:** new period starts at the later of *now*, the current paid expiry, and the end
   of a running trial; ends start + plan months (`addMonthsNoOverflow`). So an active subscription is
   extended from its expiry; an expired one starts at confirmation.
6. **Duplicates:** a second confirmation → `409 ORDER_ALREADY_ACTIVATED`; a repeated provider
   transaction → no-op (`duplicate`).
7. The existing manual override `POST /admin/stores/{store}/subscription` stays for authorised
   intervention (audited).

## Entitlements (server-enforced)

| Feature code | Enforced on |
|---|---|
| `staff` | `POST /invitations` |
| `suppliers` | `POST /purchases`, `POST /purchases/{id}/returns`, `POST /suppliers/{id}/payments` (history stays readable) |
| `csv_import` | `POST /products/import` |

| Limit | Enforced on |
|---|---|
| `max_employees` | creating and accepting invitations (active non-owner members) |
| `max_products` | creating/importing products (active products) |

Middleware `entitled:<feature>` → `403 FEATURE_NOT_IN_PLAN`; limits → `403 PLAN_LIMIT_REACHED`.
Core selling, products, customers, debts, offline sync and the dashboard are in every plan. The
three seeded plans grant **all** features with **no** limits until the owner decides otherwise, so
nothing changes for existing shops. Clients read `entitlements` from `/subscription`; hiding a
button is never the protection.

## Configuration

`HISBAH_TRIAL_DAYS=14`, `HISBAH_EXPIRING_DAYS=3`, `HISBAH_DELETION_GRACE_DAYS=14`,
`WHATSAPP_BUSINESS_NUMBER=[OWNER INPUT REQUIRED]`, `PAYMENT_CURRENCIES=ILS,USD,JOD`, provider flags
(PAYMENT_INTEGRATION_GUIDE.md). Plans are edited at `/admin/subscriptions → الباقات` — no app update.

## Not done / decisions left

- Prices, currencies, descriptions and which features each plan includes — **owner**.
- Expiry notices by SMS/WhatsApp — needs a gateway decision.
- Plan *downgrade* mid-period is not modelled: a new order starts after the current period.
- Refund/reversal rows exist in the schema; no admin UI to record them yet.
