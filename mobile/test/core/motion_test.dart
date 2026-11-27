import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/motion/motion.dart';
import 'package:smartshop/core/widgets/state_views.dart';
import 'package:smartshop/l10n/app_localizations.dart';

Widget _host(Widget child, {bool reduced = false}) => MaterialApp(
  locale: const Locale('ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

String _fmt(String a) => '[$a]';

Widget _count(String amount, {bool reduced = false}) => _host(
  CountUp(amount: amount, format: _fmt, builder: (_, text) => Text(text, key: const Key('n'))),
  reduced: reduced,
);

String _text(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('n'))).data!;

void main() {
  group('CountUp', () {
    testWidgets('counts from zero and lands on the exact figure', (tester) async {
      await tester.pumpWidget(_count('1250.50'));
      expect(_text(tester), '[0.00]');

      await tester.pump(const Duration(milliseconds: 200));
      final mid = double.parse(_text(tester).replaceAll(RegExp(r'[\[\]]'), ''));
      expect(mid, inExclusiveRange(0, 1250.50));

      await tester.pumpAndSettle();
      expect(_text(tester), '[1250.50]');
    });

    testWidgets('a new figure counts from the old one', (tester) async {
      await tester.pumpWidget(_count('100.00'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_count('200.00'));
      await tester.pump(const Duration(milliseconds: 16));
      final v = double.parse(_text(tester).replaceAll(RegExp(r'[\[\]]'), ''));
      expect(v, inInclusiveRange(100, 200));
      await tester.pumpAndSettle();
      expect(_text(tester), '[200.00]');
    });

    testWidgets('with animations turned off the figure shows at once', (tester) async {
      await tester.pumpWidget(_count('75.25', reduced: true));
      expect(_text(tester), '[75.25]');
    });
  });

  testWidgets('EntranceFade and GrowIn end fully shown', (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            EntranceFade(delay: Duration(milliseconds: 100), child: Text('a')),
            GrowIn(child: Text('b')),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final opacity = tester.widget<Opacity>(find.ancestor(of: find.text('a'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1);
    expect(tester.getSize(find.byType(GrowIn)).height, greaterThan(0));
  });

  testWidgets('Bump pops on a change and settles back to its size', (tester) async {
    Widget bump(int v) => _host(Center(child: Bump(value: v, child: const SizedBox(width: 40, height: 40))));
    await tester.pumpWidget(bump(1));
    await tester.pumpWidget(bump(2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byType(SizedBox).last).width, greaterThan(40));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(SizedBox).last).width, 40);
  });

  testWidgets('SuccessMark draws and settles', (tester) async {
    await tester.pumpWidget(_host(const Center(child: SuccessMark(color: Colors.green))));
    await tester.pumpAndSettle();
    expect(find.byType(SuccessMark), findsOneWidget);
  });

  testWidgets('EmptyView offers its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(EmptyView(icon: Icons.inbox, title: 'لا شيء', actionLabel: 'إضافة', onAction: () => taps++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    expect(taps, 1);
  });
}
