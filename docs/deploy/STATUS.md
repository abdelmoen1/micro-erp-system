# Deployment status (checkpoint)

Last verified: 2026-10-17. Everything below was checked with real requests or provider APIs; nothing secret is recorded.

## Live environment ($0)

| Piece | Provider / plan | Verified |
|---|---|---|
| API | Render web service `hisbah-api` (`srv-db94et7t5n8s73auto80`), plan **free**, Frankfurt, Docker, branch `infra/render-backend`, root `backend/` | Deploy `live` in about 100 s; `/up` 200 |
| Public URL | `https://hisbah-api-alur.onrender.com` (API base `…/api/v1`) | HTTPS; asset links generated as `https://` |
| Database | Aiven MySQL `mysql-1f5745b1`, plan **free-1-1gb** ($0.000/h, 1 GB disk), DigitalOcean Frankfurt, MySQL **8.4.11**, TLS required (`TLS_AES_256_GCM_SHA384`) | Connected from this PC and from Render |
| DB user | `hisbah_app` (normal user; the admin account is not used by the app) | Logins work |
| Schema | All 15 Laravel migrations (batch 1), run once from the release PC against the new empty database | `migrate:status` all `Ran` |
| `APP_KEY` | The existing key of the Railway app (same value, not regenerated) | Read via Railway CLI, set in Render, never printed |

The Aiven service was first created in the console on the paid **developer-1** plan ($0.007/h). It was switched
to **free-1-1gb** through the API before any use (balance $0.00).

## API checks against the live URL

| Request | Result |
|---|---|
| `GET /up` (checks the DB connection) | 200 |
| `GET /api/v1/me` with `Accept: application/json` | 401 `UNAUTHENTICATED` |
| `POST /api/v1/login` `{}` | 422 `VALIDATION_FAILED` |
| `POST /api/v1/login` unknown `@example.invalid` user | 401 `INVALID_CREDENTIALS`: a real query on `users` in Aiven |
| `GET /api/v1/<unknown>` | 404 `NOT_FOUND` JSON |
| `POST /` | 405, no stack trace |
| `GET /api/v1/me` without an `Accept: application/json` header | 401 (was 500 before commit 6080a26: guest redirect to a missing `login` route) |

**Authenticated flow, verified 2026-10-17** with a temporary probe account (`deploy-probe-…@example.invalid`, random
password held only in memory): `POST /register` 201 → wrong password 401 → `POST /login` 200 with a token →
`GET /me` 200 (role `owner`, status `active`, store timezone `Asia/Gaza`) → `GET /my-store`, `/dashboard`,
`/customers`, `/debts`, `/payments`, `/users` all 200 → `POST /logout` 200 → the same token gets 401. The probe's
user and store rows were then deleted (it had no tokens or audit rows left), and every business table is back to 0 rows.
The only trace is that the auto-increment ids start at 2.

There are still no real accounts. The first owner registers with `backend/tool/deploy/register_owner.ps1`, which
prompts for the password hidden.

## Deploys

Render auto-deploy does not fire for this service (Render's GitHub app has no access to this repository), so deploys
are triggered through the API or CLI: `render deploys create srv-db94et7t5n8s73auto80` (after `render login`).
Giving the Render GitHub app access to `abdelmoen1/micro-erp-system` (GitHub → Settings → Applications → Render) would
enable deploy-on-push. Last deploy: `ceb4586`, live (later commits on the branch change docs only).

## Data

**The new database is fresh. No data from Railway was migrated.** The old Railway MySQL (`powerful-charm` /
`mysql-volume`, about 197 MB) is stopped because the Railway account is inactive. It was not touched, and no
backup of it exists on the release PC (searched; the only `.sql` dump found belongs to another project).

## Free-plan behaviour

- Render free: sleeps after 15 minutes without traffic (about a minute to wake up). The workspace shares 750 free hours
  a month with another free service (`Backend`, repository `abdelmoen1/Backend`, which is left untouched).
- Aiven free: 1 GB disk, 76 connections; may be powered off after a period without activity (power it on again
  in the console); backups are included.
- No files are stored by the API, so Render's temporary disk is fine. The daily `idempotency:prune` schedule
  does not run on the free plan (harmless at current volumes).

## Mobile (OTA baseline)

- GitHub variable `MOBILE_API_BASE_URL` = `https://hisbah-api-alur.onrender.com/api/v1` (release and patch
  workflows). Local development keeps `env/dev.json`.
- Shorebird release **1.0.0+1** (Flutter 3.47.7), status active, built by run 38929200113 (an earlier run failed
  because secrets uploaded through a Windows PowerShell pipe carried a UTF-8 BOM; secrets re-uploaded cleanly,
  scripts fixed on `fix/secret-upload-bom`).
- APK `hisbah-1.0.0_1.apk` (56 MB, all ABIs incl. armeabi-v7a) in the **draft** GitHub release `android-1.0.0_1`
  (anonymous access 404). Verified locally: checksum, `com.hisbah.smartshop` 1.0.0 (1), certificate
  `CN=Hisbah Smart Shop` SHA-256 `d4c70c9b…2bc6`, Render API URL compiled in, no Railway/localhost URL.
- Not yet done: install on the phone (replaces the USB debug build: uninstall first), then set
  `MOBILE_OTA_RELEASE_VERSION=1.0.0+1`, run the patch acceptance test, then `MOBILE_OTA_ENABLED=true`.

## Local secrets (release PC only, `%USERPROFILE%\hisbah-release`, user-only ACL)

`aiven-api-token.dpapi`, `shorebird-api-key.dpapi`, `keystore-password.dpapi` (DPAPI), signing and patch keys.
The Render CLI login token is in `%USERPROFILE%\.render\cli.yaml`.

## Scripts

`backend/tool/deploy/`: `aiven_free_mysql.ps1` (free plan only), `migrate_new_aiven_db.ps1` (Aiven host
only, stops on foreign tables), `render_free_service.ps1` (free plan, no duplicates), DPAPI secret helpers.
