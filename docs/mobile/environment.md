# Mobile development environment (US-1302)

## Toolchain (installed 2026-10-13, Windows 11)

| Component | Version | Location |
|---|---|---|
| Flutter (stable) | 3.47.7 · Dart 3.13.5 (zip MD5-verified against the Google Storage hash) | `C:\Users\hp\dev\flutter` |
| JDK | Temurin 17.0.20.1 | `C:\Users\hp\dev\jdk17` (`flutter config --jdk-dir`) |
| Android SDK | platform-tools 37.0.1 · platforms android-36, android-37.0 · build-tools 36.1.0, 37.0.0 · NDK 28.2.13676358 · cmdline-tools | `C:\Users\hp\dev\android-sdk` (`flutter config --android-sdk`) |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 (from `flutter create`) | project wrapper |

Notes:
- Android Studio is **not** installed; the command-line SDK is enough to build and install. The `sdkmanager` CLI is deprecated and now delegates to `android.exe` (`cmdline-tools\latest\bin\android.exe sdk install <pkg>`); package names use `/`, e.g. `platforms/android-36`.
- **NDK 28.2.13676358 must be pre-installed.** AGP tries to auto-install it through the deprecated `sdkmanager`, which fails with `Android sdkmanager did not install NDK 28.2.13676358`. Install it first: `android.exe --sdk=<sdk> sdk install ndk/28.2.13676358` (~700 MB).
- The first Gradle build downloads Gradle 9.3.1 (~235 MB) and all plugin dependencies. On this connection that took about 3 hours, so run the first build ahead of device day.
- `flutter doctor` (2026-10-13): Flutter, Android toolchain (all licenses accepted), Chrome, network: OK. Only issue: Visual Studio is not installed, so Windows-desktop Flutter builds are unavailable. They are not needed.
- Session setup: `$env:Path = "C:\Users\hp\dev\flutter\bin;$env:Path"`.

## Packages (D-20, pinned in `mobile/pubspec.lock`)

| Package | Version | Note |
|---|---|---|
| flutter_riverpod / riverpod | 3.4.3 | No code generation. Riverpod 3 retries failing providers by default; the app disables it (`ProviderScope(retry: …)`). |
| go_router | 18.0.2 | `StatefulShellRoute.indexedStack` for the 5 tabs; redirect guard is a pure function (`sessionRedirect`) |
| dio | 5.11.1 | Fake `HttpClientAdapter` in tests; in widget tests never `await` a dio call outside the pumped clock |
| flutter_secure_storage | 11.2.0 | Android Keystore-backed token storage |
| intl | 0.20.3 | Required by `gen-l10n` |
| integration_test (SDK) | — | Phone runs (US-1306) |

## Project settings

- `applicationId` / namespace: `com.hisbah.smartshop` (D-37). Launcher label: حسبة.
- `INTERNET` permission in the main manifest. **Cleartext HTTP is allowed in debug builds only** (`src/debug/AndroidManifest.xml`) so a phone can reach `php artisan serve` on the LAN; release builds are HTTPS-only.

## Reaching the local API from a phone

1. Run the API on all interfaces: `php artisan serve --host=0.0.0.0 --port=8000` (against a disposable local database).
2. Allow inbound TCP 8000 on the **private** network profile (admin PowerShell):
   `New-NetFirewallRule -DisplayName "Hisbah API dev" -Direction Inbound -Protocol TCP -LocalPort 8000 -Profile Private -Action Allow`
3. `mobile/env/dev.json`: `{"API_BASE_URL": "http://<PC LAN IP>:8000/api/v1"}` (git-ignored).
4. Phone and PC on the same Wi-Fi; open `http://<PC LAN IP>:8000/up` in the phone browser → expect a page (TC-1302-03).

## Phone setup (TC-1302-01/02) — **pending: no phones connected yet**

1. Settings → About → tap *Build number* 7× → Developer options → **USB debugging** on.
2. Connect by USB, accept the RSA prompt; `adb devices` lists the phone.
3. `flutter run --dart-define-from-file=env/dev.json` (debug), then `flutter run --release …`.
4. Record model, Android version and RAM of the **reference** and **low-end** phone here.

| Phone | Model | Android | RAM | Debug run | Release run | API reachable |
|---|---|---|---|---|---|---|
| Reference | — | — | — | ☐ | ☐ | ☐ |
| Low-end | — | — | — | ☐ | ☐ | ☐ |
