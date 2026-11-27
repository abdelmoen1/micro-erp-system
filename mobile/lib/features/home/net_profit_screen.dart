import 'package:flutter/material.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/ltr_value.dart';
import '../../l10n/app_localizations.dart';
import '../more/presentation/more_widgets.dart' show pushScreen;
import '../more/presentation/obligations_screen.dart';
import '../sale/presentation/sale_widgets.dart';
import 'dashboard.dart';
import 'drilldown_screens.dart';

/// «صافي ربح اليوم», opened from its Home tile: how the figure is made, line by line, and the two
/// places that change it (the obligations, and the products without a cost price).
class NetProfitScreen extends StatelessWidget {
  const NetProfitScreen({super.key, required this.today});

  final TodayDashboard today;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = today.profit!;
    final tone = p.isLoss ? StatusTone.error : StatusTone.paid;

    return Scaffold(
      appBar: AppBar(title: Text(t.profitTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          EntranceFade(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: tone.bg,
                borderRadius: BorderRadius.circular(HisbahRadius.card),
                border: Border.all(color: tone.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.profitNet,
                    style: TextStyle(color: tone.fg, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: CountUp(
                      amount: p.net,
                      format: formatShekel,
                      builder: (_, text) => LtrValue(
                        text,
                        key: const Key('profit.net'),
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: tone.fg),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(t.profitIntro, style: const TextStyle(fontSize: 13, height: 1.5, color: HisbahColors.ink)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          EntranceFade(
            delay: const Duration(milliseconds: 60),
            child: LineCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _Line(label: t.profitSales, hint: t.profitSalesHint, amount: p.salesProfit, sign: '+'),
                    _Line(label: t.profitDiscounts, amount: p.discounts, sign: '−'),
                    _Line(label: t.profitReturns, amount: p.returnsProfit, sign: '−'),
                    _Line(
                      label: t.profitObligations,
                      hint: p.obligations == '0.00' ? t.profitNoObligations : null,
                      amount: p.obligations,
                      sign: '−',
                    ),
                    const Divider(color: HisbahColors.border),
                    _Line(label: t.profitNet, amount: p.net, strong: true, color: tone.fg),
                  ],
                ),
              ),
            ),
          ),
          if (p.uncostedLines > 0) ...[
            const SizedBox(height: 12),
            ToneCard(
              key: const Key('profit.uncosted'),
              tone: StatusTone.warning,
              icon: Icons.price_change_outlined,
              title: t.profitUncosted(p.uncostedLines),
              children: [BodyText(t.profitUncostedHint, size: 13)],
            ),
          ],
          const SizedBox(height: 14),
          LineCard(
            // Its own Material, so the rows' press ripple shows on the card.
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  ListTile(
                    key: const Key('profit.obligations'),
                    leading: const Icon(Icons.event_repeat_rounded, color: HisbahColors.primary),
                    title: Text(t.profitManageObligations, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(t.obMoreSub),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => pushScreen<void>(context, const ObligationsScreen()),
                  ),
                  const Divider(height: 1, color: HisbahColors.border),
                  // The figure the tile replaced stays one tap away.
                  ListTile(
                    key: const Key('profit.collections'),
                    leading: const Icon(Icons.savings_outlined, color: HisbahColors.primary),
                    title: Text(t.homeCollectedToday, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: LtrValue(formatShekel(today.collectedTotal)),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => pushScreen<void>(context, CollectionsScreen(today: today)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.amount, this.hint, this.sign, this.strong = false, this.color});

  final String label;
  final String? hint;
  final String amount;

  /// '+' or '−' before the figure, so each line reads as part of the sum.
  final String? sign;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: strong ? 16 : 15, fontWeight: strong ? FontWeight.w800 : FontWeight.w600),
              ),
              if (hint != null) Text(hint!, style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        LtrValue(
          '${sign == null || amount == '0.00' ? '' : '$sign '}${formatShekel(amount)}',
          style: TextStyle(
            fontSize: strong ? 17 : 15,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}
