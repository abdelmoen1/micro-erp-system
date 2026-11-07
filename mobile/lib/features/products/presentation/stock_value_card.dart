import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../application/stock_value.dart';

/// «قيمة البضاعة في المخزن» (2026-11-07), Owner / Manager: the goods on the shelf at cost, large,
/// and what they bring at selling prices. Hidden until the first figure arrives and when the
/// server cannot be reached; the last figure stays while a refresh runs.
class StockValueCard extends ConsumerWidget {
  const StockValueCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final value = ref.watch(stockValueProvider).value;
    if (value == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: t.stockValueTitle,
      child: Container(
        key: const Key('products.stockValue'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.stockValueTitle,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: HisbahColors.onPrimaryMuted),
                  ),
                ),
                Text(t.stockValueAtCost, style: const TextStyle(fontSize: 12, color: HisbahColors.onPrimaryMuted)),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Num(
                shekel(value.costValue),
                key: const Key('products.stockValue.cost'),
                size: 30,
                weight: FontWeight.w700,
                color: HisbahColors.onPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: HisbahColors.onPrimaryLine),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.stockValueAtSelling,
                    style: const TextStyle(fontSize: 13, color: HisbahColors.onPrimaryMuted),
                  ),
                ),
                Num(
                  shekel(value.sellingValue),
                  key: const Key('products.stockValue.selling'),
                  size: 14,
                  weight: FontWeight.w700,
                  color: HisbahColors.onPrimary,
                ),
              ],
            ),
            if (value.missingCostCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: HisbahColors.onPrimaryMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t.stockValueMissingCost('${value.missingCostCount}'),
                      key: const Key('products.stockValue.missing'),
                      style: const TextStyle(fontSize: 12, color: HisbahColors.onPrimaryMuted),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
