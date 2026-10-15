/// Build-time configuration from `--dart-define-from-file=env/dev.json`.
abstract final class Env {
  /// Base URL of the Laravel API v1. The default reaches the host machine
  /// from the Android emulator; real phones need the PC's LAN address.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1');
}
