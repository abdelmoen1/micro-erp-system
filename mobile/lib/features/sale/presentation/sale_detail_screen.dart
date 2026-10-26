import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../data/sale_repository.dart';
import 'receipt_screen.dart';
import 'sale_widgets.dart';

/// GET /sales/{id}, fresh each time the invoice opens (a return or a void may have happened since).
final saleDetailProvider = FutureProvider.autoDispose.family<SaleReceipt, int>(
  (ref, id) => ref.watch(saleRepositoryProvider).sale(id),
);

/// A past invoice in full, as printed on the receipt: every line with its quantity, unit price and
/// total, then the total, what was paid, what stayed as debt, a void and any returns. Read only.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final sale = ref.watch(saleDetailProvider(saleId));

    final voidable = sale.value != null && !sale.value!.isVoided && (user?.canOverride ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(t.custDebtSale(saleId))),
      // Owners and managers can void a sale from here, with the same sheet as the receipt.
      bottomNavigationBar: voidable
          ? ActionBar(
              bottomInset: MediaQuery.paddingOf(context).bottom,
              child: TextButton(
                key: const Key('saleDetail.void'),
                onPressed: () async {
                  final voided = await showSaleSheet<SaleReceipt>(context, builder: (_) => VoidSheet(receipt: sale.value!));
                  if (voided != null) ref.invalidate(saleDetailProvider(saleId));
                },
                style: TextButton.styleFrom(
                  foregroundColor: HisbahColors.dangerSolid,
                  minimumSize: const Size.fromHeight(44),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: Text(t.voidInvoiceEllipsis),
              ),
            )
          : null,
      body: sale.when(
        loading: () => const LoadingView(),
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
              ],
            ),
          );
        },
      ),
    );
  }

  static String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
