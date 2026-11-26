import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../goods/presentation/supplier_screens.dart' show fullTime;
import '../../print/application/print_documents.dart';
import '../../print/domain/print_document.dart';
import '../../print/presentation/print_sheet.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/returns.dart';
import 'cancel_return_sheet.dart';
import 'period_list.dart';

AppUser? _user(WidgetRef ref) {
  final session = ref.read(sessionProvider);
  return session is SignedIn ? session.user : null;
}

/// Both return registers: what came back from customers and, for owners and managers, what went
/// back to suppliers. A row opens the return with its lines, its reason and a print button.
class ReturnsScreen extends ConsumerStatefulWidget {
  const ReturnsScreen({super.key, this.period = ListPeriod.month});

  final ListPeriod period;

  @override
  ConsumerState<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends ConsumerState<ReturnsScreen> {
  bool _purchases = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final canSeeCosts = _user(ref)?.canOverride ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(t.returnsTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canSeeCosts)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OptionRow(
                children: [
                  OptionButton(
                    key: const Key('returns.sales'),
                    label: t.returnsSales,
                    selected: !_purchases,
                    onTap: () => setState(() => _purchases = false),
                  ),
                  OptionButton(
                    key: const Key('returns.purchases'),
                    label: t.returnsPurchases,
                    selected: _purchases,
                    onTap: () => setState(() => _purchases = true),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _purchases
                ? PeriodList<PurchaseReturnRecord>(
                    key: const ValueKey('returns.list.purchases'),
                    initial: widget.period,
                    emptyIcon: Icons.assignment_return_outlined,
                    emptyTitle: t.returnsEmpty,
                    load: (from, to, page) => ref.read(goodsRepositoryProvider).purchaseReturns(from: from, to: to, page: page),
                    row: (row, reload) => ReturnRow(
                      key: Key('returns.purchase.${row.id}'),
                      title: row.supplierName ?? '',
                      at: row.at,
                      amount: row.total,
                      voided: row.voided,
                      onTap: () => showPurchaseReturn(context, ref, row, onCancelled: reload),
                    ),
                  )
                : PeriodList<SaleReturnRecord>(
                    key: const ValueKey('returns.list.sales'),
                    initial: widget.period,
                    emptyIcon: Icons.assignment_return_outlined,
                    emptyTitle: t.returnsEmpty,
                    load: (from, to, page) => ref.read(saleRepositoryProvider).saleReturns(from: from, to: to, page: page),
                    row: (row, reload) => ReturnRow(
                      key: Key('returns.sale.${row.id}'),
                      title: row.customerName ?? t.salesWalkIn,
                      at: row.at,
                      amount: row.total,
                      voided: row.voided,
                      onTap: () => showSaleReturn(context, ref, row, onCancelled: reload),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ReturnRow extends StatelessWidget {
  const ReturnRow({super.key, required this.title, required this.at, required this.amount, required this.onTap, this.voided = false});

  final String title;
  final DateTime at;
  final Money amount;
  final VoidCallback onTap;

  /// A cancelled return stays listed, greyed and struck through, with no effect left.
  final bool voided;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                Num(fullTime(at), size: 12, weight: FontWeight.w400, color: HisbahColors.inkMuted),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (voided) ...[
            Text(AppLocalizations.of(context).returnVoidedBadge, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HisbahColors.inkMuted)),
            const SizedBox(width: 6),
          ],
          Num(shekel(amount), size: 15, weight: FontWeight.w700, color: voided ? HisbahColors.inkMuted : HisbahColors.ink),
          const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted),
        ],
      ),
    ),
  );
}

/// The return as it prints. Owners and managers can cancel a return made by mistake from here;
/// [onCancelled] refreshes the list or document it was opened from.
void showSaleReturn(BuildContext context, WidgetRef ref, SaleReturnRecord row, {VoidCallback? onCancelled}) {
  final t = AppLocalizations.of(context);
  final document = saleReturnDocument(t, row, _user(ref));
  final canCancel = (_user(ref)?.canOverride ?? false) && !row.voided;
  showSaleSheet<void>(
    context,
    builder: (sheet) => _ReturnSheet(
      document: document,
      voidReason: row.voided ? row.voidReason ?? '' : null,
      onCancel: !canCancel
          ? null
          : () => _cancel(
              sheet,
              CancelReturnSheet(
                invoiceId: row.invoiceId,
                effects: [
                  if (row.lines.any((l) => !l.flagged)) t.cancelSaleReturnStock,
                  if (row.toDebt.isPositive) t.cancelSaleReturnDebt(shekel(row.toDebt), row.customerName ?? t.salesWalkIn),
                  if (row.refund.isPositive) t.cancelSaleReturnRefund(shekel(row.refund)),
                ],
                cancel: (reason) => ref.read(saleRepositoryProvider).voidSaleReturn(row.id, reason: reason),
              ),
              onCancelled,
            ),
    ),
  );
}

void showPurchaseReturn(BuildContext context, WidgetRef ref, PurchaseReturnRecord row, {VoidCallback? onCancelled}) {
  final t = AppLocalizations.of(context);
  final document = purchaseReturnDocument(t, row, _user(ref));
  final canCancel = (_user(ref)?.canOverride ?? false) && !row.voided;
  showSaleSheet<void>(
    context,
    builder: (sheet) => _ReturnSheet(
      document: document,
      voidReason: row.voided ? row.voidReason ?? '' : null,
      onCancel: !canCancel
          ? null
          : () => _cancel(
              sheet,
              CancelReturnSheet(
                invoiceId: row.invoiceId,
                effects: [
                  if (row.lines.any((l) => !l.flagged)) t.cancelPurchaseReturnStock,
                  if (row.toBalance.isPositive) t.cancelPurchaseReturnBalance(shekel(row.toBalance), row.supplierName ?? ''),
                  if (row.refund.isPositive) t.cancelPurchaseReturnRefund(shekel(row.refund)),
                ],
                cancel: (reason) => ref.read(goodsRepositoryProvider).voidPurchaseReturn(row.id, reason: reason),
              ),
              onCancelled,
            ),
    ),
  );
}

/// Opens the cancel sheet over the return; once the server confirmed, both close and the caller refreshes.
Future<void> _cancel(BuildContext sheet, CancelReturnSheet cancelSheet, VoidCallback? onCancelled) async {
  final messenger = ScaffoldMessenger.maybeOf(sheet);
  final done = AppLocalizations.of(sheet).cancelDone;
  final cancelled = await showSaleSheet<bool>(sheet, builder: (_) => cancelSheet);
  if (cancelled != true || !sheet.mounted) return;
  Navigator.of(sheet).pop();
  onCancelled?.call();
  messenger?.showSnackBar(SnackBar(content: Text(done)));
}

/// The return as it prints, read on the phone.
class _ReturnSheet extends StatelessWidget {
  const _ReturnSheet({required this.document, this.onCancel, this.voidReason});

  final PrintDocument document;

  /// Owners and managers, on a return that still stands.
  final VoidCallback? onCancel;

  /// Set when the return was cancelled (the reason may be empty).
  final String? voidReason;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final d = document;
    Widget pair(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 16 : 14, fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
          Flexible(child: Num(value, size: strong ? 17 : 14, weight: strong ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: '${d.title} ${d.number}', closeLabel: t.backWord),
          const SizedBox(height: 10),
          if (voidReason != null) ...[
            ToneCard(key: const Key('return.voided'), tone: StatusTone.voided, icon: Icons.block_rounded, title: t.returnVoidedNote(voidReason!)),
            const SizedBox(height: 10),
          ],
          for (final (label, value) in d.facts) pair(label, value),
          const Divider(height: 20),
          for (final row in d.rows) ...[
            Text(row.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            pair(row.detail ?? '', row.amount),
            const SizedBox(height: 4),
          ],
          const Divider(height: 20),
          for (final total in d.totals) pair(total.label, total.value, strong: total.strong),
          if (d.note != null) ...[
            const SizedBox(height: 8),
            Text(d.note!, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
          ],
          const SizedBox(height: 14),
          PrintButton(key: const Key('return.print'), document: () => d),
          if (onCancel != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('return.cancel'),
              onPressed: onCancel,
              icon: const Icon(Icons.undo_rounded),
              label: Text(t.cancelReturnAction),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: HisbahColors.dangerSolid,
                side: const BorderSide(color: HisbahColors.dangerSolid),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
