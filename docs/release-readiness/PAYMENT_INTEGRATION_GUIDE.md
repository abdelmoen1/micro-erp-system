# Payment integration guide (PalPay · Jawwal Pay · Bank of Palestine)

**Status: architecture ready, no provider integrated, online payment disabled.** No provider
documentation or credentials were available in the project, so no endpoint, signature scheme,
request format or response was assumed, and no fake gateway exists in the application. Real
payments are not processed.

## What exists

| Piece | File |
|---|---|
| Provider contract | `backend/app/Services/Payments/PaymentProvider.php` — `createCheckout(order, returnUrl)`, `parseWebhook(request)` (must verify authenticity), `fetchStatus(order)` |
| Value objects | `CheckoutSession`, `PaymentNotification` (`paid` / `failed` / `pending`), `InvalidPaymentNotification` |
| Registry | `PaymentProviderRegistry` — a provider is offered only when `enabled=true` **and** `driver` is a class implementing the contract |
| Webhook endpoint | `POST /api/v1/payments/webhooks/{provider}` (no auth; 120/min) → 404 until enabled; 400 on a bad signature |
| Processing | `PaymentWebhookProcessor` → `SubscriptionService::confirmProviderPayment()` — order must exist, belong to that provider, be open; amount and currency must match exactly; idempotent per provider transaction; activation in the same DB transaction |
| Config | `backend/config/payments.php`, env `PALPAY_*`, `JAWWAL_PAY_*`, `BOP_GATEWAY_*` (`ENABLED`, `DRIVER`, `MODE`, `MERCHANT_ID`, `API_KEY`, `WEBHOOK_SECRET`, `BASE_URL`) |
| Tests | `SubscriptionPlansAndOrdersTest::test_verified_provider_notifications_activate_once_and_forgeries_change_nothing` uses a **test-only** HMAC double in `tests/Support/HmacTestProvider.php` (never registered by the app) to prove: forged signature → 400 and nothing changes; wrong amount → 409 and nothing changes; valid → activated once; replay → `duplicate` |

Manual (WhatsApp) and provider payments are distinguishable: `subscription_payments.source`
(`manual` / `provider`) and `subscription_orders.channel`.

## To add a provider (after the owner supplies documents and sandbox credentials)

1. Obtain from the provider, in writing: merchant onboarding, sandbox base URL, how a payment is
   created (hosted page / redirect / wallet push), the exact webhook/callback format, **how it is
   authenticated** (HMAC header? signed JWT? IP allow-list? mutual TLS?), the status query API,
   refund API, currencies (ILS/JOD/USD), amount format (minor units?), idempotency rules, retry policy.
2. Write `app/Services/Payments/Providers/<Name>Provider.php` implementing `PaymentProvider` **only from
   that documentation**. Never trust the browser return URL: confirm with `fetchStatus()` or the
   verified webhook.
3. Unit-test signature verification with the provider's published test vectors; feature-test with
   recorded sandbox payloads.
4. Set `<PREFIX>_ENABLED=true`, `<PREFIX>_DRIVER=<class>`, `<PREFIX>_MODE=sandbox`, secrets in
   Render (never in git). Register the webhook URL
   `https://<api-host>/api/v1/payments/webhooks/<key>` with the provider.
5. Run the full sandbox matrix (paid, failed, cancelled, duplicate, wrong amount, late webhook) before
   `MODE=live`.
6. Update the privacy policy and the Play Data safety form if the provider receives user data.

## Rules that stay true

- Never store card numbers, CVV, wallet PINs or provider passwords. Store only references.
- A provider "success" redirect alone never activates anything.
- One activation per order; one payment row per provider transaction.
- Refunds/reversals are new append-only rows (`kind=refund|reversal`), never edits.
- Online payment is a **website** feature. The Google Play build never shows it (consumption-only).

## Regional expansion

Currencies are a config list; plans carry their own currency; providers are keyed and pluggable.
Saudi Arabia / UAE would add providers (e.g. card acquirers) the same way, plus per-country tax
invoices — not designed yet.
