# Hisbah Smart Shop — mobile (Flutter)

Android app for shop staff. Arabic first, RTL. Talks only to the Laravel API under `/api/v1`
(contract: [docs/api/auth.http](../docs/api/auth.http), [docs/api/error-codes.md](../docs/api/error-codes.md)).

> **Visual direction:** Direction A (Ledger), IBM Plex Sans Arabic, Western digits — selected by the TL at DR-2 part 1
> (2026-10-15). Final DR-2 approval is **pending**; hi-fi source: the US-1507 P2 board (Main.dc.html) in the design package.

## Setup

Toolchain and phone setup: [docs/mobile/environment.md](../docs/mobile/environment.md).

```sh
cd mobile
cp env/example.json env/dev.json      # LAN address, or http://127.0.0.1:8000/api/v1 with adb reverse
flutter pub get
flutter run --dart-define-from-file=env/dev.json
```

USB alternative (no firewall / Wi-Fi setup): `adb reverse tcp:8000 tcp:8000` and API_BASE_URL `http://127.0.0.1:8000/api/v1`.
Run the API so phones can reach it: `php artisan serve --host=0.0.0.0 --port=8000` (debug builds allow plain HTTP; release builds are HTTPS only).
Without a define, `API_BASE_URL` defaults to `http://10.0.2.2:8000/api/v1` (Android emulator → host) in debug and
profile builds. Release builds have no default URL and need the Hisbah release key (`android/key.properties`):
CI builds them against the live Render API (`MOBILE_API_BASE_URL`).

Phone builds over the internet (no USB): Shorebird release + OTA patches from `main`, see
[docs/mobile/ota-updates.md](../docs/mobile/ota-updates.md).

## Checks

| Command | What |
|---|---|
| `flutter analyze` | Lints (must report no issues) |
| `flutter test` | Unit + widget tests, fake HTTP (no server needed) |
| `flutter test test/live --dart-define=LIVE_API=http://127.0.0.1:8000/api/v1` | US-1306 scenarios against a real **disposable** local API, from the PC |
| `flutter test integration_test/auth_flow_test.dart --dart-define-from-file=env/dev.json` | The same scenarios on a connected phone (secure storage, real network) |

The live scenarios create invited employees and deactivate one: never point them at real shop data.

## Structure

```
lib/
  core/        api client + typed failures, config, storage, router, theme, shared widgets
  features/
    auth/      session (restore, login, logout, 401 / deactivated handling), login screen
    shell/     5-tab bottom navigation, splash, tab placeholders
  l10n/        app_ar.arb (template), app_en.arb
```

Stack (D-20): flutter_riverpod (no code generation), go_router, dio, flutter_secure_storage, SDK `gen-l10n`.
Application ID: `com.hisbah.smartshop` (D-37) — do not change after the first Play release.
