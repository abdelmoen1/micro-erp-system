/// D-31 (approved option 1): a 1.5 s per-code cooldown between accepted scans.
///
/// The camera reports a barcode many times per second while it stays in view. The cooldown is
/// measured from the LAST sighting of that code, so a barcode held in front of the camera is
/// added once; it is accepted again after it has been out of view for [cooldown] (a deliberate
/// second scan). Different codes never block each other. Still to confirm on the device (D-31).
class RepeatScanGuard {
  RepeatScanGuard({this.cooldown = const Duration(milliseconds: 1500), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Duration cooldown;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastSeen = {};

  /// True when [code] should be acted on now; false for a repeat inside the cooldown.
  bool accept(String code) {
    final now = _clock();
    final last = _lastSeen[code];
    _lastSeen[code] = now;
    _forgetOlderThan(now);
    return last == null || now.difference(last) >= cooldown;
  }

  void reset() => _lastSeen.clear();

  void _forgetOlderThan(DateTime now) {
    _lastSeen.removeWhere((_, seen) => now.difference(seen) >= cooldown * 4);
  }
}
