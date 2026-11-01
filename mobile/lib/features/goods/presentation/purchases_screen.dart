import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../more/presentation/more_widgets.dart' show pushScreen;
import '../../print/application/print_documents.dart';
import '../../print/presentation/print_sheet.dart';
import '../../returns/presentation/period_list.dart';
import '../../returns/presentation/return_form_screen.dart';
import '../../returns/presentation/returns_screen.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/goods.dart';
import 'goods_flow.dart';
import 'supplier_screens.dart' show fullTime;

final purchaseProvider = FutureProvider.autoDispose.family<PurchaseDetail, int>(
  (ref, id) => ref.watch(goodsRepositoryProvider).purchase(id),
);

/// Every purchase invoice, newest first; of one supplier when opened from their page.
class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key, this.period = ListPeriod.month, this.supplierId, this.supplierName});

  final ListPeriod period;
  final int? supplierId;
  final String? supplierName;

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  /// A new invoice or a return changes the list: a new key reloads it.
  int _revision = 0;

  Future<void> _add() async {
    if (await openGoodsFlow(context) && mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplierName ?? t.purchasesTitle),
        actions: [TextButton(key: const Key('purchases.add'), onPressed: _add, child: Text(t.purchasesAdd))],
      ),
      body: PeriodList<PurchaseRow>(
        key: ValueKey('purchases.$_revision'),
        initial: widget.period,
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: t.purchasesEmpty,
        load: (from, to, page) => ref.read(goodsRepositoryProvider).purchases(from: from, to: to, page: page, supplierId: widget.supplierId),
        row: (row, reload) => _PurchaseRow(
          row: row,
          onTap: () async {
            await pushScreen<void>(context, PurchaseDetailScreen(purchaseId: row.id));
            await reload();
          },
        ),
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.row, required this.onTap});

  final PurchaseRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return InkWell(
      key: Key('purchases.row.${row.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.custDebtSale(row.id)} · ${row.supplierName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      Num(fullTime(row.at), size: 12, weight: FontWeight.w400, color: HisbahColors.inkMuted),
                      Text(t.salesItems(row.linesCount), style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Num(shekel(row.total), size: 15, weight: FontWeight.w700),
                if (row.returned.isPositive)
                  Text(t.purchaseReturned(shekel(row.returned)), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: StatusTone.warning.fg)),
              ],
            ),
            const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// A purchase invoice in full: its lines, what went back, print, and a return to the supplier.
class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.purchaseId});

  final int purchaseId;

  Future<void> _return(BuildContext context, WidgetRef ref, PurchaseDetail purchase, AppLocalizations t) async {
    final session = ref.read(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final owed = await ref.read(goodsRepositoryProvider).supplier(purchase.row.supplierId).then((s) => s.supplier.balance);
    if (!context.mounted) return;
    final saved = await pushScreen<bool>(
      context,
      ReturnFormScreen(
        title: t.retTitlePurchase('${purchase.row.id}'),
        lines: [
          for (final line in purchase.lines)
            if (line.returnable.isPositive)
              ReturnableLine(id: line.id, name: line.name, unit: line.unit, max: line.returnable, value: line.valueOf),
        ],
        owed: owed.isNegative ? Money.zero : owed,
        owedLabel: t.docToBalance,
        refundLabel: t.docRefundFromSupplier,
        flagLabel: t.retOffShelf,
        submit: (lines, reason) async {
          final record = await ref.read(goodsRepositoryProvider).returnPurchase(purchaseId, lines: lines, reason: reason);
          return purchaseReturnDocument(t, record, user);
        },
      ),
    );
    if (saved ?? false) ref.invalidate(purchaseProvider(purchaseId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final purchase = ref.watch(purchaseProvider(purchaseId));
    final data = purchase.value;

    return Scaffold(
      appBar: AppBar(title: Text(t.docPurchase)),
      bottomNavigationBar: data == null
          ? null
          : ActionBar(
              bottomInset: MediaQuery.paddingOf(context).bottom,
              child: Row(
                children: [
                  Expanded(child: PrintButton(key: const Key('purchase.print'), document: () => purchaseDocument(t, data, user))),
                  if (data.lines.any((line) => line.returnable.isPositive)) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('purchase.return'),
                        onPressed: () => _return(context, ref, data, t),
                        child: Text(t.retToSupplier),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      body: purchase.when(
        loading: () => const LoadingView.detail(),
        error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(purchaseProvider(purchaseId))),
        data: (p) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LineCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(t.supplierInvoiceNumber('${p.row.id}'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(p.row.supplierName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Num(fullTime(p.row.at), size: 13, weight: FontWeight.w400, color: HisbahColors.inkMuted),
                    const Divider(height: 22),
                    for (final line in p.lines) _LineRow(line: line),
                    const Divider(height: 22),
                    Row(
                      children: [
                        Expanded(child: Text(t.totalWord, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        Num(shekel(p.row.total), size: 20, weight: FontWeight.w700),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (p.returns.isNotEmpty) ...[
              const SizedBox(height: 16),
              GroupLabel(t.returnsTitle),
              const SizedBox(height: 8),
              LineCard(
                child: Column(
                  children: [
                    for (var i = 0; i < p.returns.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                      ReturnRow(
                        key: Key('purchase.returned.${p.returns[i].id}'),
                        title: p.returns[i].reason,
                        at: p.returns[i].at,
                        amount: p.returns[i].total,
                        onTap: () => showPurchaseReturn(context, ref, p.returns[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final PurchaseLine line;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cartons = line.cartons;
    final amount = line.unit == ProductUnit.kg ? '${line.quantity.format(line.unit)} ${t.kgShort}' : t.purchasePieces(line.quantity.format(line.unit));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text(
                  cartons == null ? '$amount × ${shekel(line.buyPrice)}' : '$cartons ${t.packWord} × ${shekel(line.buyPrice)} · $amount',
                  style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                ),
                if (line.returned.isPositive)
                  Text(t.purchaseLineReturned(line.returned.format(line.unit)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StatusTone.warning.fg)),
              ],
            ),
          ),
          Num(shekel(line.total), size: 15, weight: FontWeight.w700),
        ],
      ),
    );
  }
}
