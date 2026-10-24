import 'package:flutter/foundation.dart';

/// Build-time configuration from `--dart-define-from-file=env/<name>.json`.
abstract final class Env {
  static const _definedApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the Laravel API v1. Without a define, debug and profile builds reach
  /// the host machine from the Android emulator (real phones need the PC's LAN address).
  /// Release builds have no fallback: they must be built with an explicit URL
  /// (the CI release and patch workflows pass the deployed HTTPS URL), so a release
  /// never silently points at a development machine.
  static const apiBaseUrl = _definedApiBaseUrl != ''
      ? _definedApiBaseUrl
      : (kReleaseMode ? '' : 'http://10.0.2.2:8000/api/v1');
}
