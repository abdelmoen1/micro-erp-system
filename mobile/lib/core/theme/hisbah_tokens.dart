import 'package:flutter/material.dart';

/// Direction A "Ledger" (docs/design/tokens.json 0.2.0-draft, hi-fi board US-1507 P2).
/// Selected by the TL on 2026-10-15 (DR-2 part 1); final DR-2 approval is still PENDING.
/// Brand palette (2026-10-22): deep teal #10565B, secondary teal #176D73, warm ground #F2EEE4,
/// card #FBF9F4, pale teal #E1ECE8, ink #14262E. Red is kept for errors, overdue debt and
/// destructive actions only.
/// 2026-10-28 refresh: a lighter, warmer ground and near-white cards with a soft shadow, so the app
/// reads brighter without changing the brand teal.
abstract final class HisbahColors {
  static const ground = Color(0xFFF6F3EC);
  static const surface = Color(0xFFFFFDFA);
  static const raised = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8E2D6);

  /// Soft card elevation (ink at 7 %): depth without heavy borders.
  static const shadow = Color(0x1214262E);
  static const borderStrong = Color(0xFF948B7B);
  static const ink = Color(0xFF14262E);
  static const inkMuted = Color(0xFF4E5856);
  static const inkSubtle = Color(0xFF5F6A68);
  static const primary = Color(0xFF10565B);
  static const primaryPressed = Color(0xFF0B4044);
  static const secondary = Color(0xFF176D73);
  static const onPrimary = Color(0xFFFFFFFF);

  /// Secondary text on [primary] (white at 80 %, 6.0:1).
  static const onPrimaryMuted = Color(0xCCFFFFFF);

  /// Hairline on [primary] (white at 24 %): rules and outlines inside the teal hero.
  static const onPrimaryLine = Color(0x3DFFFFFF);
  static const primaryTint = Color(0xFFE1ECE8);

  /// Teal outline on light surfaces (secondary teal at 45 %): outlined chips.
  static const primaryOutline = Color(0x73176D73);
  static const highlightRow = Color(0xFFE5EFEB);
  static const disabledBg = Color(0xFFE6E1D6);
  static const disabledInk = Color(0xFF566160);
  static const scrim = Color(0x7A14262E); // rgba(20,38,46,0.48)
  static const danger = Color(0xFF9A3B2A);
  static const dangerBorder = Color(0xFFD8C3BC);
  static const progressTrack = Color(0xFFDDD5C6);
  static const sheetHandle = Color(0xFFD6CEBF);
  static const placeholderBorder = Color(0xFFC9C0AF);

  // S2 sale flow.
  static const dangerSolid = Color(0xFF9A3B2A); // «إلغاء الفاتورة نهائياً»
  static const segmentTrack = Color(0xFFE9E3D7);
  static const voidStamp = Color(0xFF50565C);
  static const receiptRule = Color(0xFFCFC7B8);
  static const skeleton = Color(0xFFECE6DA);
  static const stockNote = Color(0xFFFFF6EE);
  static const unitChipLine = Color(0xFFD6CEBF);
}

/// Semantic status roles (icon + label + colour; colour is never the only carrier).
enum StatusTone {
  error(Color(0xFFB42318), Color(0xFFFDECEA), Color(0xFFF4C7C1)),
  info(Color(0xFF1E5A8A), Color(0xFFE4F0FA), Color(0xFFC5DDF1)),
  offline(Color(0xFF14262E), Color(0xFFF3D9A4), Color(0xFFE5C27C)),
  pending(Color(0xFF14262E), Color(0xFFECEFF3), Color(0xFFD5DAE1)),
  voided(Color(0xFF3B4146), Color(0xFFECEDEE), Color(0xFFD3D5D8)),

  // Design System 0.2 status roles used by the S2 scanner (found / not found). DS 0.2 gives no
  // border colour for these two, so [line] repeats [bg].
  paid(Color(0xFF1F6B3A), Color(0xFFE2F0E6), Color(0xFFE2F0E6)),
  debt(Color(0xFFA2381F), Color(0xFFF9E6E0), Color(0xFFF9E6E0)),

  // S2 sale flow (M-02 … M-06): partial payment, a warning the cashier may continue past
  // (negative stock, owner credit-limit override), a scan that worked, and neutral notices.
  partial(Color(0xFF765400), Color(0xFFF7EFD2), Color(0xFFF7EFD2)),
  warning(Color(0xFF9A4300), Color(0xFFFCE7D3), Color(0xFFEFC9A6)),
  success(Color(0xFF1F6B3A), Color(0xFFE2F0E6), Color(0xFFBFDCC8)),
  neutral(Color(0xFF4A5565), Color(0xFFECEFF3), Color(0xFFD5DAE1));

  const StatusTone(this.fg, this.bg, this.line);

  final Color fg;
  final Color bg;
  final Color line;
}

abstract final class HisbahRadius {
  /// Icon chips inside cards and rows.
  static const chip = 10.0;
  static const field = 14.0;
  static const button = 16.0;
  static const card = 18.0;
  static const sheet = 28.0;
}

abstract final class HisbahSize {
  static const touchMin = 48.0;
  static const field = 56.0;
  static const button = 56.0;
}
