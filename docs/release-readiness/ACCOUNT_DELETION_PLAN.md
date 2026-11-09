# Account deletion — implemented

Status: **FIXED in code** (uncommitted; production not migrated). Tests:
`backend/tests/Feature/AccountDeletionTest.php` (7), plus Flutter test
`account deletion opens from the renewal screen and needs the password`. Nothing was deleted on
production; all deletion tests use isolated SQLite/MySQL test databases.

## Where users delete

| Where | How |
|---|---|
| Android app | «المزيد» → «حذف الحساب» (`mobile/lib/features/more/presentation/delete_account_screen.dart`), also from the subscription-expired screen. Password (+ store name for owners). Refused while unsynced offline sales are on the phone |
| Website, signed in | الإعدادات → «حذف الحساب» (`frontend/src/pages/Settings.jsx`); owner can cancel a scheduled closure there |
| Website, public, no app, no session | **`/delete-account`** (`frontend/src/pages/DeleteAccount.jsx`): number + password does the same as the app; "I forgot my password" files a request a platform admin verifies by hand; a request number shows its status |
| Platform admin | `/admin/deletions`: approve (after verifying identity outside the system) or reject manual requests |

API: `GET/POST/DELETE /api/v1/me/deletion`, `POST /api/v1/account-deletion` (public, throttled),
`GET /api/v1/account-deletion/{uuid}` (status only), `POST /api/v1/my-store/transfer-ownership`,
`GET/PATCH /api/v1/admin/deletion-requests`.

## What happens

### Staff (manager / employee) — immediate anonymisation
`AccountDeletionService::deleteStaff()` in one transaction: all tokens and sessions revoked, pending
SMS codes for the number deleted, `name` → «حساب محذوف», `phone`, `email`, `password`, `google_id`,
`phone_verified_at` → NULL, `status` → inactive. The user row stays because sales, payments, stock
movements and audit rows reference it (`audit_logs.user_id` is `restrictOnDelete`); it no longer
identifies anyone. The number can register again.

### Owner — store closure with a grace period
`closeStore()`: store name must be typed; `stores.deletion_scheduled_for` = now + 14 days
(`HISBAH_DELETION_GRACE_DAYS`); **every member's tokens revoked**; members cannot sign in
(`403 STORE_CLOSING`); the owner can sign in only to see and cancel (`DELETE /me/deletion`).
`php artisan hisbah:process-deletions` (hourly) then runs the existing `StoreDeletionService`:
members, customers, suppliers, products, stock movements, sales + items, returns, debts, payments,
purchases, purchase returns, supplier payments, idempotency keys, the store's audit history,
invitations, support tickets, sync conflicts, pending SMS codes, tokens, sessions — then the store.
Explicit, child-first, one transaction; nothing relies on a blind cascade.

Alternative to closing: **transfer ownership** to an active manager, then delete one's own account
as staff (API ready; no web/app button yet).

A platform admin's own store/account cannot be deleted this way (`409`).

## What is kept, and why

| Kept | Why | Personal data in it | How long |
|---|---|---|---|
| `subscription_orders`, `subscription_payments`, `subscription_order_events` of the deleted store (store id cleared, store name kept) | Hisbah's own sales / accounting records | store name; names of the Hisbah admins who handled it | **[OWNER INPUT REQUIRED]** — per tax law |
| `trial_claims` row | prevents repeated free trials (fraud prevention) | HMAC of the owner number only (not reversible without the server key) | **[OWNER INPUT REQUIRED]** |
| `account_deletion_requests` row | proof the request was handled | masked number (`059****567`), store name, reason text | **[OWNER INPUT REQUIRED]** |
| One `platform.store_deleted` audit row (admin-initiated deletions) | proof of the admin action | store name, **masked** numbers, owner id (name no longer stored — changed on this branch) | **[OWNER INPUT REQUIRED]** |
| `catalog_products` the store contributed | shared product catalogue (name, barcode) | none (`created_by` set NULL) | indefinitely |
| `admin_access_logs` | security log of platform-admin reads | admin id, IP | **[OWNER INPUT REQUIRED]** |
| Nightly DB backups (GitHub `hisbah-db-backups`) | disaster recovery | everything, until rotated | 90 days in the folder, **forever in git history** — see REMAINING_BLOCKERS S-1 |
| Hosting logs (Render, Vercel) | operations | IP, URLs | provider retention |

A staff member's past sales stay in the shop's books: the shop needs them, and they no longer name
the person. This must be stated in the privacy policy (it is, in the draft).

## Owner decisions still needed

1. Retention periods for each "kept" row above, and the legal basis (Palestine and other markets).
2. Whether 14 days is the right grace period.
3. Backups: encrypt, and decide how deleted users disappear from backups (expiry of encrypted
   backups, or history rewrite of the backup repo).
4. Whether to add an ownership-transfer button in the app/web (API exists).
