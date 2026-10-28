import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/features/scanner/application/scan_cue.dart';

class CountingBeep implements ScanBeep {
  int plays = 0;

  @override
  Future<void> play() async => plays++;
}

void main() {
  late CountingBeep beep;
  late int haptics;
  late DateTime now;
  late ScanCue cue;

  setUp(() {
    beep = CountingBeep();
    haptics = 0;
    now = DateTime(2026, 10, 28, 9);
    cue = ScanCue(beep: beep, haptic: () async => haptics++, clock: () => now);
  });

  tearDown(() => cue.dispose());

  test('one good read: one beep, one haptic, one pulse', () {
    expect(cue.success(), isTrue);
    expect((beep.plays, haptics, cue.pulses.value), (1, 1, 1));
  });

  test('reads inside the gap collapse into one cue; a later read plays again', () {
    cue.success();
    now = now.add(const Duration(milliseconds: 120));
    expect(cue.success(), isFalse);
    now = now.add(const Duration(milliseconds: 200));
    expect(cue.success(), isFalse, reason: 'still inside 400 ms of the cue that played');
    now = now.add(const Duration(milliseconds: 400));
    expect(cue.success(), isTrue, reason: 'the same item scanned again after the previous one was handled');
    expect((beep.plays, haptics, cue.pulses.value), (2, 2, 2));
  });

  test('a failing tone never breaks the cue', () async {
    final quiet = ScanCue(beep: const PlatformScanBeep(), haptic: () async {}, clock: () => now);
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(quiet.success(), isTrue, reason: 'no platform channel in tests: the beep is swallowed');
    expect(quiet.pulses.value, 1);
    quiet.dispose();
  });
}
