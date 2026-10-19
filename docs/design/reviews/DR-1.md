# DR-1 — Structure and flows (US-1505, US-1502 low-fi, US-1507 low-fi)

> **Status: PENDING TL REVIEW.** Nothing in this review is approved until the decision below is filled in by the TL.

## What to review

| Item | File |
|---|---|
| Navigation map, role landing, inventory, flows, state matrix, status cues | [../ia.md](../ia.md) |
| Low-fi wireframes: F-0 sign-in / session / shell (frames 01–11), F-1 quick sale (frames 12–21) | [../wireframes/lowfi-s1.html](../wireframes/lowfi-s1.html) — open in a browser; at phone width it shows one frame per row |
| Real API responses behind every auth state | [../../api/auth.http](../../api/auth.http), [../../api/error-codes.md](../../api/error-codes.md) |

## Checklist (from 14 §5.7 / 06 §7)

| # | Check | Result |
|---|---|---|
| 1 | Every auth API response in the frozen contract appears in the state matrix (ia.md §4.1–4.2) | ☐ |
| 2 | Role landing: employee → POS, owner / manager → Home | ☐ |
| 3 | Walk-in cash sale ≤ 4 taps after the last scan (proposed: 3) | ☐ |
| 4 | Repeat scan shows one line with quantity +1 (UI-AC-01) | ☐ |
| 5 | Commit button names the action and amount; retry reuses the same key (UI-AC-02) | ☐ |
| 6 | Customer required whenever paid < total, error inline (UI-AC-03) | ☐ |
| 7 | Money always `₪` + 2 decimals (UI-AC-04) | ☐ |
| 8 | Cash / partial / credit / return separated by label + icon + shape, not colour (UI-AC-05) | ☐ |
| 9 | Every S1 screen has loading, empty / error and success states | ☐ |

## Questions for the TL

1. **Tab order.** 06 §2.1 orders the tabs Home · POS · Customers · Products · More. The low-fi proposes **POS in the centre** (Home · Customers · **POS** · Products · More): the centre is the easiest one-handed target and POS is the most-used screen. The Flutter scaffold currently follows the **06 order** until you decide; switching is a one-line change.
2. **Session-expired re-login** is a sheet over the current screen (frame 06) that keeps the cart. Acceptable, or a full login screen?
3. **Logout with a non-empty cart** asks for confirmation (frame 11). Keep?
4. **Credit sale due date** is optional (frames 16–17), as in 06. Should it default to a value (e.g. +30 days)?

## Known constraints shown in the designs

- Server validation messages are English until DEF-19 is fixed; the app validates in Arabic first (frame 02).
- Scanner hold-in-view behaviour (frame 13) is decided by the barcode spike (US-1305, D-31).
- F-1 server states for stock and credit limit are *planned* until the S2/S3 sale contract exists.

## Decision (TL)

| Field | Value |
|---|---|
| Date | 2026-10-19 |
| Outcome | ☑ Approve (blanket approval of the recommendations) ☐ Revise |
| Answers to Q1–Q4 | Q1 POS in the centre tab: yes. Q2 re-login sheet that keeps the cart: yes. Q3 confirm logout with a non-empty cart: yes. Q4 due date optional, with quick chips (+7 / +30 days) |
| Notes / required changes | Weighted goods (CR-13 modified): the cart needs a weight / amount entry sheet; repeat scan of a `kg` product opens that sheet instead of +1 |

A "revise" outcome uses the 0.125 dd P1 revision allowance (14 §5.7). DR-1 approval unblocks the US-1303 navigation skeleton being treated as final.
