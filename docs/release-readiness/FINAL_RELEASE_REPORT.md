# Final release report — 2026-11-10

`main` @ 2f6b860 (PRs #47, #48, #49 merged). Nothing was uploaded to Google Play or submitted;
production API and database were not changed. Statuses: **READY**, **BLOCKED**,
**OWNER ACTION REQUIRED**, **NOT VERIFIED**.

## Release 1.5.0+8 (Shorebird, Android) — READY

| Check | Result | Evidence |
|---|---|---|
| Shorebird release | **READY** — `Published Release 1.5.0+8!` | run [42824229659](https://github.com/abdelmoen1/micro-erp-system/actions/runs/42824229659), Flutter 3.47.7; tag `android-1.5.0_8` → 2f6b860 (patch baseline) |
| Signed AAB | **READY** — 45.4 MB, `jarsigner`: jar verified | workflow artifact `hisbah-android-aab-1.5.0+8` (kept 30 days); local copy `C:\Users\hp\Documents\hisbah-releases\1.5.0_8\aab\hisbah-1.5.0_8.aab`, SHA-256 file alongside, checksum OK |
| APK for device testing | **READY** — 28.4 MB, APK signature v2 verifies | private draft release `android-1.5.0_8`; local copy `…\1.5.0_8\apk\hisbah-1.5.0_8.apk`, checksum OK |
| Application ID / version | **READY** — `com.hisbah.smartshop`, versionCode 8, versionName 1.5.0 | `aapt2 dump badging` |
| Target / compile SDK | **READY** — target 36, compile 36 | `aapt2 dump badging` |
| Permanent signing key | **READY** — CN=Hisbah Smart Shop, O=Hisbah, cert SHA-256 `d4c70c9b…57c52bc6`, the **same certificate as release 1.4.0+7** (installs over it) | `apksigner`, `keytool -printcert -jarfile`, both release logs |
| 16 KB page size | **READY** — every 64-bit `.so` in the AAB has PT_LOAD alignment ≥ 0x4000 (libflutter/libapp 0x10000); APK `zipalign -c -P 16` OK | ELF header check of `base/lib/arm64-v8a/*.so` |
| Manifest | **READY** — allowBackup=false, dataExtractionRules, BLUETOOTH_SCAN `neverForLocation`, legacy Bluetooth maxSdk 30; no location, SMS, contacts or notification permissions | `aapt2 dump xmltree` |
| Production config | **READY** — API `https://hisbah-api-alur.onrender.com/api/v1` and `hisbah-web.vercel.app/privacy` compiled in; no `10.0.2.2`/`127.0.0.1`, private keys or debug keystore | `libapp.so` strings (one `localhost` is a Dart library symbol name, not a URL) |
| Real phone install | **NOT VERIFIED** | no device connected. Keep `MOBILE_OTA_RELEASE_VERSION=1.4.0+7` until you verify on a phone |

## Compliance and features

| Area | Status | Evidence |
|---|---|---|
| Consumption-only Android app | **READY** | expired screen and More tab show status only; Flutter tests assert no WhatsApp/payment text (PR #47) |
| In-app privacy-policy link | **READY** | More → «سياسة الخصوصية» → `/privacy` (PR #49, in 1.5.0+8) |
| `/privacy`, `/terms`, `/delete-account` pages | **READY (code)** / **OWNER ACTION REQUIRED (content)** | rendered at 375 px, no horizontal scroll, no console errors; owner fields show «[بانتظار صاحب الخدمة]» until `frontend/src/content/legal.js` is filled |
| Account deletion (app, web, public page, admin) | **READY (code)** / **BLOCKED (production)** | `AccountDeletionTest` 7/7 (PR #47); needs the API deploy below |
| Subscriptions, trial, WhatsApp orders, admin confirmation | **READY (code)** / **BLOCKED (production)** | `SubscriptionPlansAndOrdersTest` 13/13 (PR #47); prices not set |
| Online payment provider | **BLOCKED** | no provider documentation or credentials; stays disabled (PAYMENT_INTEGRATION_GUIDE.md) |
| **Production API** | **BLOCKED — OWNER ACTION REQUIRED** | 2026-11-10: `GET /api/v1/subscription/plans` returns **404** while `GET /api/v1/me` returns 401, so production runs the API from before #47. The 1.5.0+8 app and the website's subscription and deletion features need the new API and migration |

## Tests (actual runs)

| Suite | Result |
|---|---|
| CI on PR #49 / main | backend SQLite and MySQL 8, mobile analyze+test, web lint+build: all pass |
| Local, this round | `flutter analyze` clean; `flutter test` 234 passed, 6 skipped; web lint + build OK; Playwright auth + subscription 10 passed |
| Earlier evidence still valid (backend unchanged since #47) | backend 452 passed (SQLite); MariaDB parity 450/452 (2 pre-existing, also fail on old main); `composer audit` / `npm audit` clean |
| Not run | real device, Bluetooth printer, production |

## Owner actions, in order

1. **Production API (before installing 1.5.0+8):** dispatch the `hisbah-db-backups` workflow and confirm
   it succeeded → deploy the API on Render → run the migration → set `WHATSAPP_BUSINESS_NUMBER`
   (OWNER_ACTIONS.md §B). Then set plan prices at `/admin/subscriptions`.
2. Install `hisbah-1.5.0_8.apk` over 1.4.0+7 on a phone; check sign-in, a sale, printing, More →
   privacy link, delete-account screen (cancel before confirming). Then set
   `MOBILE_OTA_RELEASE_VERSION=1.5.0+8`.
3. Fill `frontend/src/content/legal.js` (LEGAL_INFORMATION_REQUIRED.md) and have both texts reviewed.
4. Create the reviewer demo store on production with an **active** subscription and sample data only.
5. Play Console: follow PLAY_CONSOLE_CHECKLIST.md; listing text in STORE_LISTING_DRAFT.md; upload
   `hisbah-1.5.0_8.aab` yourself.

**Another code change before submission?** No, unless review or the device test finds a problem.
Owner details go into `legal.js` (website only, no app release). Dart-only fixes can ship as
Shorebird patches on 1.5.0+8.
