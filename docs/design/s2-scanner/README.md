# S2 · T-1301-7 — Barcode scan + product lookup (hi-fi, Direction A)

> **FOR REVIEW, NOT APPROVED.** Spec 0.1. Implemented in `mobile/lib/features/scanner/`.

| File | What |
|---|---|
| [states/](states/) | 20 states at 360 × 760 dp: A entry · B permission · C scanner / torch / hint / detected · D found · E not found · F denied / blocked · G manual · H network / 5xx / 401 · 130% text |
| [screen-family-gallery.png](screen-family-gallery.png) | All states as one family, with the annotated primary scanner |
| [interaction-spec.png](interaction-spec.png) | Interaction spec, design-system summary (reused + proposed camera tokens), recovery matrix, checklist, open decisions U-1…U-10, contradictions with earlier decisions |

The clickable prototype and the source boards (`ScannerPhone`, `S2-Gallery`, `S2-Spec`, Design System 0.2) live on
the design canvas "Hisbah · Mobile UI/UX (S1 + S2)". They are references only; the app builds native Flutter widgets.

## How the app maps the spec

- **Tokens:** reused roles come from `mobile/lib/core/theme/hisbah_tokens.dart` (tokens v0.2; `StatusTone.paid` and
  `StatusTone.debt` added from Design System 0.2). The proposed camera tokens are only in
  `mobile/lib/core/theme/camera_tokens.dart`, marked *proposed, pending approval*.
- **Camera:** behind one interface, `BarcodeCamera` / `CameraPermissions`
  (`mobile/lib/features/scanner/domain/barcode_camera.dart`), implemented with mobile_scanner (bundled ML Kit) and
  permission_handler. The US-1305 spike can swap the library without touching the screens.
- **API:** `GET /products/lookup?barcode=` (docs/api/products.http): 200 → D, 404 (also inactive) → E, network / 5xx → H,
  401 → the global session handler (M-01 «انتهت الجلسة», back to بيع without the scanner).
- **Not implemented on purpose:** the «بيانات توضيحية» chip and «معاينة كاميرا محاكاة» caption (prototype-only labels).

## Open decisions (TODO in code)

U-1 offline banner wording (kept verbatim) · U-2 entry placement in the real بيع screen · U-3 manual entry rules (only
empty input refused) · U-4 lookup contract (implemented from products.http; inactive = 404) · U-5 beep (off) ·
U-6 stock display (shown as-is, no low-stock badge) · U-7 camera auto-pause (none) · U-8 formats / confirmation /
cooldown (EAN-13/8, UPC-A/E, Code 128; first read wins) · U-9 lookup timeout (ApiClient defaults) · U-10 rationale
before the first system dialog (none). Plus C4: Android CONFIRM haptic is not exposed by Flutter; `mediumImpact` stands in.
