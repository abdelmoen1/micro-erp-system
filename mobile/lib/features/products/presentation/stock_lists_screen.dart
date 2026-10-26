import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'product_detail_screen.dart';

final lowStockProvider = FutureProvider.autoDispose<List<Product>>((ref) => ref.watch(productRepositoryProvider).lowStock());
final negativeStockProvider = FutureProvider.autoDispose<List<NegativeStockItem>>(
  (ref) => ref.watch(productRepositoryProvider).negativeStock(),
);

final _when = DateFormat('dd/MM · HH:mm', 'en');

/// Products at or below their alert level, lowest first; a tap opens the product to count or
/// receive stock.
class LowStockScreen extends ConsumerWidget {
  const LowStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final products = ref.watch(lowStockProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.lowTitle)),
      body: products.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(lowStockProvider)),
        data: (rows) => rows.isEmpty
            ? EmptyView(icon: Icons.inventory_2_outlined, title: t.lowEmpty)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(lowStockProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    LineCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                            _ProductLine(
                              product: rows[i],
                              detail: t.lowRow(
                                isolateLtr(rows[i].currentStock.format(rows[i].unit)),
                                isolateLtr(rows[i].minimumStock.format(rows[i].unit)),
                              ),
                              onChanged: () => ref.invalidate(lowStockProvider),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Products sold beyond their recorded stock (D-27), with their latest sales: count the shelf,
/// then correct the stock from the product page.
class NegativeStockScreen extends ConsumerWidget {
  const NegativeStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final items = ref.watch(negativeStockProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.negTitle)),
      body: items.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(negativeStockProvider)),
        data: (rows) => rows.isEmpty
            ? EmptyView(icon: Icons.task_alt_rounded, title: t.negEmpty)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(negativeStockProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Text(t.negHelp, style: const TextStyle(fontSize: 13, height: 1.6, color: HisbahColors.inkMuted)),
                    const SizedBox(height: 12),
                    for (final item in rows) ...[
                      LineCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProductLine(
                              product: item.product,
                              detail: '${t.prodStockNowLabel} ${isolateLtr(item.product.currentStock.format(item.product.unit))}',
                              onChanged: () => ref.invalidate(negativeStockProvider),
                            ),
                            for (final sale in item.sales)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                                child: Text(
                                  [
                                    if (sale.invoiceId != null) t.negSale(sale.invoiceId!, isolateLtr(sale.quantity)),
                                    ?sale.by,
                                    if (sale.at != null) isolateLtr(_when.format(sale.at!)),
                                  ].join(' · '),
                                  style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProductLine extends StatelessWidget {
  const _ProductLine({required this.product, required this.detail, required this.onChanged});

  final Product product;
  final String detail;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('stockList.row.${product.id}'),
    onTap: () async {
      if (await openProduct(context, product.id)) onChanged();
    },
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(detail, style: TextStyle(fontSize: 13, color: StatusTone.warning.fg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted),
        ],
      ),
    ),
  );
}
