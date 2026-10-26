import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session_controller.dart';
import '../products/presentation/inventory_scanner_screen.dart' show openInventoryScanner;
import '../sale/presentation/sale_scanner_screen.dart' show openSaleScanner;

/// The user guide for a first-time user: it does not describe the app, it walks through it. Each
/// step opens the real screen (the inventory scanner, the sale scanner), so the product and the
/// invoice made here are real. Seen once per account on this phone; «المزيد» reopens it.

String _seenKey(int userId) => 'guide.done.$userId';

/// True once this account finished or dismissed the guide on this phone.
final guideSeenProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session is! SignedIn) return true;
  return await ref.watch(keyValueStoreProvider).read(_seenKey(session.user.id)) != null;
});

Future<void> _markSeen(WidgetRef ref) async {
  final session = ref.read(sessionProvider);
  if (session is! SignedIn) return;
  await ref.read(keyValueStoreProvider).write(_seenKey(session.user.id), DateTime.now().toIso8601String());
  ref.invalidate(guideSeenProvider);
}

Future<void> openUsageGuide(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const UsageGuideScreen()));

/// On Home until the guide is finished or put off: what it offers, «ابدأ» and «لاحقاً».
class GuideCard extends ConsumerWidget {
  const GuideCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(guideSeenProvider).value ?? true) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return Container(
      key: const Key('guide.card'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HisbahColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HisbahColors.primaryOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: HisbahColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.guideCardTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t.guideCardBody, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              // The theme's filled buttons are full width: share the row.
              Expanded(
                child: FilledButton(
                  key: const Key('guide.start'),
                  onPressed: () => openUsageGuide(context),
                  child: Text(t.guideStart),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(key: const Key('guide.later'), onPressed: () => _markSeen(ref), child: Text(t.guideLater)),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Step { welcome, addProduct, sale, done }

class UsageGuideScreen extends ConsumerStatefulWidget {
  const UsageGuideScreen({super.key});

  @override
  ConsumerState<UsageGuideScreen> createState() => _UsageGuideScreenState();
}

class _UsageGuideScreenState extends ConsumerState<UsageGuideScreen> {
  int _index = 0;
  bool _productAdded = false;

  List<_Step> _steps() {
    final session = ref.read(sessionProvider);
    // An employee sells but does not add products.
    final canAdd = session is SignedIn && session.user.canOverride;
    return [_Step.welcome, if (canAdd) _Step.addProduct, _Step.sale, _Step.done];
  }

  void _next() => setState(() => _index++);

  Future<void> _finish() async {
    await _markSeen(ref);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addProduct() async {
    final added = await openInventoryScanner(context);
    if (!mounted) return;
    if (added) {
      setState(() => _productAdded = true);
    }
  }

  Future<void> _sell() async {
    await openSaleScanner(context);
    if (mounted) _next();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final steps = _steps();
    final step = steps[_index.clamp(0, steps.length - 1)];
    final (icon, title, lines) = switch (step) {
      _Step.welcome => (Icons.waving_hand_outlined, t.guideWelcomeTitle, [t.guideWelcomeBody]),
      _Step.addProduct => (Icons.qr_code_scanner_rounded, t.guideAddTitle, [t.guideAdd1, t.guideAdd2, t.guideAdd3]),
      _Step.sale => (Icons.point_of_sale_rounded, t.guideSaleTitle, [t.guideSale1, t.guideSale2, t.guideSale3]),
      _Step.done => (Icons.check_circle_outline_rounded, t.guideDoneTitle, [t.guideDoneBody]),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(t.guideTitle),
        // Closing counts as seen: the card does not come back, «المزيد» still opens the guide.
        leading: IconButton(key: const Key('guide.close'), icon: const Icon(Icons.close_rounded), onPressed: _finish),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.guideStep(_index + 1, steps.length),
                key: const Key('guide.progress'),
                style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (_index + 1) / steps.length,
                  minHeight: 6,
                  backgroundColor: HisbahColors.progressTrack,
                ),
              ),
              Expanded(
                child: ListView(
                  key: Key('guide.step.${step.name}'),
                  padding: const EdgeInsets.only(top: 28),
                  children: [
                    Icon(icon, size: 56, color: HisbahColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    if (lines.length == 1)
                      Text(lines.single, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.7))
                    else
                      for (var i = 0; i < lines.length; i++) _NumberedLine(number: i + 1, text: lines[i]),
                    if (step == _Step.addProduct && _productAdded) ...[
                      const SizedBox(height: 12),
                      Row(
                        key: const Key('guide.added'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: StatusTone.success.fg),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              t.guideAddDone,
                              style: TextStyle(fontWeight: FontWeight.w700, color: StatusTone.success.fg),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              ..._actions(t, step),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(AppLocalizations t, _Step step) => switch (step) {
    _Step.welcome => [FilledButton(key: const Key('guide.next'), onPressed: _next, child: Text(t.guideStart))],
    _Step.addProduct => [
      if (_productAdded)
        FilledButton(key: const Key('guide.next'), onPressed: _next, child: Text(t.guideNext))
      else ...[
        FilledButton.icon(
          key: const Key('guide.addProduct'),
          onPressed: _addProduct,
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: Text(t.guideAddAction),
        ),
        TextButton(key: const Key('guide.skip'), onPressed: _next, child: Text(t.guideSkip)),
      ],
    ],
    _Step.sale => [
      FilledButton.icon(
        key: const Key('guide.sell'),
        onPressed: _sell,
        icon: const Icon(Icons.point_of_sale_rounded),
        label: Text(t.guideSaleAction),
      ),
      TextButton(key: const Key('guide.skip'), onPressed: _next, child: Text(t.guideSkip)),
    ],
    _Step.done => [FilledButton(key: const Key('guide.finish'), onPressed: _finish, child: Text(t.guideFinish))],
  };
}

class _NumberedLine extends StatelessWidget {
  const _NumberedLine({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: HisbahColors.primary,
          child: Text('$number', style: const TextStyle(color: HisbahColors.onPrimary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.7))),
      ],
    ),
  );
}
