# Remaining blockers (updated 2026-11-09)

What still stops a Google Play submission, after this round's implementation. Nothing was deployed,
uploaded or submitted.

## Resolved in code this round (uncommitted)

| Was | Now |
|---|---|
| B-1 Payments: WhatsApp payment CTA in the app | **FIXED** — the Android app is consumption-only: no WhatsApp/payment button, no payment wording, no contact-to-pay details (`subscription_expired_screen.dart`, More tab). Purchasing moved to the website (plan picker + WhatsApp request + admin confirmation). Tests assert no WhatsApp/payment text appears |
| B-2 No account deletion | **FIXED** — in-app, website settings, public `/delete-account`, admin review; ACCOUNT_DELETION_PLAN.md |
| S-3 Shared proxy IP could let one client block sign-up for all | **FIXED** — limiters keyed per IP + number with a looser IP ceiling; test proves a flood on one number does not block another |

## Still blocking submission

| ID | Blocker | Owner of the next step |
|---|---|---|
| P-1 | **Privacy policy not published** and not linked in the app (draft ready; in-app link appears only when built with `PRIVACY_POLICY_URL`) | owner: LEGAL_INFORMATION_REQUIRED.md, legal review, publish |
| P-2 | **Terms not published** (draft ready) | owner |
| P-3 | Changes not deployed: production lacks the new tables, `/delete-account` page and admin pages; the Play AAB must come from a full Shorebird release built after merge | owner: OWNER_ACTIONS.md §B |
| P-4 | **Scheduler** not running on Render free plan → scheduled store closures never execute | owner: add a cron |
| P-5 | Play Console: account type/closed test (12 × 14 days if personal), app signing choice, demo account, Data safety, IARC, target audience, store listing | owner |
| P-6 | **Signed release AAB** can only be built by CI with the real keystore (not on this PC; never with a test key) | owner runs `mobile-release.yml` |
| P-7 | Real-device testing, incl. Bluetooth printing on Android 12+ | owner/QA |

## Security items needing the owner

| ID | Item | Status |
|---|---|---|
| S-1 | Backups are unencrypted gzip SQL in a private GitHub repo; history keeps them forever | BLOCKED — design in OWNER_ACTIONS §C.2; history rewrite needs your explicit approval |
| S-2 | Production `APP_KEY` vs committed test key | UNVERIFIED — reading production config was not permitted; script provided |
| S-4 | DB account privileges (Aiven) | UNVERIFIED |
| S-5 | Website CSP in report-only | owner switches to enforcing after observation |
| S-6 | Payment provider: no docs/credentials | BLOCKED — online payment stays disabled |

## Release-engineering notes
- R-2 Obfuscation not enabled (optional; must be added to both release and patch workflows).
- R-4 `backend/package.json` has no lockfile.
- Ownership-transfer exists in the API but has no button in app/web yet.
- Expiry notices are recorded and shown in-app/web, not sent by SMS/WhatsApp.
