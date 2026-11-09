# Hisbah (حسبة) — Privacy Policy (DRAFT v2)

> **Draft for the owner and a legal reviewer. Not published. Not legal advice. No certification or
> legal compliance is claimed.** Every `[OWNER INPUT REQUIRED]` must be filled from
> LEGAL_INFORMATION_REQUIRED.md. Publish in Arabic (primary) and English at a public HTTPS URL
> without sign-in, link it in the app (build with `PRIVACY_POLICY_URL`), on the website, and in
> Play Console. Written from the code on `chore/release-readiness` (2026-11-09); update it whenever
> data use changes.

**Effective date:** [OWNER INPUT REQUIRED]
**Operator ("Hisbah", "we"):** [OWNER INPUT REQUIRED — legal name], [OWNER INPUT REQUIRED — address]
**Privacy contact:** [OWNER INPUT REQUIRED — e-mail] · [OWNER INPUT REQUIRED — WhatsApp/phone]
**Covers:** the Hisbah Android app (`com.hisbah.smartshop`), the Hisbah website
[OWNER INPUT REQUIRED — URL], and the Hisbah API.

## 1. Who uses Hisbah
Bookkeeping and point-of-sale software for small shops, used by **store owners and their staff**.
Not intended for children. [OWNER INPUT REQUIRED — minimum age, proposed 18]

Shops also record information about **their own customers and suppliers**. The shop decides what to
record; Hisbah stores and processes it to provide the service. [OWNER INPUT REQUIRED — legal reviewer
to confirm the controller/processor roles.]

## 2. What we collect

| Category | Data | Source | Purpose |
|---|---|---|---|
| Account | name, mobile number, password (stored only as a one-way hash), role (owner / manager / employee), account status | you, or the owner's invitation | sign-in, permissions |
| Store | store name, phone, address, area, optional map coordinates you type in, time zone | owner | identify the store, receipts |
| Products & inventory | names, barcodes, units, quantities, stock movements, **cost prices**, **selling prices**, pack sizes and prices, low-stock levels | you and your staff | inventory and sales |
| Suppliers & purchasing | supplier names and contact details, purchase invoices, **wholesale prices** per product, supplier payments and returns, balances owed | you and your staff | purchasing records |
| Sales & accounting | invoices, items, discounts, payment method recorded, returns, customer debts and payments, credit limits, offline-sale records | you and your staff | bookkeeping |
| Your customers | names, mobile numbers, addresses, notes, balances | you and your staff | the shop's customer accounts |
| Employees & permissions | staff names, numbers, roles, invitations, who recorded which operation | owner and staff | access control, history |
| Subscription & payments | plan, period, order reference, amount, currency, payment method and transaction reference **as recorded by Hisbah staff or reported by a payment provider**; never card numbers or wallet PINs | you, Hisbah staff, payment provider | selling and activating subscriptions |
| WhatsApp-assisted requests | if you choose "contact us through WhatsApp", WhatsApp opens with a prepared message (store name, plan, duration, price, request number). The conversation then happens on WhatsApp, under WhatsApp's terms; we record the payment details we verify | you | manual subscription purchase and support |
| Support | ticket subject, details, our replies | you | support |
| Security & audit | who changed what and when; request IP address and device/browser description; one-time SMS codes (hashed) with the requesting IP; log of platform-administrator access to store data | generated | security, fraud prevention, history |
| Trial use | a keyed one-way hash of the owner's mobile number | generated | one free trial per number |
| On the phone | session token in Android encrypted storage; offline copy of products, customers and unsent sales; random installation ID for sync | the app | stay signed in, sell offline |
| Camera | used only to read barcodes on the phone; images are not stored or uploaded | your camera, only when you open the scanner | scanning |
| Bluetooth | list of printers already paired with your phone; not used to find your location | your phone, only when printing | receipts |
| Notifications | the app does not send push notifications [update if added] | — | — |

We do **not** collect your phone's location, contacts, photos or files, or advertising IDs, and the
app shows **no advertising**.

## 3. Platform-owner access
Hisbah's platform administrators (the operator's own staff with a platform-admin account; ordinary
store managers and Hisbah support accounts do not have it) can view, **read-only**, for every store:
store details and status, members and contact numbers, products with barcodes, quantities, cost and
selling prices, suppliers and the products each supplied with wholesale and selling prices, purchase
relationships, subscription status and orders, and support tickets. They can change a store's account
status and subscription, confirm payments, and delete a store on request. Every platform-admin
request is logged (administrator, time, store, IP). Purpose: operating, supporting and billing the
service, preventing abuse, and [OWNER INPUT REQUIRED — any other purpose, e.g. aggregated market
insight; if used, describe it and how it is anonymised].

## 4. Service providers
| Provider | Role | Data |
|---|---|---|
| Render | API hosting — [OWNER INPUT REQUIRED: region, config says Frankfurt] | all, in processing |
| Aiven | database hosting — [OWNER INPUT REQUIRED: cloud/region] | all stored data |
| Vercel | website hosting; relays website API calls | web traffic |
| GitHub | private repository holding nightly database backups; app download hosting | all stored data (backups) |
| Shorebird | app updates; the app checks it for updates | app version, a random install identifier [verify with Shorebird] |
| Google ML Kit (on device) | barcode reading; Google receives diagnostic data about the feature, not images | device model, OS, app version, performance |
| Google Play | distribution | per Google's policy |
| WhatsApp (Meta) | only if you choose WhatsApp | what you send there |
| [OWNER INPUT REQUIRED — payment provider, when chosen] | online payment | per the provider |
| [OWNER INPUT REQUIRED — SMS gateway, only if SMS codes are switched on] | one-time codes | number, code |

We do not sell personal data or share it for advertising.

## 5. Retention
- While the store account exists: kept.
- Staff account deletion: personal fields removed immediately; the shop's records remain under
  «حساب محذوف».
- Store closure: everything of the store is deleted after the grace period (14 days).
- Kept after deletion: Hisbah's own subscription orders and payment records (store name, amounts,
  references) for [OWNER INPUT REQUIRED — period, legal basis]; a one-way hash of the owner number to
  prevent repeated free trials for [OWNER INPUT REQUIRED]; the deletion request record with a masked
  number for [OWNER INPUT REQUIRED]; platform-admin access logs for [OWNER INPUT REQUIRED].
- Backups: up to [OWNER INPUT REQUIRED] days. Server logs: per hosting provider.

## 6. Deleting your account
In the app: «المزيد» → «حذف الحساب». On the website: الإعدادات → «حذف الحساب». Without the app:
**[OWNER INPUT REQUIRED — public URL]/delete-account**. See section 5 for what is kept.

## 7. Security
HTTPS for all traffic; passwords hashed (bcrypt); per-store data isolation enforced on the server;
rate limits on sign-in and sensitive actions; app data excluded from Android backups; administrator
access logged. No system is perfectly secure; report issues to [OWNER INPUT REQUIRED].

## 8. Your rights
View and correct your data in the app/website, export [OWNER INPUT REQUIRED — export feature not
built], delete your account. [OWNER INPUT REQUIRED — rights under applicable law after legal review.]

## 9. Changes and contact
Changes are posted here with a new effective date. Contact: [OWNER INPUT REQUIRED].
