# Backend on Render

The Laravel API (`backend/`) as a Render Docker web service, defined in [render.yaml](../../render.yaml).

| Piece | File |
|---|---|
| Image: PHP 8.2 + Apache, `pdo_mysql`, `bcmath`, `intl`, `opcache`; production Composer install; Vite assets for `/` | [backend/Dockerfile](../../backend/Dockerfile) |
| Start-up: listen on `$PORT`, `APP_URL` from `RENDER_EXTERNAL_URL`, refuse to start without `APP_KEY`, config/view cache. **No migrations.** | [backend/docker/entrypoint.sh](../../backend/docker/entrypoint.sh) |
| Apache vhost (document root `public/`, `.htaccess` routing), PHP production settings | [backend/docker/](../../backend/docker/) |
| HTTPS URLs behind Render's proxy (trusted `X-Forwarded-Proto/Host/Port`; `X-Forwarded-For` deliberately not trusted) | [backend/bootstrap/app.php](../../backend/bootstrap/app.php) |

Health check: `/up` (Laravel boots). It does **not** touch the database; see the verification below.

## Database requirement

Moving the data from Railway: [mysql-migration.md](mysql-migration.md).

The service needs the existing MySQL database, reachable **over the internet** from Render:

- A Railway `*.railway.internal` host only works inside Railway's private network. Render cannot reach it.
- Railway MySQL can be reached from outside only through its TCP proxy (Railway dashboard → MySQL → Settings →
  Networking → TCP Proxy), which gives a public host and port. That requires the MySQL service to be running.
- Never point the service at a new empty database, and never switch engines (e.g. to PostgreSQL) without a
  planned, backed-up data migration.

## Environment variables (Render dashboard → service → Environment)

Set by the Blueprint: `APP_ENV=production`, `APP_DEBUG=false`, `LOG_CHANNEL=stderr`, `LOG_LEVEL=info`,
`DB_CONNECTION=mysql`, `SESSION_DRIVER=database`, `CACHE_STORE=database`, `QUEUE_CONNECTION=database`.

Entered in the dashboard (secret, `sync: false`):

| Variable | Value |
|---|---|
| `APP_KEY` | the **existing** key of this application (copied from the previous host), never a new one |
| `DB_HOST`, `DB_PORT` | the database's public host and port |
| `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | the existing database credentials |
| `APP_URL` | optional; defaults to the Render URL |

## Create the service

1. Render Dashboard → **New → Blueprint** → repository `abdelmoen1/micro-erp-system`, branch `main`
   (after this branch is merged) → Render reads `render.yaml` and asks for the `sync: false` values.
2. First deploy: watch the build and runtime logs.

Migrations never run inside the container. Production deploys go through the pipeline below.

## Deploys: backup → migrate → deploy

On 2026-11-25, Render auto-deployed #56 from `main` a day before its migrations ran. The code read
`inventory_reservations` before that table existed, so every sale, purchase and return failed. Two
safeguards now prevent this:

1. **`/up` fails while a migration is pending** (`App\Support\MigrationHealth`, config
   `hisbah.health_requires_migrations`). Render switches traffic only to a healthy deploy, so code that
   arrives before its migrations never serves, and the previous version stays live.
   `HEALTH_REQUIRES_MIGRATIONS=false` turns this off. Use it only for a deliberate rollback of the code onto a
   newer schema.
2. **One pipeline deploys the API.** Render auto-deploy is off (`autoDeployTrigger: "off"`).
   - When the backend tests pass on `main`, the CI job «Deploy API» starts the workflow `deploy-api.yml` in the
     private repository `abdelmoen1/hisbah-db-backups`. That repository already holds the database secrets.
   - The workflow checks that the commit is on `main` and its backend tests passed, and reads what production runs
     from `GET /api/v1/version`.
   - It skips the deploy when nothing under `backend/` changed.
   - If migrations are pending, it backs up first (`backup.yml`), then runs `php artisan migrate --force`.
   - It then calls the Render deploy hook and waits until `/api/v1/version` reports the commit.
   - A failed step stops everything after it, and GitHub emails the owner.

To deploy a commit by hand: `hisbah-db-backups` → Actions → «Deploy API» → Run workflow, with the full SHA.

### One-time setup (owner)

| Where | What |
|---|---|
| Render → `hisbah-api` → Settings → Build & Deploy | **Auto-Deploy: Off** (the dashboard setting wins over `render.yaml` unless the service is Blueprint-synced) |
| Render → `hisbah-api` → Settings → Deploy Hook | copy the URL into the `hisbah-db-backups` secret **`RENDER_DEPLOY_HOOK_URL`** |
| GitHub → Settings → Developer settings → Fine-grained token | repository access: only `hisbah-db-backups`; permission **Actions: Read and write**; nothing else |
| `micro-erp-system` → Settings → Secrets → Actions | that token as **`DEPLOY_DISPATCH_TOKEN`** |

The token can only start workflows in the backups repository. It cannot read the dumps or the database secrets.
Until it is set, the «Deploy API» CI job fails on `main` and says so.

### Checking production

- `GET /api/v1/version` returns the commit Render built (`RENDER_GIT_COMMIT`).
- `GET /up` returns 200 only when the database answers and every migration has run.

## Verify before switching the app

Replace `<url>` with the URL Render assigns (`https://<name>.onrender.com`):

| Check | Expected |
|---|---|
| `GET <url>/up` | 200 (Laravel boots; says nothing about the database) |
| `GET <url>/api/v1/me` with `Accept: application/json` | 401 `UNAUTHENTICATED` JSON |
| `POST <url>/api/v1/login` with `{}` | 422 `VALIDATION_FAILED` JSON |
| `POST <url>/api/v1/login` with an unknown `@example.invalid` email | 401 `INVALID_CREDENTIALS`: proves a real `users` query (only side effect: a 60 s throttle counter) |
| Login with a real account, then `GET /api/v1/me` | 200 with the user: token handling works |
| Any error response | JSON envelope with `correlation_id`, no stack trace |

Only then change `MOBILE_API_BASE_URL` (GitHub variable used by the mobile release/patch workflows) to
`<url>/api/v1`.

## Free plan limits

- The service spins down after 15 minutes without traffic; the next request waits about a minute while it starts.
  Not suitable for a shop that needs instant responses at all times (a paid instance type avoids this).
- 750 free instance hours per workspace per month; when they run out, free services stop until the next month.
- The filesystem is temporary (lost on redeploy/restart/spin-down). The API stores no files, so this is fine.
- Outbound SMTP ports are blocked on free services (mail is `log` today).
- `routes/console.php` schedules `idempotency:prune` daily. Nothing runs the scheduler on a free web service, so
  old idempotency keys (older than 30 days) are not pruned automatically. This is harmless at current volumes;
  run it by hand from the Render shell when needed, or add a Render cron job (paid).
