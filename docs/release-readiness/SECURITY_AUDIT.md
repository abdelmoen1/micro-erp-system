# Hisbah — pre-launch security audit

| | |
|---|---|
| Date | 2026-11-08 |
| Code audited | `main` @ 5307b9d (PR #46), in branch `chore/release-readiness` (separate worktree; the user's uncommitted work on `fix/apk-size-and-app-card` was not touched) |
| Scope | Laravel 12 API (`backend/`), Flutter Android app (`mobile/`), React web back office (`frontend/`), CI/deploy config (`.github/`, `render.yaml`, `backend/Dockerfile`, `frontend/vercel.json`) |
| Not in scope / not accessed | production servers, Render/Aiven/Vercel dashboards and env values, the production database, Play Console |
| Method | code reading, git-history secret scan, dependency audits, the existing test suites, new tests, a local release build signed with a throwaway key |

Statuses: **PASS** (verified, nothing to change) · **FIXED** (changed on this branch and tested) ·
**BLOCKED** (needs the owner) · **NOT APPLICABLE** · **UNVERIFIED** (could not be proven from here).

## Round 2 (2026-11-09) — revalidation and new attack surface

All round-1 fixes (headers, CORS, login limits, per-account API limit, dependency updates, Android
backup/permissions, printing fix) are still in place and their tests pass.

| Check | Status | Evidence |
|---|---|---|
| Rate limits behind a shared proxy IP | **FIXED** | Render appends to `X-Forwarded-For` (spoofable), so it is still not trusted. `register` and `otp` limiters are now `[IP + number: 5/min (otp 3/min), IP: 30/min (otp 20/min)]` (`AppServiceProvider`). Test `test_one_number_flooding_sign_up_does_not_block_other_shops_behind_the_same_proxy`. Login: 5/min per number+IP and 20/h per number (round 1). Signed-in: 300/min per user |
| `APP_KEY` production vs committed test key | **UNVERIFIED** | Reading the production key via the Render API was blocked by the session's safety classifier (correctly: production credentials). Script `docs/release-readiness/tools/appkey_fingerprint.mjs` prints fingerprints only; test-key fingerprint `a605b87b8af22117`. Rotation consequences in OWNER_ACTIONS §C.1 |
| Backups | **BLOCKED** (owner) | This repo tracks no dumps (history check, round 1); `.gitignore` now ignores `*.sql.gz`, `*.dump`, `/backups/`, `backup-*.sql`, `backup-before-*.sql`, `prod-*.sql`. The separate `hisbah-db-backups` repo holds plaintext gzip dumps — encryption design (`age`, public key in CI, private key offline) in OWNER_ACTIONS §C.2; history rewrite not done (needs explicit approval) |
| New endpoints: authn/authz | **PASS** | 115 API routes. New public: `POST /account-deletion` (throttle `register`), `GET /account-deletion/{uuid}` (30/min, status only), `POST /payments/webhooks/{provider}` (404 until a real adapter is enabled; signature verified by the adapter). New admin routes behind `platform.admin`; store routes behind `auth:sanctum, active, store`. `StoreIsolationSweepTest` extended to the new parameters (still 404 for every foreign id) |
| Payment safety | **FIXED** | only `confirm-payment` (admin attests verification; exact amount/currency) or a verified provider notification activates; row locks; duplicate activation → 409; provider replay → no-op; payment and history rows append-only (model throws on update/delete; test); no card data stored |
| Privilege escalation | **PASS** | registration ignores `role`, `store_id`, `is_platform_admin`, subscription fields (round-1 test); ownership transfer only owner → active manager of the same store with password (test); platform admin cannot self-delete via the deletion flow (test) |
| Admin access to store data | **FIXED** | every platform-admin request logged in `admin_access_logs` (admin, method, path, target store, IP) by `EnsurePlatformAdmin`; test `test_platform_admin_reads_of_store_data_are_logged`. Read views unchanged and read-only (products with cost/selling price, suppliers with wholesale prices) |
| Account deletion / session invalidation | **FIXED** | staff: tokens + sessions + OTPs removed, identity fields cleared; owner closure revokes every member's tokens and blocks sign-in (`STORE_CLOSING`); tests in `AccountDeletionTest` |
| Data minimisation | **FIXED** | the `platform.store_deleted` audit row now stores masked numbers and no owner name (`StoreDeletionService`; `PlatformAdminTest` updated) |
| Trial abuse | **FIXED** | one trial per owner number via `trial_claims` (HMAC); test `test_deleting_and_recreating_with_the_same_number_gives_no_second_trial` |
| WhatsApp message content | **PASS** | store name, plan, duration, price, reference only — no phone, password or token (test + local browser check) |
| Offline database protection | **PASS** (with note) | SQLite in app-private storage, excluded from backups (round 1); cleared on logout and on account deletion; not encrypted at rest (relies on Android file-based encryption) |
| Third-party SDK security | **PASS** | no new SDKs this round; no ads/analytics; ML Kit diagnostics disclosed |
| CSRF | **NOT APPLICABLE** | bearer tokens only (unchanged) |

## Changes made on this branch (round 1)

| Area | Change | Files |
|---|---|---|
| API headers | `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Permissions-Policy`, COOP, a `default-src 'none'` CSP on `/api/*`, HSTS on HTTPS requests; outermost middleware so 4xx/5xx carry them | `backend/app/Http/Middleware/AddSecurityHeaders.php`, `backend/bootstrap/app.php` |
| CORS | Explicit allow-list (`CORS_ALLOWED_ORIGINS`, default `https://hisbah-web.vercel.app` + local Vite), explicit methods/headers, no credentials. Was the framework default `*` | `backend/config/cors.php` |
| Login | Second limiter: 20 failed sign-ins per number per hour from any IP (on top of 5/min per number+IP). Unknown numbers now cost the same password-hash check as known ones (no timing oracle) | `backend/app/Services/AuthService.php` |
| API rate limit | `throttle:api` — 300 requests/min per signed-in account on every authenticated route (admin included); keyed by user, not IP | `backend/app/Providers/AppServiceProvider.php`, `backend/routes/api.php` |
| Store deletion | Also removes the members' pending SMS codes (`phone_otps`) and the store's sync conflicts | `backend/app/Services/StoreDeletionService.php` |
| Dependencies | `laravel/framework` 12.64.0 → 12.71.0 and Symfony 7.4.x / league/commonmark / flysystem patch updates within existing constraints (fixes the advisories below); frontend dev-tooling lockfile patch (Vite 8.2.x, nanoid, source-map-js) | `backend/composer.lock`, `frontend/package-lock.json` |
| Android backup | `allowBackup="false"`, `fullBackupContent="false"`, `dataExtractionRules` excluding everything (cloud + device transfer) — the offline sales DB and the Keystore-encrypted session no longer leave the phone | `mobile/android/app/src/main/AndroidManifest.xml`, `.../res/xml/data_extraction_rules.xml` |
| Android permissions | `BLUETOOTH_SCAN` flagged `neverForLocation`; legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` limited to API ≤ 30; Bluetooth hardware optional | `AndroidManifest.xml` |
| Printing bug | The app requested only `BLUETOOTH_CONNECT`, but `print_bluetooth_thermal` 1.2.5 refuses every call on Android 12+ unless `BLUETOOTH_SCAN` is also granted (it then reports Bluetooth "off"). Both are now requested in one prompt | `mobile/lib/features/print/application/printer_service.dart` |
| Web headers | `nosniff`, `DENY` framing, `Referrer-Policy`, `Permissions-Policy`, HSTS; CSP in **report-only** | `frontend/vercel.json` |
| Hygiene | `mobile/android/.kotlin/` ignored | `mobile/android/.gitignore` |
| Tests | 10 new backend tests (380 assertions) | `backend/tests/Feature/ReleaseReadinessSecurityTest.php` |

## The 20 checks

| # | Check | Status | Evidence |
|---|---|---|---|
| 1 | No private keys/secrets in the Flutter client | **PASS** | Build-time config is only `API_BASE_URL` / `WEB_BASE_URL` (`mobile/lib/core/config/env.dart`). `mobile/env/*.json` is git-ignored except `example.json` (a LAN URL). `shorebird.yaml` holds a public app id; `shorebird-patch-public.pem` and `tool/release/apk-delivery-public.pem` are **public** keys (checked: `BEGIN PUBLIC KEY`). No SMS/Shorebird/DB credentials in `lib/` |
| 2 | `.env`, environment config, `.gitignore`, production settings | **PASS** | `backend/.gitignore` ignores `.env`, `.env.backup`, `.env.production`; `.dockerignore` keeps `.env*` out of the image; `render.yaml` sets `APP_ENV=production`, `APP_DEBUG=false`, `LOG_LEVEL=info`, secrets `sync: false`; `docker/entrypoint.sh` refuses to start without `APP_KEY`/DB vars. Only `backend/.env.testing` is committed (throwaway test key — see #18). Production env values themselves: **UNVERIFIED** (not accessed) |
| 3 | Admin routes and admin operations protected | **PASS** | All `/api/v1/admin/*` under `auth:sanctum, active, platform.admin` (+ `throttle:api` now). `EnsurePlatformAdmin` runs **before** route-model binding, so ids cannot be probed. Admin flag only set by `php artisan hisbah:platform-admin`. Tests: `PlatformAdminTest` (owner/manager/employee get 403 on every admin route, guests 401, registration cannot grant admin, deactivated admin refused, deletion needs the exact store name) |
| 4 | Authentication, token handling, expiry, logout, revocation | **PASS + FIXED** | Sanctum tokens expire after 30 days (`config/sanctum.php`, `AuthHardeningTest::test_tokens_expire_after_thirty_days`); logout deletes the current token (`ReleaseReadinessSecurityTest::test_logout_revokes_the_token_and_other_devices_keep_theirs`); password change/reset, deactivation and admin revocation delete other tokens (`AccountSettingsTest`, `PhoneSignInTest`, `RoleMatrixTest`). FIXED: hourly per-number limit + constant-time unknown-number path |
| 5 | Authorization and store-level isolation | **PASS** | Every tenant model uses `BelongsToStore`/`ScopedThroughDebtStore`, whose route binding adds `store_id = auth user's store`; list queries filter by `store_id`; foreign ids in requests use `Rule::exists(...)->where('store_id', …)`. `StoreIsolationSweepTest` calls **every** parameterised `/api/v1` route with another store's ids and requires 404 (fails if a new parameter is added without a fixture). Role matrix: `RoleMatrixTest`. Policies in `app/Policies` |
| 6 | Input validation, file uploads, injection | **PASS** | 33 FormRequest classes + inline `validate()` on every write; `per_page` capped (max 50); CSV import: `mimes:csv,txt`, 2 MB, 2000 rows, each row re-validated (`ProductImportService`). No other uploads. New tests: privileged fields ignored at registration, oversized/array/huge `per_page` input refused |
| 7 | XSS, SQL injection, unsafe output | **PASS** | Eloquent/bindings everywhere; the 9 raw fragments (`selectRaw`/`orderByRaw`/`whereRaw`) are constant strings. API returns JSON only, now with `nosniff` + `default-src 'none'`. React escapes output; no `dangerouslySetInnerHTML`/`innerHTML` in `frontend/src`. Flutter renders text widgets only. Test: script/SQL payloads are stored and returned verbatim as JSON data, search terms act as values |
| 8 | Rate limits on login, registration, OTP, reset, sensitive endpoints | **FIXED** (one part **UNVERIFIED**) | Login 5/min per number+IP **and now 20/h per number**; `register` (sign-up, invitation, password reset) 5/min/IP; `otp` 3/min/IP + per-number/day limits in `OtpService`; `/me/password`, `/me/phone` 6/min; support 10/min; sync batch 60/min; admin OTP codes 20/min; **new** 300/min per account on all authenticated routes. Tests: `AuthHardeningTest`, `PhoneSignInTest`, `ReleaseReadinessSecurityTest`. UNVERIFIED: which IP Laravel sees behind Render/Vercel — see `REMAINING_BLOCKERS.md` S-3 |
| 9 | Every endpoint: authn, authz, validation, ownership | **PASS** | `php artisan route:list --path=api`: 96 routes — 6 public (`auth/options`, `auth/otp`, `auth/password/reset`, `login`, `register`, `register/invitation`, all throttled except the read-only options), 90 behind `auth:sanctum` + `active`, of which 15 are platform-admin and the rest also `store` (+ `subscribed` for business routes). Financial writes require `Idempotency-Key`. Ownership: #5 sweep |
| 10 | CORS | **FIXED** | Was `allowed_origins: ['*']`. Now an allow-list; the web app uses the same-origin Vercel rewrite and the app is not a browser, so neither depends on CORS. Test: `test_cors_allows_only_listed_origins` |
| 11 | Security headers | **FIXED** | API middleware + `frontend/vercel.json`. Test: `test_api_responses_carry_security_headers_even_on_errors`. Web CSP is report-only until checked on the live site (S-5) |
| 12 | Debug off, no verbose errors or sensitive logs | **PASS** | `ProductionSafety` forces `app.debug=false` in production (`AuthHardeningTest::test_debug_is_forced_off_in_production`); `ApiExceptionRenderer` returns a generic message for 5xx; `docker/php.ini` `display_errors=Off`, `expose_php=Off`; Apache `ServerTokens Prod`. `LogSmsSender` (logs OTP codes) is refused in production (`AppServiceProvider`). Flutter: no `print`/`debugPrint`/`LogInterceptor` in `lib/`. `X-Powered-By` removed |
| 13 | Dependency vulnerabilities | **FIXED** (see results below) | Composer, npm, pub |
| 14 | Unused packages | **PASS** (nothing removed) | Flutter deps all imported in `lib/` (`sqflite_common_ffi` is dev-only for tests). Composer prod deps are framework, Sanctum, Tinker. `backend/package.json` (Vite/Tailwind/axios) builds the `/` welcome page only. Nothing was removed: no package was proven unused enough to justify the risk |
| 15 | Exposed config, backups, dumps, logs, debug endpoints | **PASS** | `backend/public/` contains only `index.php`, `.htaccess`, `favicon.ico`, `robots.txt`; Apache `Options -Indexes`, docroot `public/`; no Telescope/Debugbar/Horizon; Laravel Boost (registers `/_boost/browser-logs`) is `require-dev` and the image installs `--no-dev`. Tracked SQL file `backend/tool/db/verification-snapshot.sql` contains only read-only count/checksum queries, no data. No `.sql`, `.sqlite`, `.log`, keystore or `key.properties` was ever committed (history check) |
| 16 | Database, credentials, connections, backups, permissions | **UNVERIFIED** (partly BLOCKED) | TLS to Aiven with CA verification (`DB_SSL_CA_PEM` → `MYSQL_ATTR_SSL_CA`, `docker/entrypoint.sh`); credentials only in Render env (`sync: false`). Not verifiable from here: DB user grants (S-4), restore drill. **Owner action:** backups are unencrypted SQL in a private GitHub repo whose history never expires (S-1) |
| 17 | Secure password hashing | **PASS** | `User::casts()` `'password' => 'hashed'` (bcrypt, 12 rounds by default); `$hidden` hides it from JSON. Test: `test_registration_ignores_privileged_fields` asserts the stored value is a hash and absent from the response |
| 18 | Secrets in tracked files and git history | **PASS** (one owner check) | Scanned all 195 commits (`git log --all -p`) for Laravel keys, private-key blocks, GitHub/AWS/Google/Slack/Render tokens, Aiven passwords, Sanctum tokens, JWTs, DB URLs/passwords and generic `password=`/`secret=` assignments; output was masked (first 4 chars + length). Found: (a) `APP_KEY` in `backend/.env.testing` (commit 3da27b8) — a documented throwaway test key; (b) test fixture passwords in Playwright/Flutter tests. No production credential found. **Owner check S-2:** the throwaway key's fingerprint is `sha256[:16] = a605b87b8af22117`; compare with the production key on the release PC without printing it (PowerShell: `$k='<value>'; ([BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash([Text.Encoding]::UTF8.GetBytes($k))) -replace '-','').Substring(0,16).ToLower()`) — they must differ |
| 19 | Comprehensive audit across mobile, backend, API, deployment | **PASS** | This document + `GOOGLE_PLAY_CHECKLIST.md` + `REMAINING_BLOCKERS.md` |
| 20 | Every result verified with evidence | **PASS** | Each status above cites code, a test or a command. Items that could not be proven are marked UNVERIFIED rather than PASS |

## Additional checks

| Check | Status | Evidence |
|---|---|---|
| IDOR / broken access control | **PASS** | `StoreIsolationSweepTest` (all parameterised routes), `RoleMatrixTest::test_cross_store_staff_targets_are_not_found`, admin-before-binding ordering |
| CSRF | **NOT APPLICABLE** | API auth is bearer tokens only (web keeps the token in `localStorage`, app in secure storage); no cookie session on `/api`; CORS `supports_credentials=false` |
| Sensitive data in logs / responses | **PASS** | Password/remember token hidden; OTP codes stored hashed and phone numbers masked in messages; audit metadata masks phone changes; 5xx bodies generic with a correlation id |
| Token storage on mobile | **PASS** | `flutter_secure_storage` 11 (Android Keystore) — `mobile/lib/core/storage/key_value_store.dart`; now also excluded from backups |
| Logout clears local credentials | **PASS** | `AuthRepository.logout` revokes server-side then always deletes token + cached user; the More-tab logout also clears the offline catalog (customers/products); logout is refused while unsynced sales are queued. A server-side expiry (401) clears the token but keeps the catalog cache for the same store (cleared when another store signs in) — acceptable |
| HTTPS enforcement | **PASS** | Release builds require an `https://…/api/v1` URL (`mobile/tool/ci/check_api_url.sh`, `Env.apiBaseUrl` has no release fallback); cleartext allowed only in the debug manifest; HSTS added on API and web |
| Database tenant isolation | **PASS** | see #5 |
| Backup and recovery safety | **UNVERIFIED** | Nightly dumps exist (`hisbah-db-backups`); no restore test seen; unencrypted (S-1) |

## Dependency audit results

| Ecosystem | Before | After | Command |
|---|---|---|---|
| Composer (prod) | 24 advisories in 8 packages, incl. **critical** CVE-2026-114509 (laravel/framework TokenGuard bypass — the app uses Sanctum and only a `session` guard, so not reachable here), high: symfony/http-foundation ReDoS CVE-2026-108082, 10 league/commonmark DoS/XSS (Markdown is not rendered from user input in this app) | **0** — "No security vulnerability advisories found" (laravel/framework 12.71.0, symfony/* 7.4.22–7.4.23, league/commonmark 2.10.7) | `composer audit --no-dev` |
| Composer (dev) | + symfony/yaml (2) | **0** | `composer audit` |
| npm `frontend` (prod) | 0 | 0 | `npm audit --omit=dev` |
| npm `frontend` (all) | 3 high (vite 8.2.0–8.2.2 dev server, nanoid, source-map-js) | 0 | `npm audit fix --package-lock-only`, then `npm ci`, `npm run build`, `npm run lint` OK |
| npm `backend` | no lockfile — cannot audit (R-4) | — | `npm audit` → ENOLOCK |
| Dart/Flutter | `flutter pub get` reports no security advisories; 29 packages have newer incompatible majors (not upgraded) | — | `flutter pub get` |

## Mobile / Android

| Check | Status | Evidence |
|---|---|---|
| Permissions | **FIXED** | Merged release manifest (`build/app/intermediates/merged_manifest/release/…`): `INTERNET`, `ACCESS_NETWORK_STATE`, `CAMERA` (camera feature optional), `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` with `usesPermissionFlags="neverForLocation"`, `BLUETOOTH`/`BLUETOOTH_ADMIN` with `maxSdkVersion=30`, and the AndroidX signature-level `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. No location, storage, contacts, SMS, phone, notification or foreground-service permission. Exported components: `MainActivity` (launcher) and AndroidX `ProfileInstallReceiver` (permission-protected by the system) only |
| Camera only when scanning | **PASS** | requested in `sale_scanner_screen.dart` / `mobile_scanner_camera.dart` when the scanner opens; manual entry works without it |
| Notifications | **NOT APPLICABLE** | no `POST_NOTIFICATIONS`, no push SDK |
| Android backups | **FIXED** | see changes |
| Release mode, logging, config | **PASS** | no logging in `lib/`; release requires explicit HTTPS API URL; release signing refuses the debug key (`android/app/build.gradle.kts`) |
| Crashes, navigation, loading, network failures | **PASS (automated)** / **UNVERIFIED (device)** | 235 widget/unit tests incl. offline fallback, sync, error mapping, session expiry; no real-device run in this audit |
| Core workflows (scan, sale, stock, debts, returns, purchases, printing) | **PASS (automated)** / **UNVERIFIED (device)** | backend feature tests (sales, returns, debts, payments, stock, purchases, sync) + Flutter flow tests; printing fix needs a real printer on Android 12+ |
| Android versions / screens | **PASS (config)** / **UNVERIFIED (device)** | minSdk 24 (Android 7.0), targetSdk 36, compileSdk 36 |
| Plugins and native libraries | **PASS** | Native code in the AAB: `libflutter.so`, `libapp.so` (Dart), `libdartjni.so`, ML Kit `libbarhopper_v3.so` (mobile_scanner), CameraX `libimage_processing_util_jni.so` / `libsurface_util_jni.so`; ABIs `arm64-v8a` + `armeabi-v7a` only; the unused `libsqlite3.so` and x86 libs are excluded (`build.gradle.kts`). Plugins: flutter_secure_storage 11.2.0, mobile_scanner 7.4.2, permission_handler 12, print_bluetooth_thermal 1.2.5, printing 5.15.1, sqflite 2.4.5, url_launcher 6.3.x |
| 16 KB page size | **PASS** (Flutter build) / **UNVERIFIED** (Shorebird engine) | ELF `PT_LOAD` alignment of every 64-bit library in the locally built AAB ≥ 16384 (`libflutter.so`/`libapp.so` 65536; ML Kit, CameraX, dartjni 16384) — checked with a program-header parser. The 32-bit ML Kit lib is 4 KB-aligned, which the requirement (64-bit devices) does not cover. Native libs are compressed (`useLegacyPackaging`), so zip alignment does not apply. Shorebird's release swaps in its own engine build: run the same check on the CI-built AAB before upload |
| Obfuscation / split debug info | **PASS (feasible)** — not enabled | `flutter build appbundle --release --obfuscate --split-debug-info=…` succeeded locally. Not switched on in CI: it must be enabled in both `mobile-release.yml` and `mobile-patch.yml`, symbols kept per release, and `sync_engine.dart:174` shows `runtimeType` names to users (they would become obfuscated) — `REMAINING_BLOCKERS.md` R-2 |

## Test results (this branch)

| Suite | Result |
|---|---|
| Backend `php vendor/bin/phpunit` (SQLite in-memory, isolated) — before dependency update | **432 tests, 3288 assertions, OK** |
| Backend — after dependency update | **432 tests, 3288 assertions, OK** |
| `composer validate` | valid |
| `flutter analyze` | No issues found |
| `flutter test` | **235 passed, 6 skipped**, 0 failed |
| `frontend`: `npm run build`, `npm run lint` | OK |
| Local release AAB (`flutter build appbundle --release --obfuscate`, signed with a throwaway key) | **Built** `app-release.aab` 44.4 MB, `com.hisbah.smartshop` versionCode 7 / 1.4.0, minSdk 24, targetSdk 36. First attempt failed on a network drop downloading Kotlin Gradle plugin 2.3.0 from Maven Central; the retry succeeded. The throwaway key, `key.properties` and the AAB were deleted afterwards — **this AAB must never be uploaded** (Play would bind the app to a lost upload key) |

Not run: `phpunit.mysql.xml` (needs a local MySQL; the XAMPP MySQL on this PC is known-broken),
Playwright e2e (needs a running API + browsers), on-device tests.
