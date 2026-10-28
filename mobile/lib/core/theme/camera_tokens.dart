import 'package:flutter/material.dart';

/// Camera-context tokens from the S2 scanner spec (T-1301-7, spec 0.1, "Proposed additions").
///
/// PROPOSED, PENDING APPROVAL: these are not part of tokens v0.2 yet. They live only in this
/// file so that approving, changing or dropping them is a one-file change.
/// Flat colours only (no blur, gradients or looping animation: Galaxy A01 class devices).
abstract final class CameraTokens {
  /// `camera.scrim`: rgba(0,0,0,.56) outside the frame. White text on it stays ≥ 4.95:1.
  static const scrim = Color(0x8F000000);

  /// Background behind the preview before the first camera frame arrives.
  static const background = Color(0xFF0B1418);

  /// `camera.control`: 48 dp circle rgba(20,38,46,.72), white icon. Torch "on" = white fill + ink icon.
  static const control = Color(0xB814262E);
  static const controlSize = 48.0;

  /// `camera.frame`: 296 × 168 dp, corner arm 32, stroke 4 dp white, radius 14.
  /// Locked (code read): closed outline + 36 dp ✓ badge.
  static const frameSize = Size(296, 168);
  static const frameArm = 32.0;
  static const frameStroke = 4.0;
  static const frameRadius = 14.0;
  static const frameColor = Color(0xFFFFFFFF);
  static const badgeSize = 36.0;

  /// `camera.instruction`: 17/600 white, one line, centred above the frame.
  static const instruction = TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.4);

  /// `camera.status`: pill 30 dp, rgba(20,38,46,.72), 13 px white + 8 dp dot
  /// (white = scanning, #7FD1C2 = read).
  static const statusHeight = 30.0;
  static const statusText = TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4);
  static const statusDot = 8.0;
  static const dotScanning = Color(0xFFFFFFFF);
  static const dotRead = Color(0xFF7FD1C2);

  /// The glow around the frame after a good read (same mint as the read dot), and how long it lasts.
  static const pulse = Color(0xFF7FD1C2);
  static const pulseDuration = Duration(milliseconds: 450);

  /// `camera.hint`: rgba(20,38,46,.86) card, 14 px text, shown after [hintDelay] without a read.
  static const hint = Color(0xDB14262E);
  static const hintText = TextStyle(color: Colors.white, fontSize: 14, height: 1.6);
  static const hintDelay = Duration(seconds: 8);

  /// `camera.manualButton`: 56 dp white on camera, ink text + keyboard icon, 16 dp from the bottom.
  static const manualButtonHeight = 56.0;
  static const manualButtonGap = 16.0;

  /// `sheet.maxHeight`: 62% of the app area (74% at 130% text); content scrolls, actions stay.
  static const sheetMaxHeight = 0.62;
  static const sheetMaxHeightLargeText = 0.74;
}
