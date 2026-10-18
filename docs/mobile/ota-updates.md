# Mobile delivery: Railway API + Shorebird OTA updates

How the Android app reaches phones without a USB cable, and how Dart/UI changes reach installed apps
over the internet. Workflows: [mobile-release.yml](../../.github/workflows/mobile-release.yml) (full release,
manual) and [mobile-patch.yml](../../.github/workflows/mobile-patch.yml) (OTA patch).

```
push to main (mobile/lib/**) ─► Mobile patch: analyze + test ─► signed shorebird patch ─► phone downloads it at
   (only when MOBILE_OTA_ENABLED=true)                                                    app start, runs it from
                                                                                          the next start
```

## 1. Production API

| | |
|---|---|
| Backend | Laravel on Railway, `https://micro-erp-system-production.up.railway.app` |
| API base URL in releases and patches | `https://micro-erp-system-production.up.railway.app/api/v1` (variable `MOBILE_API_BASE_URL`) |

- Release builds get the URL only from `--dart-define-from-file=env/production.json`, which CI writes from
  `MOBILE_API_BASE_URL` after `tool/ci/check_api_url.sh` checks it (HTTPS, public host, `/api/v1`, no trailing slash).
  Endpoint paths (`/login`, `/me`, …) are relative to it, so `/api/v1` is never doubled.
- A release build without a define has **no** fallback URL (`lib/core/config/env.dart`). Debug runs keep the
  emulator default and `env/dev.json` (README).
- Releases and patches read the same variable, so a patch cannot switch the phone to another API.

Railway settings (source repo/branch/root directory, `APP_DEBUG=false`, database variables) are managed in the
Railway dashboard. Read-only checks from the service shell: `php artisan db:show`, `php artisan migrate:status`.
Never run `migrate` or seeders against production from a shell.

## 2. One-time setup

### 2.1 Signing keys (permanent, outside the repository)

Everything lives in `%USERPROFILE%\hisbah-release\`, which only the current Windows user can open:

| File | What it is | If lost |
|---|---|---|
| `hisbah-upload.jks` | Android release key (alias `upload`, PKCS12, cert `CN=Hisbah Smart Shop`). Every full APK must carry it to install over the previous one | CI keeps working from the GitHub secrets; only if those are lost too: new key, one uninstall/reinstall per phone |
| `keystore-password.dpapi` | Its random password, encrypted with Windows DPAPI | Same as above |
| `shorebird-patch-private.pem` | Patch signing: phones only run patches signed with it (public half: `mobile/shorebird-patch-public.pem`) | No more patches for releases carrying the public key; a new full release is needed |
| `apk-delivery-private.pem` | Opens encrypted APK artifacts (2.4) | Harmless: make a new pair, commit the new public key |
| `shorebird-api-key.dpapi` | Shorebird Console API key, DPAPI-encrypted, for local `shorebird` commands | Create a new key in the console |

`setup_signing.ps1` creates the key without any input: a random 32-byte password that nobody types or sees, the
keystore, and the GitHub secrets (over stdin, never in arguments or history). It is resumable and never
overwrites an existing key or secret. It prints the certificate SHA-256 fingerprint, the same one shown in every
release run summary (`D4:C7:0C:9B:…:2B:C6` for the current key).

```powershell
powershell -ExecutionPolicy Bypass -File mobile\tool\release\setup_signing.ps1
```

**Recovery and backup.** DPAPI files can be decrypted only by this Windows account on this PC; copying them
elsewhere does not carry the password. What survives losing the laptop:
- The GitHub secrets hold the keystore, its password and the patch key. Releases and patches are built in CI,
  so delivery keeps working without this PC. GitHub never shows secret values again, so they cannot be copied out.
- A copy of the `hisbah-release` folder on a USB stick or OneDrive restores everything for this same Windows
  account on this PC (for example after deleting the folder by mistake).
- A fully portable backup of the password needs it written down or kept in a password manager; that is not part
  of the default setup.

### 2.2 Shorebird

1. Install the CLI (PowerShell): `iwr -UseBasicParsing 'https://raw.githubusercontent.com/shorebirdtech/install/main/install.ps1' | iex`
2. Shorebird Console → **Account → API Keys → Create API Key** (Full access; default expiry 1 year: renew it
   before then). Store it with `set_shorebird_token.ps1`: hidden prompt, sets the `SHOREBIRD_TOKEN` secret and a
   DPAPI copy for local use. `shorebird login:ci` tokens stopped working on 2026-10-01.
3. Local commands use that key: `. mobile\tool\release\shorebird_env.ps1`, then e.g. `shorebird releases list`.
4. `shorebird init --display-name Hisbah` in `mobile/` (once). It keeps `com.hisbah.smartshop`, creates
   `mobile/shorebird.yaml` (the `app_id`, not secret) and adds it to the `assets` in `pubspec.yaml`.
   Never `init --force`: it creates a different app and orphans existing releases.

Automatic update checks stay on (no `auto_update: false`).

### 2.3 GitHub configuration (names only)

| Name | Kind | Set by |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | secrets | `setup_signing.ps1` |
| `SHOREBIRD_PATCH_PRIVATE_KEY` | secret | `setup_signing.ps1` |
| `SHOREBIRD_TOKEN` | secret | `set_shorebird_token.ps1` (2.2) |
| `MOBILE_API_BASE_URL` | variable | `https://micro-erp-system-production.up.railway.app/api/v1` |
| `MOBILE_APK_DISTRIBUTION` | variable | `draft-release` (2.4) |
| `MOBILE_OTA_ENABLED` | variable | `false` until the device acceptance test passes (3.3) |
| `MOBILE_OTA_RELEASE_VERSION` | variable | the release version installed and verified on the phone |

Both workflows run in the `mobile-production` environment. Recommended: Settings → Environments →
`mobile-production` → deployment branches: `main` only.

### 2.4 How the APK leaves CI

The repository is **public**: workflow artifacts can be downloaded by any signed-in GitHub user. The release
workflow refuses to run until `MOBILE_APK_DISTRIBUTION` is set:

| Mode | APK goes to | Who can use it |
|---|---|---|
| `draft-release` (configured) | a **draft** GitHub release `android-<version>` with the APK + checksum | Only accounts with write access (drafts answer 404 to everyone else, checked on this repository). On the phone: github.com → sign in → repository → Releases → the draft → tap the `.apk` |
| `encrypted` | `hisbah-<version>.apk.enc` (AES-256, random one-time key) + `hisbah-<version>.key.enc` (that key, RSA-OAEP-encrypted to `mobile/tool/release/apk-delivery-public.pem`) + checksum | Only the holder of `%USERPROFILE%\hisbah-release\apk-delivery-private.pem` (never leaves the release PC; no secret in GitHub, no passphrase) |
| `artifact` | the plain APK + checksum | Any signed-in GitHub user |

No mode puts signing keys or credentials anywhere downloadable; the APK holds only the public API URL.
Opening an encrypted artifact on the PC (Git Bash, in the unzipped artifact folder):
`bash mobile/tool/release/decrypt_apk.sh hisbah-<version>.apk.enc` (checks the SHA-256). Then move the APK to
the phone privately, e.g. Google Drive or an email to yourself, opened on the phone.
Losing the delivery private key is harmless: generate a new pair and commit the new public key.

### 2.5 Baseline release and install

1. Merge the setup into `main` (patches stay off: `MOBILE_OTA_ENABLED` is not `true`).
2. Actions → **Mobile release (Shorebird, Android)** → Run workflow on `main`. The summary records the release
   version, application ID, certificate fingerprint and API URL; the build fails if the APK has the wrong
   application ID or a debug signature.
3. Get the APK onto the phone as in 2.4. Allow the browser / My Files / Drive to install unknown apps when
   Android asks. Play Protect may warn about an unknown developer.

**Replacing the USB-installed debug app.** The app installed during Sprint 1 is a debug build signed with the
PC's debug key and is not a Shorebird release. Android refuses to update it with the release APK ("App not
installed"), so it has to be **uninstalled once** (long-press حسبة → Uninstall), and only once the release
APK is downloaded and verified. That loses only data on the phone (the saved login): accounts and shop data
live on the server. Later full releases signed with the same key install over the top and keep the login.
The test accounts from the local SQLite dev API do not exist on Railway; sign in with a production account.

## 3. Day to day

### 3.1 What ships as an OTA patch, what needs a full APK

| Change | Delivery |
|---|---|
| Dart code under `mobile/lib/` (screens, logic, routes, ARB text) | **Patch** |
| Pure-Dart dependency changes in `pubspec.yaml` / `pubspec.lock` | Patch if Shorebird finds no native difference |
| `mobile/android/**` (Gradle, manifest, Kotlin, launch screen, icons) | **Full APK** |
| New or upgraded plugin with native code | **Full APK** (Shorebird rejects the patch) |
| `mobile/assets/**` (fonts, images), `shorebird.yaml`, `shorebird-patch-public.pem` | **Full APK** |
| Flutter version, `version:` in pubspec | **Full APK** |
| A Material icon (`Icons.*`) the release does not already use | **Full APK** for 1.0.0+1 only (see Icons below) |

The patch workflow stops with "Full release required" for pushes touching `android/`, `assets/`, `shorebird.yaml`
or the patch public key (`tool/ci/check_patchable.sh`), and when `version:` differs from
`MOBILE_OTA_RELEASE_VERSION`. Shorebird's own native/asset checks then cover the rest. The workflows never
pass `--allow-native-diffs` or `--allow-asset-diffs`.

**Icons.** Release builds tree-shake `MaterialIcons-Regular.otf` down to the icons the code uses, so the font
is an asset whose bytes depend on the set of `Icons.*` in `mobile/lib/`. A patch that uses an icon the release
does not ship changes that asset, and Shorebird refuses it ("Your app contains asset changes … Not publishing",
run 39128334615). With `--allow-asset-diffs` the new icons would render as empty boxes on the phone. Patches
for release 1.0.0+1 must keep exactly its icon set (`git grep -ho "Icons\.[a-zA-Z0-9_]*" -- mobile/lib | sort -u`).
From release 1.0.0+2 on, both `mobile-release.yml` and `mobile-patch.yml` pass `--no-tree-shake-icons` (the whole
font ships, about +1.6 MB), so patches can use any Material icon. Keep the flag identical in both workflows: a
release and its patches must build the font the same way.

### 3.2 Patch timing on the phone

1. A push to `main` with Dart changes runs **Mobile patch**: `flutter analyze`, `flutter test`, then a signed
   patch for `MOBILE_OTA_RELEASE_VERSION`. The summary shows the release version and patch number.
2. The app checks for a patch **when it starts** and downloads it in the background (internet needed).
   A running app does not change.
3. The patch runs from the **next start of the app process**: close حسبة from recent apps, then open it again.
   In practice: open (downloads), close, open (patched).
4. No network or a failed check: the app keeps its current code and tries again at the next start.

### 3.3 Device acceptance test, then automatic patches

With the baseline installed and `MOBILE_OTA_RELEASE_VERSION` set to its version:
1. Merge a harmless, visible Dart-only change into `main` (push does not patch yet).
2. Actions → **Mobile patch** → Run workflow on `main` (manual runs work while automatic patches are off).
3. On the phone: open, close, open. The change must be visible. Shorebird Console should show the patch install.
4. Revert the change the same way (new patch) and confirm it disappears.
5. Then set `MOBILE_OTA_ENABLED=true`: from now on every eligible push to `main` patches automatically.

### 3.4 Full release

1. Bump `version:` in `mobile/pubspec.yaml` (e.g. `1.0.0+1` → `1.0.1+2`; the `+build` number must go up).
   Each Shorebird release version can be published once.
2. Merge to `main`, run **Mobile release**, install over the existing app (same key: data kept). A standard
   Android phone always asks the user to confirm an APK install; nothing installs silently.
3. Set `MOBILE_OTA_RELEASE_VERSION` to the new version once it is on the phone. Until then patches fail fast.

### 3.5 Which patch is running, diagnosing, rollback

- Shorebird Console → app → release: patch numbers and install counts.
- GitHub → Actions → Mobile patch summaries: patch number per commit.
- Device logs (Wireless debugging works on Android 11+, no cable: Developer options → Wireless debugging →
  `adb pair`, `adb connect`): `adb logcat | findstr shorebird`. No `[shorebird]` lines means the installed app
  is not a Shorebird release; "no active patch" usually means a release-version mismatch. If the patch does not
  apply after closing the app, compare `adb shell pidof com.hisbah.smartshop` before and after: the same PID
  means the process never restarted.
- Roll back a bad patch (from `mobile/`): `shorebird patches rollback --release-version 1.0.0+1 --patch-number 2`.
  Phones drop it at their next start. Undo with `shorebird patches rollforward`
  ([docs](https://docs.shorebird.dev/code-push/rollback/)). Or revert the commit and push (new patch).

## 4. Local development (unchanged)

`flutter run --dart-define-from-file=env/dev.json` against the local API, as in the [README](../../mobile/README.md).
Debug builds need no key. Local **release** builds fail unless `android/key.properties` points at the Hisbah
keystore: nothing is ever signed with the public debug key. CI builds always use `MOBILE_API_BASE_URL`.
