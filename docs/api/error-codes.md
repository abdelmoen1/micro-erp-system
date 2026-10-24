# API v1 — Error Envelope and Codes

Contract freeze for US-0106 (2026-10-13). Clients (Flutter, React) map **`code`**, never `message` text.
Any change here updates [`auth.http`](auth.http), the Flutter error mapping (US-1304) and the design state matrix (US-1505) in the same change.
`ErrorCodeContractTest` fails if the backend throws a code that is not listed below.

## Envelope

Every error response under `/api/v1` has this shape and the `X-Correlation-ID` header:

```json
{
  "message": "Arabic, user-presentable text",
  "code": "MACHINE_READABLE_CODE",
  "errors": { "field": ["message", "..."] },
  "correlation_id": "01M4TX2BQ5JA9MSMRA877EFV4Y"
}
```

- `errors` is always an object; it is `{}` when there are no field errors.
- `correlation_id` equals the `X-Correlation-ID` response header. A client may send its own `X-Correlation-ID` (8–64 characters: letters, digits, `-`); otherwise the server generates one. Unexpected errors (5xx) are logged server-side with the same ID.
- Successful object responses carry `meta.currency = "ILS"`. Money values are decimal **strings** (e.g. `"12.50"`), never numbers.

> **Known gap (DEF-19):** Laravel's built-in validation messages (`VALIDATION_FAILED`) are currently in English because the backend locale is `en` and no Arabic validation translations exist. Messages written by the application (all other codes) are Arabic. Clients must validate input locally and show their own Arabic text; server field errors are a fallback.

## Codes

### Generic (any endpoint)

| HTTP | `code` | Meaning | Client behaviour |
|---|---|---|---|
| 400 | `BAD_REQUEST` | Malformed request | Show generic error |
| 401 | `UNAUTHENTICATED` | Missing, invalid, revoked or **expired** token (tokens expire after 30 days) | Clear the stored token; go to login; return to the same place after re-login |
| 403 | `FORBIDDEN` | The role is not allowed to do this (role matrix, US-0105) | Show "not allowed"; do not retry |
| 404 | `NOT_FOUND` | Unknown route, or a record that does not exist **or belongs to another store** | Show "not found" |
| 405 | `METHOD_NOT_ALLOWED` | Wrong HTTP method | Developer error |
| 409 | `CONFLICT` | Generic conflict | Show error |
| 419 | `SESSION_EXPIRED` | Framework session/CSRF expiry (not used by token clients) | Treat as 401 |
| 422 | `VALIDATION_FAILED` | Field validation failed; see `errors` | Show inline field errors |
| 422 | `BUSINESS_RULE_VIOLATION` | Generic business-rule rejection without a specific code | Show `message` |
| 428 | `PRECONDITION_REQUIRED` | Generic precondition failure | Developer error |
| 429 | `TOO_MANY_REQUESTS` | Rate limited. `Retry-After` header (seconds) is present; on login `errors.retry_after[0]` too | Disable the action and show a countdown from `Retry-After` |
| 5xx | `SERVER_ERROR` | Unexpected error; no details leaked | Show generic error with `correlation_id` for support |
| other | `HTTP_<status>` | Fallback for an unmapped status | Show generic error |

### Authentication and account

| HTTP | `code` | Where | Client behaviour |
|---|---|---|---|
| 401 | `INVALID_CREDENTIALS` | `POST /login` | "Email or password is incorrect"; keep the email field |
| 403 | `USER_INACTIVE` | `POST /login` with correct password; **any** authenticated call by a deactivated user (the token is revoked at the same time) | Clear the token; show the "account deactivated" screen |
| 403 | `STORE_REQUIRED` | Any authenticated call by a user with no store | Show error; contact support |
| 403 | `SUBSCRIPTION_EXPIRED` | Any **business** route (everything except `POST /logout`, `GET /me`, `GET /subscription`) for a store whose 7-day trial has ended without a valid paid subscription, or whose paid subscription passed its expiry. Sign-in still works. `details`: `state` (`expired`/`inactive`), `has_access`, `trial_ends_at`, `subscription_expires_at`, `trial_days_left`, `support_whatsapp` (digits or null). No data is changed; access returns as soon as the platform admin activates the subscription. A suspended store gets `STORE_SUSPENDED` instead | Show the "subscription expired" screen with the WhatsApp contact (when `support_whatsapp` is set); keep the session; offer "check again" (`GET /subscription`) |
| 403 | `STORE_SUSPENDED` | `POST /login`, `POST /auth/google` or `POST /register/invitation` for a store the platform admin suspended; **any** store route called with an earlier token (the token is kept, so access returns on reactivation) | Show "store suspended, contact Hisbah"; do not retry |
| 401 | `GOOGLE_TOKEN_INVALID` | `POST /auth/google`: the Google ID token is invalid, expired, unverified or for another client | Show `message`; offer the Google button again |
| 503 | `SSO_UNAVAILABLE` | `POST /auth/google`: `GOOGLE_CLIENT_ID` is not set, or Google could not be reached | Show `message`; email sign-in still works |

Google sign-in: `POST /auth/google {credential}` returns `{user, token}` for a known account (linked by email on first use) or `{onboarding: {token, name, email}}` for a new one; `POST /register/google {onboarding_token, store_name, owner_name, …}` then creates the store (token valid 30 min). `/auth/google` allows 10 requests/min per IP.

Login throttling: after 5 failed attempts per email + IP within 60 s, `POST /login` returns 429 `TOO_MANY_REQUESTS` with `Retry-After`. A successful login resets the counter. `POST /register` and `POST /register/invitation` allow 5 requests/min per IP.

### Financial writes (idempotency, US-0101)

Endpoints: `POST /payments`, `POST /customers/{id}/debts/pay-all`, `POST /debts`, `POST /sales`, `POST /sales/{id}/void` (alias `POST /invoices/{id}/void`), `POST /payments/{id}/reverse`, `POST /payment-groups/{id}/reverse`, `POST /stock-adjustments`. The legacy `POST /invoices` is removed (US-0501).

| HTTP | `code` | Meaning | Client behaviour |
|---|---|---|---|
| 428 | `IDEMPOTENCY_KEY_REQUIRED` | No `Idempotency-Key` header | Developer error: always send one |
| 422 | `IDEMPOTENCY_KEY_INVALID` | Key is not a UUID | Developer error |
| 409 | `IDEMPOTENCY_KEY_REUSED` | Same key, different request body | Generate a new key only if the user changed the operation |

A repeated request with the same key and body returns the **original** status and body, with `Idempotent-Replay: true`. The client keeps the key until it receives a response (including across an app restart) and retries with the same key.

### Debts and payments

| HTTP | `code` | Meaning |
|---|---|---|
| 422 | `DEBT_ALREADY_PAID` | The debt has no remaining amount |
| 422 | `PAYMENT_EXCEEDS_REMAINING` | Amount is larger than the remaining debt (`errors.amount`) |
| 422 | `NOTHING_TO_PAY` | Pay-all on a customer with nothing outstanding |
| 422 | `PAYMENT_ALREADY_REVERSED` | The payment or payment group is already reversed |
| 422 | `REVERSE_GROUP_REQUIRED` | `POST /payments/{id}/reverse` on a payment that belongs to a pay-all group (D-11, DEF-10). `details.payment_group_id` names the group; reverse it with `POST /payment-groups/{id}/reverse` |

### Products and stock

| HTTP | `code` | Meaning |
|---|---|---|
| 422 | `INSUFFICIENT_STOCK` | A stock **adjustment** would make the product's stock negative (`errors.quantity` gives the current stock). Nothing is written. A **sale** never returns this code (D-27: see the `NEGATIVE_STOCK` warning below) |
| 422 | `IMPORT_INVALID` | `POST /products/import` (US-0408): the CSV has errors, or a missing header / no rows / more than 2000 rows. Nothing is imported. `details.errors` lists `{row, column, message}` (first 200) |

### Sales (US-0501 – US-0503, [`sales.http`](sales.http))

| HTTP | `code` | Meaning | Client behaviour |
|---|---|---|---|
| 422 | `CREDIT_LIMIT_EXCEEDED` | An **Employee**'s credit or partial sale would take the customer above the credit limit. Nothing is written. `details` = `{credit_limit, outstanding, new_debt, balance_after, can_override: false}` | Show the amounts; ask an Owner / Manager, or take more payment |
| 422 | `CREDIT_LIMIT_CONFIRMATION_REQUIRED` | An **Owner / Manager**'s sale would exceed the limit. Nothing is written. Same `details`, with `can_override: true` | Show the warning; if confirmed, resend the same sale with `confirm_over_limit: true` and a **new** `Idempotency-Key` (the body changed). The override is audited |
| 422 | `INVOICE_IMMUTABLE` | `PATCH /sales/{id}` tried to change a financial field (items, totals, customer, payment). Only `notes` are editable (D-06) | Offer void or return instead |
| 409 | `INVOICE_ALREADY_VOIDED` | The sale is already voided; nothing is reversed twice | Refresh the sale |
| 409 | `INVOICE_HAS_PAYMENTS` | The sale's debt has live (non-reversed) payments | Reverse the payments first, then void |
| 409 | `INVOICE_HAS_RETURNS` | Goods were returned against the sale | Voiding is not possible; use returns |
| 409 | `INVOICE_NOT_VOIDABLE` | The record is an opening debt, not a sale | Manage it from the debts screens |
| 422 | `INVOICE_VOIDED` | `POST /sales/{id}/returns` on a voided sale (US-0601 AC5). Nothing is written | Refresh the sale |
| 422 | `INVOICE_NOT_RETURNABLE` | `POST /sales/{id}/returns` on an opening debt, which has no goods | Manage it from the debts screens |

Field rules on `POST /sales` come back as `VALIDATION_FAILED` with these `errors` keys: `items.N.product_id` (unknown, other store's or inactive product), `items.N.quantity` (a fraction for a `piece` product, more than 3 decimals, or ≤ 0), `paid_amount` (above the total, more than 2 decimals), `payment_method` (missing while `paid_amount > 0`), `customer_id` (missing while something stays unpaid, D-07), `due_date` (in the past in the store timezone, or sent for a fully paid sale).

#### Warning flags (successful responses)

A `201` from `POST /sales` carries `flags` (a list of codes) and `warnings` (one object per affected line). Flags never block the sale.

| Flag | Meaning | Client behaviour |
|---|---|---|
| `NEGATIVE_STOCK` | The sale took a product below zero (D-27). Each warning has `product_id`, `name` and `balance_after` | Show a non-blocking notice on the receipt; managers review negative stock later |

### Optional `details`

A few codes add a `details` object to the envelope with machine-readable facts (today only the two credit-limit codes). Clients that do not need it can ignore it.
