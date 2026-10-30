# SMS codes (OTP) with textbee

Sign-up, "forgot password" and a changed number can be confirmed with a 6-digit SMS code. The
code is sent by **textbee** (MIT, [textbee.dev](https://textbee.dev)) from an Android phone of the
team, with its own SIM. It costs nothing but that SIM's SMS plan; the hosted free plan sends
**50 messages a day, 300 a month**. Firebase phone sign-in needs a paid plan since September 2024.

Until the variables below are set, codes are **off**: sign-up and sign-in by phone work without a
code, and "forgot password" is hidden (`GET /auth/options` → `otp: false`).

## Turn it on (about 10 minutes)

1. Take an Android phone that stays on and charged in the shop or office, with a Jawwal or Ooredoo
   SIM that has an SMS bundle.
2. Create a free account at [textbee.dev](https://textbee.dev), install the textbee app from its
   site on that phone, sign in, and register the phone as a device. Allow it to send SMS.
3. In the textbee dashboard, create an **API key** and copy the **device ID**.
4. In Render → `hisbah-api` → Environment, add:

   | Variable | Value |
   |---|---|
   | `SMS_DRIVER` | `textbee` |
   | `TEXTBEE_API_KEY` | the API key |
   | `TEXTBEE_DEVICE_ID` | the device ID |
   | `SMS_DAILY_LIMIT` | `45` (stays under the free 50) |

5. Save; Render restarts the service. `GET /api/v1/auth/options` now answers `otp: true`, the app
   and the website show the code step, and "forgot password" appears.

## Limits built in

- A code: 6 digits, valid 10 minutes, 5 tries, one use; only its hash is stored (`phone_otps`).
- Per number: one code a minute, 5 an hour. Per IP: 10 an hour, and 3 requests a minute.
- Per day: `SMS_DAILY_LIMIT` codes for the whole system (503 `OTP_DAILY_LIMIT` after that).
- A login never sends a code, so the daily allowance goes to sign-ups and resets.

## Local development

`SMS_DRIVER=log` writes each message to `storage/logs/laravel.log` instead of sending it (never in
production).

## When the SMS does not arrive

textbee reaches the phone over the internet, so a phone that is offline, asleep or out of charge
sends nothing, while the API still answers as if it had. Keep it plugged in, online and exempt from
battery optimisation, and read a stuck message's status in the textbee dashboard.

Set `SUPPORT_WHATSAPP` on Render (digits only, e.g. `970599000000`). The code screens then offer
«اطلب الرمز على واتساب»; the person asks there, and the platform admin issues a code at
**/admin/support** (`POST /admin/otp-codes`) and reads it back. It is checked like an SMS code.
