# Legal information required from the owner

Nothing below was invented. Each item blocks publishing the Privacy Policy and/or the Terms.

**Where to put it (2026-11-10):** the public pages `/privacy` and `/terms` are built and read every owner
value from one file, `frontend/src/content/legal.js` (`null` shows «[بانتظار صاحب الخدمة]» on the page).
Fill it, have the text reviewed, then deploy the website. Items 1–4, 6, 7, 11, 12 and 14 map to its keys.

| # | Needed | Used in |
|---|---|---|
| 1 | Legal name of the operator (person or company) and registration number if any | Privacy §header, Terms §header, Play developer name consistency |
| 2 | Postal address | Privacy, Terms, Play (required for paid/merchant accounts) |
| 3 | Privacy contact e-mail (monitored) | Privacy §header/§7/§9, Play Console |
| 4 | Support contact: e-mail and/or WhatsApp Business number, hours | Terms §13, Play store listing, `WHATSAPP_BUSINESS_NUMBER` |
| 5 | Public HTTPS URLs — built: `https://hisbah-web.vercel.app/privacy`, `/terms`, `/delete-account`. Only needed if you move to your own domain | the app links to `/privacy` by default (`WEB_BASE_URL`), Play Console |
| 6 | Minimum age / target audience (proposed 18+, business users) | Privacy §1, Play target audience |
| 7 | Retention periods + legal basis: Hisbah payment records, trial hash, deletion records, admin access logs, backups, data of stores that never renew | Privacy §5, ACCOUNT_DELETION_PLAN, Terms §6 |
| 8 | Controller/processor roles for shops' customer and supplier data | Privacy §1 |
| 9 | Any purpose for platform-owner access beyond operating/support/billing/abuse (e.g. aggregated price insights) and how it is anonymised | Privacy §3 |
| 10 | Plan prices, currencies, features per plan, what limits apply | Terms §4, website, admin plans page |
| 11 | Accepted manual payment methods (bank transfer, Jawwal Pay transfer, cash, …); invoices/receipts; tax treatment | Terms §5 |
| 12 | Refund and cancellation policy (subject to applicable consumer law) | Terms §8 |
| 13 | Suspension notice period and appeal route | Terms §11 |
| 14 | Liability limits; governing law and courts | Terms §12, §14 |
| 15 | Data export commitment (no export feature exists) | Privacy §8, Terms §9 |
| 16 | Payment provider chosen (when it is) and its data handling | Privacy §4, PAYMENT_INTEGRATION_GUIDE |
| 17 | SMS gateway, if SMS codes are switched on | Privacy §4 |
| 18 | Confirmation of Shorebird's data collection from its current documentation | Privacy §4, Data safety |
| 19 | Legal review of both drafts and Arabic translation | both |
