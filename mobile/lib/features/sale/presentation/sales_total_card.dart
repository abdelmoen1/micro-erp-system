import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/dashboard.dart';
import 'sale_widgets.dart';
import 'sales_history_screen.dart' show SalesPeriod, SalesType;

/// The dashboard period each list period matches (the same Monday-on week and calendar month).
String? _apiPeriod(SalesPeriod period) => switch (period) {
  SalesPeriod.today => 'today',
  SalesPeriod.week => 'this_week',
  SalesPeriod.month => 'this_month',
  SalesPeriod.all => null,
};

/// «مجموع المبيعات» over the invoice list, like the stock-value card over the products: the chosen
/// period's total, large, and today / this week / this month side by side (a tap picks the
/// period). Follows the list's cash / credit filter and the green card's eye.
class SalesTotalCard extends ConsumerWidget {
  const SalesTotalCard({super.key, required this.period, required this.type, required this.onPeriod});

  final SalesPeriod period;
  final SalesType type;
  final ValueChanged<SalesPeriod> onPeriod;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final hidden = ref.watch(hideAmountsProvider);
    final selected = _apiPeriod(period);
    final summary = selected == null ? null : ref.watch(salesSummaryProvider(selected));

    String amountOf(SalesSummary s) => switch (type) {
      SalesType.all => s.total,
      SalesType.cash => s.cash,
      SalesType.onCredit => s.credit,
    };
    String money(String amount) => hidden ? '₪ $hiddenAmount' : shekel(Money.parse(amount));

    final title = switch (type) {
      SalesType.all => t.salesTotalTitle,
      SalesType.cash => t.salesTotalCash,
      SalesType.onCredit => t.salesTotalCredit,
    };
    final value = summary?.value;

    return Container(
      key: const Key('sales.total'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
      decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HisbahColors.onPrimaryMuted),
                ),
              ),
              IconButton(
                key: const Key('sales.total.eye'),
                tooltip: hidden ? t.homeShowAmounts : t.homeHideAmounts,
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(hideAmountsProvider.notifier).toggle(),
                icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: HisbahColors.onPrimary),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: selected == null
                ? Text(t.salesTotalAllTime, style: const TextStyle(fontSize: 15, color: HisbahColors.onPrimary))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: value == null
                                ? const SizedBox(
                                    height: 36,
                                    child: Center(
                                      child: SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: HisbahColors.onPrimary),
                                      ),
                                    ),
                                  )
                                : Num(
                                    money(amountOf(value)),
                                    key: const Key('sales.total.amount'),
                                    size: 30,
                                    weight: FontWeight.w700,
                                    color: HisbahColors.onPrimary,
                                  ),
                          ),
                        ),
                      ),
                      if (value != null && type == SalesType.all)
                        Text(
                          t.homeInvoicesCount(value.count),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HisbahColors.onPrimaryMuted),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: HisbahColors.onPrimaryLine),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (p, label) in [
                (SalesPeriod.today, t.salesToday),
                (SalesPeriod.week, t.salesThisWeek),
                (SalesPeriod.month, t.salesThisMonth),
              ]) ...[
                if (p != SalesPeriod.today) const SizedBox(width: 6),
                Expanded(
                  child: _PeriodFigure(
                    key: Key('sales.total.${p.name}'),
                    label: label,
                    amount: ref.watch(salesSummaryProvider(_apiPeriod(p)!)).value,
                    text: (s) => money(amountOf(s)),
                    selected: p == period,
                    onTap: () => onPeriod(p),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodFigure extends StatelessWidget {
  const _PeriodFigure({
    super.key,
    required this.label,
    required this.amount,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final SalesSummary? amount;
  final String Function(SalesSummary) text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? const Color(0x33FFFFFF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? HisbahColors.onPrimary : HisbahColors.onPrimaryMuted,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Num(
                  amount == null ? '—' : text(amount!),
                  size: 14,
                  weight: FontWeight.w700,
                  color: HisbahColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
