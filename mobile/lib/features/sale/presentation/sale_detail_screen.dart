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
import '../../returns/presentation/return_form_screen.dart';
import '../../returns/presentation/returns_screen.dart';
import '../data/sale_repository.dart';
import 'receipt_screen.dart';
import 'sale_widgets.dart';

/// GET /sales/{id}, fresh each time the invoice opens (a return or a void may have happened since).
final saleDetailProvider = FutureProvider.autoDispose.family<SaleReceipt, int>(
  (ref, id) => ref.watch(saleRepositoryProvider).sale(id),
);

/// A past invoice in full, as printed on the receipt: every line with its quantity, unit price and
/// total, then the total, what was paid, what stayed as debt, a void and any returns. It prints,
/// and owners and managers can take goods back or void it from here.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  Future<void> _return(BuildContext context, WidgetRef ref, SaleReceipt sale, AppLocalizations t) async {
    final session = ref.read(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final saved = await pushScreen<bool>(
      context,
      ReturnFormScreen(
        title: t.retTitleSale('${sale.id}'),
        lines: [
          for (final line in sale.lines)
            if (line.productId != null && line.returnable.isPositive)
              ReturnableLine(
                id: line.id,
                name: line.name,
                unit: line.unit,
                max: line.returnable,
                value: (quantity) => lineTotal(line.unitPrice, quantity),
              ),
        ],
        owed: sale.openDebt,
        owedLabel: t.docToDebt,
        refundLabel: t.docRefunded,
        flagLabel: t.retDamaged,
        submit: (lines, reason) async {
          final record = await ref.read(saleRepositoryProvider).returnSale(sale.id, lines: lines, reason: reason);
          return saleReturnDocument(t, record, user);
        },
      ),
    );
    if (saved ?? false) ref.invalidate(saleDetailProvider(saleId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final sale = ref.watch(saleDetailProvider(saleId));

    final data = sale.value;
    final manages = data != null && !data.isVoided && (user?.canOverride ?? false);
    // D-06: a sale with returns can no longer be voided; a correction is another return.
    final voidable = manages && data.returns.isEmpty;
    final returnable = manages && data.lines.any((line) => line.productId != null && line.returnable.isPositive);

    return Scaffold(
      appBar: AppBar(title: Text(t.custDebtSale(saleId))),
      // Owners and managers can void a sale from here, with the same sheet as the receipt.
      bottomNavigationBar: data == null
          ? null
          : ActionBar(
              bottomInset: MediaQuery.paddingOf(context).bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: PrintButton(key: const Key('saleDetail.print'), document: () => saleDocument(t, data, user))),
                      if (returnable) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            key: const Key('saleDetail.return'),
                            onPressed: () => _return(context, ref, data, t),
                            child: Text(t.retAction),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (voidable)
                    TextButton(
                      key: const Key('saleDetail.void'),
                      onPressed: () async {
                        final voided = await showSaleSheet<SaleReceipt>(context, builder: (_) => VoidSheet(receipt: data));
                        if (voided != null) ref.invalidate(saleDetailProvider(saleId));
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: HisbahColors.dangerSolid,
                        minimumSize: const Size.fromHeight(44),
                        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: Text(t.voidInvoiceEllipsis),
                    ),
                ],
              ),
            ),
      body: sale.when(
        loading: () => const LoadingView.detail(),
        error: (_, _) =>
            ErrorView(message: t.saleDetailError, onRetry: () => ref.invalidate(saleDetailProvider(saleId))),
        data: (r) {
          final returned = r.returned;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(saleDetailProvider(saleId).future),
            child: ListView(
              key: const Key('saleDetail.list'),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                ReceiptPaper(
                  key: const Key('saleDetail.paper'),
                  receipt: r,
                  user: user,
                  strike: r.isVoided ? TextDecoration.lineThrough : TextDecoration.none,
                ),
                if (r.isVoided) ...[
                  const SizedBox(height: 12),
                  ToneCard(
                    tone: StatusTone.voided,
                    icon: Icons.block_rounded,
                    title: t.receiptVoidedBy(r.voidedByName ?? '', r.voidedAt == null ? '' : _time(r.voidedAt!)),
                    children: [
                      if ((r.voidReason ?? '').isNotEmpty) BodyText(t.receiptVoidReason(r.voidReason!)),
                      BodyText(t.receiptVoidEffect),
                    ],
                  ),
                ],
                if (returned != null && returned.isPositive) ...[
                  const SizedBox(height: 12),
                  ToneCard(
                    key: const Key('saleDetail.returned'),
                    tone: StatusTone.info,
                    icon: Icons.undo_rounded,
                    title: t.saleReturnedNote(shekel(returned)),
                  ),
                ],
                if (r.returns.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LineCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < r.returns.length; i++) ...[
                          if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                          ReturnRow(
                            key: Key('saleDetail.returned.${r.returns[i].id}'),
                            title: r.returns[i].reason,
                            at: r.returns[i].at,
                            amount: r.returns[i].total,
                            onTap: () => showSaleReturn(context, ref, r.returns[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
