# DR-2 — Visual foundation (US-1506, US-1501, US-1507 hi-fi)

> **Status: PART 1 PENDING TL DECISION.** No visual direction is approved. The Flutter app keeps its neutral theme until part 2 is signed off.

DR-2 is one review in two touchpoints (14 §5.8).

## Part 1 — direction pick

| Review | File |
|---|---|
| The two directions on login + POS cart, with rationale and trade-offs | [../mockups/directions.html](../mockups/directions.html) (open on a phone too: the frames are 360 px wide) |
| Tokens and colour roles | [../tokens.json](../tokens.json), [../design-system.md](../design-system.md) |
| Contrast (TC-1501-01) | [../contrast-report.md](../contrast-report.md) — 58 / 58 pairs pass |

| Decision | Options |
|---|---|
| **Direction** | ☐ A · دفتر Ledger ☐ B · كاونتر Counter ☐ Revise (say what) |
| **Typeface (UI-D2)** — independent of the direction | ☐ IBM Plex Sans Arabic (same as the web) ☐ Noto Sans Arabic |
| **Digits (UI-D1)** | ☐ Western `27.50` (proposed) ☐ Arabic-Indic `٢٧٫٥٠` |

TL decision — date: 2026-10-15 (direction) and 2026-10-19 (typeface, digits) · notes: **Direction A · دفتر Ledger**; typeface **IBM Plex Sans Arabic** (same as the web); digits **Western** `27.50` (blanket approval of the recommendations).

## Part 2 — sign-off (after part 1)

Prepared only after the direction is picked, in that direction:

- hi-fi auth and shell screens (US-1507): every state in [../ia.md](../ia.md) §4.1–4.2;
- component state sheet and RTL / bidi sample sheet (US-1501);
- 130 % text-size check and phone viewing.

| Field | Value |
|---|---|
| Date | |
| Outcome | ☐ Approve ☐ Revise |
| Notes | |

Approval unblocks visual styling in Flutter (theme from the chosen tokens).
