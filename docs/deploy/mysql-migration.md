# Moving the production MySQL from Railway to Render

The only copy of production data is the Railway volume `mysql-volume` (project `powerful-charm`, service `MySQL`,
about 197 MB including MySQL's own system files). Every step below keeps that volume untouched: it is read through
a logical dump and never deleted, replaced or re-initialised.

## Facts this plan is based on (checked 2026-10-16)

| | |
|---|---|
| Railway billing state | `INACTIVE` (no active subscription), plan Hobby. API deployment `REMOVED`; MySQL has no running deployment |
| Volume | `mysql-volume`, mounted at `/var/lib/mysql`, not deleted, not pending deletion |
| Railway volume backups on this plan | none (`maxBackupsCount: 0`) |
| Image that last wrote the data | `mysql:9` at digest `sha256:e2bde46db6563855d7177adb5f0b57b9dc663f5a20927a90f4259d3312068497` = **MySQL 9.7.2** (built 2026-09-29), still pullable. The `mysql:9` tag has moved since |
| Network | API used the private `*.railway.internal` host; MySQL has **no** public TCP proxy (and none is needed below) |
| Database features used by the app | InnoDB row locks (`lockForUpdate`), JSON columns (audit logs), utf8mb4 tables from Laravel migrations |

## Destination: MySQL as a Render private service (recommended)

`backend/docker/mysql/` (same MySQL 9.7.2 image digest, small-memory settings) as a Render **private service**
with a persistent disk, in the same region and workspace as the API (Frankfurt):

- Not reachable from the internet at all; the API reaches it over Render's private network (free web services
  can send private-network requests).
- Same server version as the source: the dump restores without version conversion, and table checksums compare 1:1.
- Cost: smallest paid instance $7/month (512 MB) + disk $0.25/GB/month (1 GB → $0.25; 10 GB → $2.50).
  The API web service can stay on the free plan (with its spin-down).
- Backups: Render snapshots disks daily (kept at least 7 days), but restoring a database from a disk snapshot is
  not recommended by Render. Take logical dumps (`mysqldump`, as in step 3) before every risky change.
- A service with a disk runs a single instance and has a short downtime on each deploy.

Alternatives considered:

| Option | Why not first choice |
|---|---|
| Aiven for MySQL, free tier | Public endpoint (TLS), may be powered off after inactivity, free-tier specs/backups not documented; MySQL 8 (dump from 9.7 needs a compatibility check) |
| Railway with a public TCP proxy | Keeps paying Railway and exposes MySQL to the internet (the decision was to leave Railway) |
| TiDB / other MySQL-compatible services | Not MySQL; locking and JSON behaviour differ |
| A fresh empty database | Never: production data would be lost |

## Sequence (each step needs explicit approval)

### 0. Prerequisite (owner, billing): reactivate Railway
Railway dashboard → workspace **Billing** → reactivate the **Hobby** plan ($5/month including $5 usage).
Needed only long enough to take the dump; nothing else changes.

### 1. Start MySQL on its existing volume, pinned, with the API kept stopped
1. Railway → `MySQL` service → Settings → Source image: change `mysql:9` to
   `mysql@sha256:e2bde46db6563855d7177adb5f0b57b9dc663f5a20927a90f4259d3312068497` (the exact server that wrote the data).
2. Check that the volume `mysql-volume` is still attached at `/var/lib/mysql` (Settings → Volumes).
3. Deploy **only** `MySQL`. Do not redeploy `micro-erp-system`: with the API stopped, nothing writes, so the dump is a
   consistent final copy.
4. Logs must show the server starting on an existing data directory. If they show "Initializing database" or
   "--initialize", **stop**: the volume is not mounted and nothing must be written.

### 2. Baseline snapshot (read-only)
```
railway ssh -p <project> -e production -s MySQL -- sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" --batch --skip-column-names "$MYSQL_DATABASE"' < backend/tool/db/verification-snapshot.sql > snapshot-source.txt
```
Passwords stay inside the container (`$MYSQL_ROOT_PASSWORD` is expanded there, never locally).

### 3. Logical dump, streamed to the release PC (no public endpoint)
```
railway ssh ... -s MySQL -- sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction --routines --triggers --events --hex-blob --set-gtid-purged=OFF --no-tablespaces --databases "$MYSQL_DATABASE" > /tmp/hisbah.sql && sha256sum /tmp/hisbah.sql'
railway ssh ... -s MySQL -- cat /tmp/hisbah.sql > hisbah-<date>.sql
sha256sum hisbah-<date>.sql      # must equal the checksum printed inside the container
```
Keep the dump in `%USERPROFILE%\hisbah-release\backups\` (user-only folder), never in the repository.
Railway is left as it is (volume intact) until step 7.

### 4. Create the destination (Render, owner approves the cost)
Render → New → **Private Service** → this repo, root directory `backend/docker/mysql`, Docker, Frankfurt,
instance $7/month, disk mounted at `/var/lib/mysql` (1–10 GB). Environment (secret, dashboard only):
`MYSQL_ROOT_PASSWORD`, `MYSQL_DATABASE` (same name as the source), `MYSQL_USER`, `MYSQL_PASSWORD`.
The first start initialises an empty data directory; nothing points at it yet.

### 5. Restore and verify
1. Stream the dump in through Render SSH (paid services): `ssh <service>@ssh.frankfurt.render.com 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"' < hisbah-<date>.sql`.
2. Run the same snapshot script on the target → `snapshot-target.txt`.
3. `diff snapshot-source.txt snapshot-target.txt` must show no differences: same tables, exact row counts,
   checksums, migrations and schema. Any difference: stop, the source stays untouched.
4. The application user (`MYSQL_USER`) already has rights on `MYSQL_DATABASE` only (the MySQL image grants them on
   first start); the API never uses root.

### 6. Point the Render API at it
Render API service environment: `DB_HOST=<private service internal hostname>`, `DB_PORT=3306`, `DB_DATABASE`,
`DB_USERNAME`, `DB_PASSWORD` (the application user), and `APP_KEY` copied from Railway's `micro-erp-system`
variables (same key, so existing tokens and encrypted values stay valid). Then the checks in
[render.md](render.md#verify-before-switching-the-app): `/up`, 401/422 contracts, unknown-user login (401 =
real query), real login + `/me`.

### 7. Switch, then retire Railway
- Only after step 6 passes: `MOBILE_API_BASE_URL` → `<render url>/api/v1` (separate, reviewed change).
- Keep Railway's volume until the Render setup has run cleanly for a while; cancelling the Railway plan and
  deleting the volume are separate, later decisions.

## Confirmed only when the services run
Checked at the start of steps 2–5, before relying on them: `railway ssh` forwards stdin/stdout byte-for-byte
(compare checksums), `mysqldump` exists in the 9.7.2 image (`mysqldump --version`), and Render SSH sessions see
the service's environment variables. If one fails, the step pauses; there is no fallback that exposes MySQL publicly
without a separate decision.

## Rollback at any point
Until step 7, Railway's volume is unchanged: pointing back means reactivating the Railway API service.
