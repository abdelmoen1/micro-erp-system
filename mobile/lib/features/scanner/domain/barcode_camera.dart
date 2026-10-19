import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Camera permission as the scanner needs it (S2 spec, Permission (B) / F).
enum CameraPermission {
  granted,

  /// Not granted yet, or denied once: the system dialog can still be shown.
  denied,

  /// "Don't ask again" / denied twice: only the app settings can grant it.
  permanentlyDenied,
}

/// Reads and requests the camera permission. Checked again every time the scanner opens.
abstract interface class CameraPermissions {
  Future<CameraPermission> status();

  /// Shows the Android system dialog when the OS still allows it.
  Future<CameraPermission> request();

  /// Opens this app's page in the Android settings.
  Future<bool> openSettings();
}

enum TorchMode { unavailable, off, on }

/// The single seam between the scanner screens and the camera / decoding library
/// (mobile_scanner today; the US-1305 spike may replace it without touching the UI).
/// One instance per scanner screen; the screen disposes it.
abstract interface class BarcodeCamera {
  /// Decoded codes from inside the scan window, as raw strings.
  Stream<String> get detections;

  /// Hidden in the UI while [TorchMode.unavailable] (no flash, or the camera is not running).
  ValueListenable<TorchMode> get torch;

  /// Rear camera, not mirrored. Only codes inside [scanWindow] (preview coordinates) count.
  Widget buildPreview(BuildContext context, Rect scanWindow);

  /// Stops decoding and freezes the preview (a code was read or a sheet is open).
  Future<void> pause();

  Future<void> resume();

  Future<void> toggleTorch();

  /// Releases the camera; the torch turns off with it.
  Future<void> dispose();
}
