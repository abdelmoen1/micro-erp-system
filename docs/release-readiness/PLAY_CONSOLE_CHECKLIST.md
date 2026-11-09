# Play Console — declarations and manual actions for the owner

Nothing on this list was submitted. Each item is done by the owner in Play Console (or decided by
the owner). Suggested answers come from the code on `main` @ 5307b9d + this branch; check each one
against the app you actually upload. Policy sources are listed at the end.

Legend: ☐ to do · ⚠ blocked until a decision or a code change

## 0. Before creating the app

- ☐ **Developer account type.** A *personal* account created after 13 Nov 2023 must run a
  **closed test with ≥ 12 testers opted in for 14 consecutive days** before it can apply for
  production. An *organization* account (needs a D-U-N-S number) does not. Plan the timeline.
- ☐ **Payments profile / merchant account** — only if Google Play Billing is chosen (see §7).
  Palestine is a supported merchant country.
- ⚠ **Play App Signing key decision** (one-time, irreversible):
  - The app is already installed on shop phones as `com.hisbah.smartshop`, signed with the Hisbah
    release key (CI secret `ANDROID_KEYSTORE_BASE64`). Android only updates an app signed with the
    same key.
  - **Option 1 (keeps one app for everyone):** in Play Console choose *"Use existing app signing
    key"* and upload the current release key through Google's PEPK tool. Play-installed and
    website-installed copies stay compatible. Then create a **new, separate upload key** for CI.
  - **Option 2:** let Google generate the app signing key. Phones that installed the APK from the
    website can **not** update from Play; they must uninstall (local offline data is lost unless
    synced first). Decide before the first upload — it cannot be changed later.
- ☐ **Shorebird + Play.** Shorebird releases build the AAB; patches are delivered OTA. Confirm with
  Shorebird's current documentation that patching a Play-distributed app complies with Play's
  *Device and Network Abuse* policy, and keep patches to Dart code only.

## 1. App setup

| Item | Suggested value / action |
|---|---|
| App name | «حسبة» (≤ 30 characters) — check the trademark/name is free |
| Default language | Arabic (ar) |
| App or game | App |
| Free or paid | Free (decide §7 first) |
| Category | Business |
| Contact e-mail (public) | ☐ [[owner to provide]] |
| Website (optional) | ☐ [[public URL]] |
| Privacy policy URL | ⚠ public HTTPS page — not published yet (`PRIVACY_POLICY_DRAFT.md`) |

## 2. App content declarations

| Declaration | Suggested answer | Notes |
|---|---|---|
| Privacy policy | URL of the published policy | ⚠ also link it **inside the app** (More tab + sign-up screen) — not built yet |
| App access | "All or some functionality is restricted" → give reviewer credentials | ☐ create a **dedicated demo store** on production: owner phone + password, a few products/customers, **active subscription well past review** (a lapsed trial shows only the renewal screen). SMS codes are off, so no OTP step. Write the steps: open app → «تسجيل الدخول» → phone + password. Keep it usable for every future review |
| Ads | **No ads** (no ad SDK in `pubspec.yaml` / merged manifest) | |
| Content rating (IARC) | Category *Utility, Productivity, Communication or Other*; no violence, sex, drugs, gambling; **no user-to-user interaction** (support tickets go to Hisbah only); **does not share the user's location**; digital purchases: depends on §7 | Expected: Everyone / PEGI 3 — the questionnaire decides |
| Target audience | **18+ only** (business tool) | ☐ confirm; then "not appealing to children" |
| News app | No | |
| COVID-19 / health | No / No health features | |
| Government app | No | |
| Financial features | Hisbah records shop sales, customer debts and payments (bookkeeping). It **does not** lend money, hold funds, process payments or offer banking/crypto. Answer accordingly (likely "My app doesn't provide any of these financial features") | ☐ owner confirms |
| Data safety | see §3 | deletion URL = `<website>/delete-account` once deployed |
| Account deletion | in-app: «المزيد» → «حذف الحساب» (also on the expired screen). Web: `<website>/delete-account` (works without the app or a session) | built on this branch — ☐ deploy, then enter the URL. Describe retention (Hisbah's own payment records, trial hash, masked request record) as in ACCOUNT_DELETION_PLAN.md |
| Sensitive permissions | None requiring a declaration: CAMERA, BLUETOOTH_CONNECT/SCAN (`neverForLocation`), INTERNET are not restricted permissions. No SMS, call log, location, all-files, accessibility, foreground-service or exact-alarm permissions | re-check the merged manifest of the final AAB |

## 3. Data safety form (draft answers)

*Does your app collect or share user data?* **Yes (collects).** *Encrypted in transit?* **Yes**
(HTTPS only in release builds). *Can users request deletion?* **Yes** (in-app + web URL, §2).
Purchases happen on the website, not in the app: the app itself collects no payment data. If you
answer for the whole service, add *Financial info → Purchase history* (subscription orders) and,
once a provider is live, what that provider receives.

| Data type (Play category) | Collected | Shared | Optional? | Purposes |
|---|---|---|---|---|
| Personal info → Name | Yes (owner/staff; also the shop's customers and suppliers) | No | Required | App functionality, Account management |
| Personal info → Phone number | Yes (sign-in; customers/suppliers) | No | Required | App functionality, Account management, Fraud prevention & security |
| Personal info → Address | Yes (shop address; customer address if entered) | No | Optional | App functionality |
| Personal info → User IDs | Yes (account id) | No | Required | App functionality, Account management |
| Financial info → Purchase history / Other financial info | Yes (sales, debts, payments recorded by the shop) | No | Required | App functionality |
| Messages → Other in-app messages | Yes (support tickets) | No | Optional | Customer support |
| App activity → Other actions | Yes (audit log of changes) | No | Required | Fraud prevention & security |
| App info and performance → Diagnostics | Yes — **Google ML Kit** barcode SDK sends diagnostics | No (ML Kit does not transfer to third parties) | Required when scanning | Analytics/diagnostics (by the SDK) |
| Device or other IDs | Yes — ML Kit per-installation ID; Hisbah offline-sync installation ID; IP address in audit/OTP rows | No | Required | App functionality, Fraud prevention & security |
| Location | **No** (no location permission; shop coordinates are typed in as an address) | | | |
| Photos/videos | **No** (camera frames are processed on the phone and not stored or uploaded) | | | |

Service providers (Render, Aiven, Vercel, GitHub, Shorebird, SMS gateway) process data on Hisbah's
behalf and are **not** "sharing" under Play's definition — keep that true by contract.

## 4. Store listing

- ☐ Short description (≤ 80 chars) and full description (≤ 4000) — accurate; no claims the app does
  not deliver (no "free forever" while a paid subscription follows the trial; disclose the
  **14-day trial and that a store subscription is required afterwards**). Do **not** put prices,
  payment instructions, WhatsApp-to-pay or links to the purchase page in the Play listing
  (consumption-only; Payments FAQ: no links or calls to action toward other payment methods).
- ☐ App icon 512×512 PNG (32-bit, ≤ 1 MB). Feature graphic 1024×500.
- ☐ ≥ 2 phone screenshots (real app, Arabic UI, no device frames with misleading content).
  Optional 7"/10" tablet screenshots if you declare tablet support.
- ☐ Support e-mail, website, privacy policy URL.

## 5. Release

- ☐ Upload the **AAB** built by `mobile-release.yml` (Shorebird) — never the local check build from
  this audit (it was signed with a throwaway key).
- ☐ Version: `pubspec.yaml` `version: X.Y.Z+N`; `N` (versionCode) must be higher than every APK
  already installed from the website (latest known: 1.4.0+7 → versionCode 7).
- ☐ Native debug symbols / deobfuscation file: upload if obfuscation is enabled.
- ☐ Pre-launch report: review crashes and accessibility warnings.
- ☐ Closed test (§0) → production access application → staged rollout.

## 6. After launch

- ☐ Keep `targetSdk` current: Play requires **API 36** for new apps and updates from
  31 Aug 2026 (extension to 1 Nov 2026 on request). Current build: target 36 ✓.
- ☐ Re-answer Data safety whenever an SDK or data use changes (e.g. switching SMS codes on).

## 7. Payments — consumption-only model (owner decision 2026-11-09)

The Play build sells nothing and links to no payment method: the renewal screen and the More tab
show status only (FIXED on this branch, covered by Flutter tests). Purchasing (plans, WhatsApp
request, future online provider) is on the website only. Play allows "consumption-only" apps where
users access what they bought elsewhere, provided nothing is bought in the app and there are no
links or encouraging language toward outside purchase (Payments FAQ 10281818). Keep it that way in
every OTA patch: no prices, no "renew on our website" links, no WhatsApp-to-pay.
Residual risk: Google decides on review; keep the reviewer demo store **active** so the renewal
screen is not what the reviewer sees.

## Sources (checked 2026-11-08 / 2026-11-09)

- Account deletion requirements: https://support.google.com/googleplay/android-developer/answer/13327111
- Prepare your app for review (privacy policy in-app, sign-in details, ads, ratings): https://support.google.com/googleplay/android-developer/answer/9859455
- Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Preparing for release: https://developer.android.com/studio/publish/preparing

- Target API: https://support.google.com/googleplay/android-developer/answer/11926878
- Payments policy: https://support.google.com/googleplay/android-developer/answer/9858738
- Payments FAQ (consumption-only apps): https://support.google.com/googleplay/android-developer/answer/10281818
- Merchant countries: https://support.google.com/googleplay/android-developer/answer/9306917
- Testing requirement for new personal accounts: https://support.google.com/googleplay/android-developer/answer/14151465
- ML Kit data disclosure: https://developers.google.com/ml-kit/android-data-disclosure
- 16 KB page sizes: https://developer.android.com/guide/practices/page-sizes
