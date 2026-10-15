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

Login throttling: after 5 failed attempts per email + IP within 60 s, `POST /login` returns 429 `TOO_MANY_REQUESTS` with `Retry-After`. A successful login resets the counter. `POST /register` and `POST /register/invitation` allow 5 requests/min per IP.

### Financial writes (idempotency, US-0101)

Endpoints: `POST /payments`, `POST /customers/{id}/debts/pay-all`, `POST /debts`, `POST /invoices`, `POST /payments/{id}/reverse`, `POST /payment-groups/{id}/reverse`.

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
