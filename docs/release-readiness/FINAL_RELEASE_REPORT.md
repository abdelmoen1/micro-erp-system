# Final release report — 2026-11-09

Worktree `micro-erp-system.worktrees/release-readiness`, branch `chore/release-readiness` (from
`main` @ 5307b9d). **Everything is uncommitted.** Nothing was deployed, pushed, uploaded or submitted;
production was not read or changed.

## Acceptance areas

| | Area | Status | Evidence |
|---|---|---|---|
| A | Backend and mobile security | **FIXED** (residuals BLOCKED/UNVERIFIED) | SECURITY_AUDIT.md (round 1 + round 2) |
| B | Store-level subscription architecture | **FIXED** | SUBSCRIPTION_ARCHITECTURE.md; `SubscriptionPlansAndOrdersTest` 13/13 |
| C | 14-day trial, expiry | **FIXED** | one trial per owner number (HMAC claims); lifecycle trial/active/expiring/expired/suspended; reminders command |
| D | Three configurable plans + feature permissions | **FIXED** (prices BLOCKED: owner) | plans seeded inactive/unpriced; admin editor; `entitled:` middleware + limits enforced server-side |
| E | WhatsApp manual request on the website | **FIXED** | plan picker on expired page and Settings; pending order + reference + wa.me message; verified in local browser preview; Playwright |
| F | Payment provider readiness | **FIXED (architecture)** / **BLOCKED (provider)** | PAYMENT_INTEGRATION_GUIDE.md; webhook pipeline tested with a test-only double; online payment disabled |
| G | Admin payment confirmation + audit history | **FIXED** | `/admin/subscriptions`; append-only payments/events; verified end-to-end in local preview |
| H | Account deletion in app + external page | **FIXED** (not deployed) | ACCOUNT_DELETION_PLAN.md; `AccountDeletionTest` 7/7; Flutter test; `/delete-account` previewed |
| I | Privacy Policy and Terms accuracy | **BLOCKED (owner + legal)** | drafts written from code; LEGAL_INFORMATION_REQUIRED.md |
| J | Platform-owner view of products, prices, suppliers, wholesale/retail | **PASS** (existing views) + **FIXED** (access logging) | `/admin/stores/{id}/products`, `/admin/products`, `/admin/suppliers[/{id}]`; `admin_access_logs`; disclosed in privacy draft §3 |
| K | Android API 36 and 16 KB | **PASS** (Flutter build) / UNVERIFIED (Shorebird engine) | round 1: merged manifest target 36 / min 24; every 64-bit `.so` ≥ 16 KB aligned |
| L | Permanent signing key readiness | **BLOCKED** | key only in CI secrets; local release builds refuse to sign without `key.properties`; no throwaway key used for anything distributable |
| M | Play declarations and reviewer access | **BLOCKED (owner)** | PLAY_CONSOLE_CHECKLIST.md |
| N | Tests on available devices/environments | see below | no Android device connected; no Bluetooth printer |

## Test results (actual runs, this round)

| Suite | Result |
|---|---|
| Backend PHPUnit, SQLite in-memory | **452 passed** (3474 assertions), 0 failed — was 432; +20 new (13 subscription, 7 deletion) |
| Backend PHPUnit, MySQL/MariaDB 10.4 parity (`phpunit.mysql.xml`, local disposable `hisbah_test` on port 3307) | **450 passed, 2 failed** (3465 assertions). First run caught a real bug in the new migration (MariaDB rejects a second non-null `TIMESTAMP` without default) → fixed with `dateTime`; then the 20 new tests pass on MariaDB and the migration rolls back and re-applies. The 2 remaining failures (`CollectionsTest::test_statement_running_balance_matches_summary`, `OfflineSyncTest::test_occurred_at_is_kept_as_the_business_time`) **fail identically on unmodified main** (`price-edit` worktree, f653ea3) against the same MariaDB 10.4 — pre-existing, not caused by this work; CI uses MySQL 8 |
| `composer validate` / `composer audit` | valid / no advisories |
| `flutter analyze` | no issues |
| `flutter test` | **234 passed, 6 skipped**, 0 failed (2 WhatsApp-CTA tests removed, 1 deletion test added; 2 tests rewritten to assert no payment CTA) |
| Web `npm run lint` / `npm run build` / `npm audit` | clean / built / 0 vulnerabilities |
| Playwright (`PW_CHANNEL=msedge`, API mocked) | **51 passed**, 0 failed (3 specs updated to the new intended UI) |
| Local browser preview (real API on disposable SQLite) | owner on expired page → plans → WhatsApp request (message checked) → admin moves request → confirms payment → activated 1 month, history complete; `/delete-account` renders; no console errors |
| Real Android device | **BLOCKED** — `adb devices` lists none |
| Bluetooth printer | **BLOCKED** — no hardware |
| Signed release AAB | **BLOCKED** — permanent key is CI-only (round 1 verified the pipeline with a throwaway key, then deleted it) |

## Answers

1. **Implemented:** store subscriptions (3 admin-managed plans, entitlements and limits enforced by the
   API, 14-day one-per-number trial, lifecycle, reminders), website plan picker with WhatsApp request,
   admin request/payment workflow with append-only payments and history, provider-independent payment
   layer (disabled), consumption-only Android build (payment CTAs removed), account deletion (app,
   website, public page, admin review, scheduled closure), ownership transfer API, admin access log,
   proxy-robust rate limits, data minimisation in the deletion audit, docs.
2. **Preserved:** all round-1 security fixes; sales, stock, debts, suppliers, purchases, returns,
   offline sync, printing, admin views; existing stores' trial dates; the manual admin subscription
   override; all 432 previous backend tests (two expectations updated intentionally).
3. **Tests:** see table — everything that ran passed; MySQL result above; device/printer/signed AAB blocked.
4. **Security left:** unencrypted backup dumps in GitHub history (S-1), production APP_KEY not compared
   (S-2, permission denied), DB grants unverified (S-4), CSP report-only (S-5), scheduler not running on
   Render free (P-4).
5. **Subscription system:** functional end-to-end locally (tests + browser). Not live: needs migration,
   deploy, prices, `WHATSAPP_BUSINESS_NUMBER`, a cron.
6. **Payment provider:** missing for each candidate — official integration docs, sandbox merchant ID/API
   key, webhook signing scheme and secret, status/refund API, currency rules.
7. **Legal:** LEGAL_INFORMATION_REQUIRED.md (operator identity, contacts, URLs, retention, refund policy,
   law, prices, age).
8. **Play Console:** PLAY_CONSOLE_CHECKLIST.md + OWNER_ACTIONS.md §F (account type/closed test, app signing
   choice, demo store, Data safety, IARC, audience, ads, financial features, listing, privacy & deletion URLs).
9. **Final signed AAB:** not safely possible here — the permanent key exists only in CI secrets. Merge,
   then run `mobile-release.yml` (full Shorebird release); check its AAB with the 16 KB script.
10. **What prevents submission today:** privacy policy/terms not published and URL not built into the
    app; this branch not merged/deployed (no `/delete-account` live, no migration); reviewer demo account;
    Play Console declarations; signed AAB from CI; device testing.
