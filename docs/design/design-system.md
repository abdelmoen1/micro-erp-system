# Mobile Design System — Foundation (US-1501)

> **PROPOSAL — for DR-2.** Values live in [tokens.json](tokens.json); contrast is verified by [tools/contrast.php](tools/contrast.php) → [contrast-report.md](contrast-report.md) (TC-1501-01). The two candidate palettes are compared in [mockups/directions.html](mockups/directions.html); after DR-2 part 1 the unchosen palette is deleted.

## 1. Rules that hold for any direction

| Area | Rule |
|---|---|
| Direction | RTL by default (Arabic). Layout uses start/end, never left/right. |
| Type | One Arabic typeface, bundled in the app (UI-D2: IBM Plex Sans Arabic or Noto Sans Arabic). Body 16 sp minimum; scale 13 / 14 / 16 / 20 / 24; money 22 and hero 34–38. Must survive 130 % system text size without clipping. |
| Digits and money | Western digits (UI-D1, proposed). Tabular figures. Always `₪` + 2 decimals (`₪ 27.50`). Money, phone numbers, invoice numbers and dates are **isolated LTR runs** inside Arabic text (Flutter: `TextDirection.ltr` span; HTML: `unicode-bidi: isolate`). Amounts come from the API as strings and are never re-computed with floating point in the UI. |
| Colour | Roles first, palette second. Colour never carries meaning alone: every status has a label and an icon (UI-AC-05). |
| Size | Touch targets ≥ 48 dp; primary bar 56 dp; list rows ≥ 64 dp; 4-pt spacing scale (4 · 8 · 12 · 16 · 24 · 32 · 48). |
| Borders | `border` is decorative (dividers). Anything that identifies a control (input outline, stepper) uses `borderStrong` (≥ 3:1). |
| Focus | Visible focus ring in `focus` (on light surfaces) or `focusOnChrome` (on the dark chrome). |
| Feedback | Scan accepted: haptic + short sound + line highlight. Errors are inline next to their cause, never only a toast. |

## 2. Colour roles

| Role | Use |
|---|---|
| `page`, `surface`, `surfaceRaised` | Screen background, content areas, inputs |
| `textPrimary`, `textSecondary` | Content; labels, hints and secondary values |
| `action`, `onAction`, `actionSoft` | The one primary action per screen; its text; selected / soft backgrounds |
| `chrome`, `onChrome` | App bar and total bar (in B they are the dark brand navy) |
| `border`, `borderStrong`, `focus`, `focusOnChrome` | See §1 |
| `paid` · `partial` · `debt` · `return` · `voided` · `lowStock` · `pending` · `error` (+ `…Tint`) | Status only. **`debt` is deliberately not the error red**: owing money is a normal state, not a failure. |

## 3. Components and their states

Every component is specified with all of its states; DR-2 part 2 reviews a state sheet drawn in the chosen direction.

| Component | Purpose | States |
|---|---|---|
| `MoneyText` | Formats `"27.5"` → `₪ 27.50`, tabular, LTR-isolated | normal · hero · negative / refund (with sign and `return` role) · strikethrough (voided) |
| `QuantityStepper` | − / value / +, direct entry on tap | default · pressed · disabled at min (1) · disabled at max (stock, S2+) · focused (keyboard) |
| `StatusChip` | Label + icon + colour role | paid · partial · debt · return · voided · low stock · pending sync |
| `ConfirmSummary` | Key/value summary + named commit button | default · submitting (button disabled with progress) · failed (inline error, retry with same key) |
| `ListRow` (with balance) | Customer / product / cart rows | default · pressed · selected · highlighted (just scanned) · swiped (remove + undo) |
| `TextField` | Labelled input with inline validation | empty · focused · filled · error (message under field) · read-only · disabled |
| `PrimaryBar` | Sticky bottom area with the screen's single primary action | enabled · disabled (with reason) · loading |
| `MessageBanner` | Form-level message (invalid credentials, throttled countdown, network) | info · warning · error · countdown |
| `OfflineBanner` | Under the app bar while the server is unreachable | shown / hidden |
| `EmptyState`, `ErrorState`, `Skeleton` | Mandatory per screen (06 §1) | — |

## 4. Accessibility checks at DR-2

1. Contrast report: all pairs pass (generated, not hand-written).
2. 130 % text size: the login, cart and checkout frames are re-checked at 130 % in the chosen direction.
3. RTL / bidi sheet viewed on a phone: mixed Arabic text with money, phone numbers, Latin product names and dates.
4. Screen-reader labels on icon-only buttons (scan, show password, stepper).

## 5. Flutter mapping (after DR-2 sign-off only)

`tokens.json` (chosen direction) → `lib/core/theme/` (`ColorScheme` + a `ThemeExtension` for the status roles and money styles). Until sign-off the app uses `AppTheme.neutral()`.
