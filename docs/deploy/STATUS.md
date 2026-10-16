# Deployment status (checkpoint)

Last verified: 2026-10-16. Everything below was checked with real requests or provider APIs; nothing secret is recorded.

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
| `GET /api/v1/me` **without** an `Accept: application/json` header | 500 `SERVER_ERROR` JSON (no trace). Existing app behaviour: the guest redirect targets a missing `login` route. Clients send the JSON header; a fix is tracked separately |

Not yet verified: a real login and `GET /api/v1/me` with a token. There are no accounts yet (fresh database);
the first owner registers through `POST /api/v1/register`.

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

## Mobile

GitHub variable `MOBILE_API_BASE_URL` = `https://hisbah-api-alur.onrender.com/api/v1` (used by the release and
patch workflows). Local development keeps `env/dev.json`.

## Local secrets (release PC only, `%USERPROFILE%\hisbah-release`, user-only ACL)

`aiven-api-token.dpapi`, `shorebird-api-key.dpapi`, `keystore-password.dpapi` (DPAPI), signing and patch keys.
The Render CLI login token is in `%USERPROFILE%\.render\cli.yaml`.

## Scripts

`backend/tool/deploy/`: `aiven_free_mysql.ps1` (free plan only), `migrate_new_aiven_db.ps1` (Aiven host
only, stops on foreign tables), `render_free_service.ps1` (free plan, no duplicates), DPAPI secret helpers.
