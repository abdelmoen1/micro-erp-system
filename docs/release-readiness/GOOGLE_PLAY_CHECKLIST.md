# Google Play requirements — technical status

Checked against the official Play policy pages on 2026-11-08 (sources at the end of
`PLAY_CONSOLE_CHECKLIST.md`). Code: `chore/release-readiness` (= `main` @ 5307b9d + this audit's fixes).
The owner's Play Console actions are in `PLAY_CONSOLE_CHECKLIST.md`; blockers in `REMAINING_BLOCKERS.md`.

| # | Requirement | Status | Evidence |
|---|---|---|---|
| 1 | `targetSdkVersion` ≥ 36 (Android 16) for new apps and updates from 31 Aug 2026 | **PASS** | `android/app/build.gradle.kts` uses `flutter.targetSdkVersion`; Flutter 3.47.7 sets 36 (`flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt`). Verified in the merged release manifest of a local build: `minSdkVersion="24" targetSdkVersion="36"` |
| 2 | compileSdk, Gradle, AGP, Java, Kotlin, Flutter compatible | **PASS** | compileSdk 36, minSdk 24, NDK 28.2.13676358 (Flutter defaults); AGP 9.1.0, Kotlin 2.4.0 (`settings.gradle.kts`); Gradle 9.3.1 (wrapper); Java 17 (`compileOptions`, CI `setup-java` 17); Flutter 3.47.7 locally and in CI (`FLUTTER_VERSION`). Local release build succeeded with this toolchain (#3) |
| 3 | Android App Bundle release configuration | **PASS** | `flutter build appbundle --release` produced a 44.4 MB AAB locally (throwaway key, deleted afterwards), ABIs arm64-v8a + armeabi-v7a. CI: `mobile-release.yml` → `shorebird release android` (builds the AAB, plus an APK for the website) |
| 4 | Play App Signing and safe upload key | **PASS (config)** / **BLOCKED (owner choice)** | Release signing only from git-ignored `android/key.properties` + keystore written by CI from secrets and deleted at job end; a release build without it fails instead of using the debug key (`build.gradle.kts` `taskGraph.whenReady`); `*.jks`, `*.keystore`, `key.properties` git-ignored and never committed (history check). Owner must choose the app-signing-key option — `PLAY_CONSOLE_CHECKLIST.md` §0 |
| 5 | Application ID, versionCode, versionName | **PASS** | `com.hisbah.smartshop`; `pubspec.yaml` `version: 1.4.0+7` → versionName 1.4.0, versionCode 7. The first Play upload must use a versionCode **> 7** (website installs are at 7) |
| 6 | 16 KB memory page size | **PASS** (Flutter build) / **UNVERIFIED** (Shorebird engine) | every 64-bit `.so` in the AAB has ELF load alignment ≥ 16 KB (libflutter, libapp 64 KB; ML Kit libbarhopper_v3, CameraX, libdartjni 16 KB). Shorebird replaces the engine at release time: re-run the check (`SECURITY_AUDIT.md`) on the CI-built AAB before upload |
| 7 | Privacy policy in the app and on a public HTTPS page | **BLOCKED (owner)** | draft v2 `PRIVACY_POLICY_DRAFT.md` (covers prices, suppliers, platform-owner access, payments, WhatsApp, deletion); in-app row «سياسة الخصوصية» is built and appears when the app is built with `PRIVACY_POLICY_URL` (`mobile/lib/core/config/env.dart`) |
| 8 | Accurate Data safety incl. third-party SDKs | **BLOCKED (owner submits)** | draft answers in `PLAY_CONSOLE_CHECKLIST.md` §3 — includes Google ML Kit diagnostics (barcode SDK), no ads/analytics SDKs |
| 9 | In-app account deletion + external deletion page | **FIXED** (not deployed) | app «المزيد» → «حذف الحساب»; web `/delete-account` (no app, no session); `AccountDeletionTest` 7/7, Flutter deletion test; verified in a local browser preview |
| 10 | Deletion of associated data, documented retention | **FIXED** / retention periods **BLOCKED (owner)** | staff anonymised; owner store deleted after grace period by `StoreDeletionService` (explicit, child-first); kept items and reasons listed in `ACCOUNT_DELETION_PLAN.md`; periods need owner + legal input |
| 11 | Target audience and age | **BLOCKED (owner declares)** | suggested 18+, business tool |
| 12 | Content rating (IARC) | **BLOCKED (owner submits)** | suggested answers in the console checklist |
| 13 | Ads declaration incl. SDKs | **PASS** | no ad SDK in `pubspec.lock`; answer "No ads" |
| 14 | Sensitive permission declarations | **PASS** | none needed: merged manifest has only INTERNET, ACCESS_NETWORK_STATE, CAMERA, BLUETOOTH_CONNECT, BLUETOOTH_SCAN (neverForLocation) and legacy BLUETOOTH/BLUETOOTH_ADMIN (max API 30) |
| 15 | Reviewer access + reusable demo account | **BLOCKED (owner)** | no demo store on production (the old test store #5 was deleted); create one with an active subscription; SMS codes are off so no OTP step |
| 16 | Store description, screenshots, icon, support info | **BLOCKED (owner)** | not in the repo; disclose the 14-day trial → store subscription honestly; no prices or purchase links in the listing |
| — | Payments policy | **FIXED** (consumption-only) | the app shows no purchase, payment link or WhatsApp-to-pay (Flutter tests assert it); purchasing is website-only; Google's review decides — residual risk documented in `PLAY_CONSOLE_CHECKLIST.md` §7 |
| — | New personal developer account: closed test, 12 testers × 14 days | **UNVERIFIED (owner)** | depends on your account type and creation date, which I cannot see; applies to personal accounts created after 13 Nov 2023 |
