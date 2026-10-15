import 'package:flutter/material.dart';

/// Direction A "Ledger" (docs/design/tokens.json 0.2.0-draft, hi-fi board US-1507 P2).
/// Selected by the TL on 2026-10-15 (DR-2 part 1); final DR-2 approval is still PENDING.
abstract final class HisbahColors {
  static const ground = Color(0xFFF2EEE4); // also the logo's own background
  static const surface = Color(0xFFFBF9F4);
  static const raised = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2DBCD);
  static const borderStrong = Color(0xFF948B7B);
  static const ink = Color(0xFF14262E);
  static const inkMuted = Color(0xFF4E5856);
  static const inkSubtle = Color(0xFF5F6A68);
  static const primary = Color(0xFF176D73);
  static const primaryPressed = Color(0xFF0E4F54);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryTint = Color(0xFFE1ECE8);
  static const highlightRow = Color(0xFFE5EFEB);
  static const disabledBg = Color(0xFFE6E1D6);
  static const disabledInk = Color(0xFF566160);
  static const scrim = Color(0x7A14262E); // rgba(20,38,46,0.48)
  static const danger = Color(0xFF9A3B2A);
  static const dangerBorder = Color(0xFFD8C3BC);
  static const progressTrack = Color(0xFFDDD5C6);
  static const sheetHandle = Color(0xFFD6CEBF);
  static const placeholderBorder = Color(0xFFC9C0AF);
}

/// Semantic status roles (icon + label + colour; colour is never the only carrier).
enum StatusTone {
  error(Color(0xFFB42318), Color(0xFFFDECEA), Color(0xFFF4C7C1)),
  info(Color(0xFF1E5A8A), Color(0xFFE4F0FA), Color(0xFFC5DDF1)),
  offline(Color(0xFF14262E), Color(0xFFF3D9A4), Color(0xFFE5C27C)),
  pending(Color(0xFF14262E), Color(0xFFECEFF3), Color(0xFFD5DAE1)),
  voided(Color(0xFF3B4146), Color(0xFFECEDEE), Color(0xFFD3D5D8));

  const StatusTone(this.fg, this.bg, this.line);

  final Color fg;
  final Color bg;
  final Color line;
}

abstract final class HisbahRadius {
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
