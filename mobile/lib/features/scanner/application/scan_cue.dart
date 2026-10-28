import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The short tone after a good read. On Android, MainActivity plays it with ToneGenerator on the
/// notification stream, so a phone on silent stays silent; without the channel it does nothing.
abstract interface class ScanBeep {
  Future<void> play();
}

class PlatformScanBeep implements ScanBeep {
  const PlatformScanBeep();

  static const _channel = MethodChannel('hisbah/scan_feedback');

  @override
  Future<void> play() async {
    try {
      await _channel.invokeMethod<void>('beep');
    } on PlatformException {
      // Sound is a nicety: a failed tone never breaks the scan.
    } on MissingPluginException {
      // Tests and platforms without the channel.
    }
  }
}

/// One confirmation per accepted read: a short beep, one light haptic and a pulse on the scan
/// frame ([pulses] counts up; the frame animates on each change).
///
/// Callers fire it only for a real decode the screen acts on (after the repeat-scan guard), never
/// for empty values, camera errors or a code still in view. Cues closer than [minGap] collapse
/// into one, so a burst of reads never stacks sounds or restarts the animation mid-way.
class ScanCue {
  ScanCue({
    required this.beep,
    Future<void> Function()? haptic,
    this.minGap = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _haptic = haptic ?? HapticFeedback.lightImpact,
       _clock = clock ?? DateTime.now;

  final ScanBeep beep;
  final Future<void> Function() _haptic;
  final DateTime Function() _clock;
  final Duration minGap;
  final ValueNotifier<int> pulses = ValueNotifier(0);
  DateTime? _last;

  /// True when the cue played; false when it fell inside [minGap] of the previous one.
  bool success() {
    final now = _clock();
    final last = _last;
    if (last != null && now.difference(last) < minGap) return false;
    _last = now;
    unawaited(beep.play());
    unawaited(_haptic());
    pulses.value++;
    return true;
  }

  void dispose() => pulses.dispose();
}

final scanCueProvider = Provider<ScanCue>((ref) {
  final cue = ScanCue(beep: const PlatformScanBeep());
  ref.onDispose(cue.dispose);
  return cue;
});
