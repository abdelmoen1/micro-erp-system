import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../customers/presentation/record_payment_screen.dart' show paymentMethods;
import '../../more/presentation/more_widgets.dart' show pushScreen;
import '../../sale/presentation/checkout_screen.dart' show paymentMethodLabel;
import '../../sale/presentation/sale_widgets.dart';
import '../domain/goods.dart';
import 'goods_flow.dart' show MethodChoices;
import 'goods_item_screen.dart' show GoodsField;

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) => ref.watch(goodsRepositoryProvider).suppliers());

final supplierAccountProvider = FutureProvider.autoDispose.family<SupplierAccount, int>(
  (ref, id) => ref.watch(goodsRepositoryProvider).account(id),
);

/// Every supplier with what the store still owes them.
class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final suppliers = ref.watch(suppliersProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.suppliersTitle)),
      body: SafeArea(
        child: suppliers.when(
          loading: () => const LoadingView(),
          error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(suppliersProvider)),
          data: (rows) => rows.isEmpty
              ? Center(
                  child: Text(t.suppliersEmpty, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final supplier = rows[i];
                    return LineCard(
                      child: InkWell(
                        key: Key('suppliers.row.${supplier.id}'),
                        onTap: () async {
                          await pushScreen<void>(context, SupplierAccountScreen(supplierId: supplier.id));
                          ref.invalidate(suppliersProvider);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(supplier.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              ),
                              Num(
                                shekel(supplier.balance),
                                size: 17,
                                weight: FontWeight.w700,
                                color: supplier.balance.isPositive ? StatusTone.debt.fg : StatusTone.success.fg,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// What is owed, then the invoices and payments that make it up, newest first.
class SupplierAccountScreen extends ConsumerWidget {
  const SupplierAccountScreen({super.key, required this.supplierId});

  final int supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final account = ref.watch(supplierAccountProvider(supplierId));
    return Scaffold(
      appBar: AppBar(title: Text(account.value?.supplier.name ?? t.supplierAccount)),
      body: SafeArea(
        child: account.when(
          loading: () => const LoadingView.detail(),
          error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(supplierAccountProvider(supplierId))),
          data: (data) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      key: const Key('supplier.balance'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(HisbahRadius.card)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.supplierOwed, style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 16)),
                          const SizedBox(height: 4),
                          Num(shekel(data.supplier.balance), size: 34, weight: FontWeight.w700, color: HisbahColors.onPrimary),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(t.supplierMoves, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    LineCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < data.entries.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            _EntryRow(entry: data.entries[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (data.supplier.balance.isPositive)
                ActionBar(
                  child: FilledButton(
                    key: const Key('supplier.pay'),
                    onPressed: () async {
                      final paid = await showSaleSheet<bool>(context, builder: (_) => SupplierPaySheet(supplier: data.supplier));
                      if (paid ?? false) ref.invalidate(supplierAccountProvider(supplierId));
                    },
                    child: Text(t.supplierPay),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final SupplierEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final title = entry.isInvoice
        ? t.supplierInvoice
        : t.supplierPayment(entry.method == null ? '' : paymentMethodLabel(t, entry.method!));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(dayMonthYear(entry.at), style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
              ],
            ),
          ),
          Num(
            '${entry.isInvoice ? '+' : '-'}${shekel(entry.amount)}',
            size: 16,
            weight: FontWeight.w700,
            color: entry.isInvoice ? StatusTone.debt.fg : StatusTone.success.fg,
          ),
        ],
      ),
    );
  }
}

/// A later payment on the account. Pops true when it was recorded.
class SupplierPaySheet extends ConsumerStatefulWidget {
  const SupplierPaySheet({super.key, required this.supplier});

  final Supplier supplier;

  @override
  ConsumerState<SupplierPaySheet> createState() => _SupplierPaySheetState();
}

class _SupplierPaySheetState extends ConsumerState<SupplierPaySheet> {
  final _amount = TextEditingController();
  final String _operationId = 'supplier-pay-${DateTime.now().microsecondsSinceEpoch}';
  String _method = paymentMethods.first;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Money? get _value {
    try {
      final value = Money.parse(_amount.text.trim());
      return value.isPositive ? value : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(AppLocalizations t) async {
    final amount = _value;
    if (amount == null) return setState(() => _error = t.formPriceInvalid);
    if (amount > widget.supplier.balance) return setState(() => _error = t.supplierPayTooMuch);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(goodsRepositoryProvider).pay(supplierId: widget.supplier.id, amount: amount, method: _method, operationId: _operationId);
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationFailed catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.fieldErrors.values.expand((e) => e).firstOrNull ?? t.formFailed;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure is NetworkFailure ? t.formNetwork : failure.message ?? t.formFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final left = widget.supplier.balance - (_value ?? Money.zero);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: t.supplierPayTitle, closeLabel: t.cancel),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: StatusTone.debt.bg, borderRadius: BorderRadius.circular(HisbahRadius.field)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.supplierOwes, style: TextStyle(color: StatusTone.debt.fg, fontWeight: FontWeight.w600)),
                  Num(shekel(widget.supplier.balance), size: 16, weight: FontWeight.w700, color: StatusTone.debt.fg),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GoodsField(
              fieldKey: const Key('supplier.amount'),
              label: t.supplierAmount,
              controller: _amount,
              number: true,
              decimal: true,
              error: _error,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            MethodChoices(selected: _method, onPick: (m) => setState(() => _method = m)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.supplierStillOwed, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted)),
                Num(shekel(left.isNegative ? Money.zero : left), size: 16, weight: FontWeight.w700),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('supplier.savePayment'),
              onPressed: _busy ? null : () => _save(t),
              child: BusyLabel(busy: _busy, label: _busy ? t.formSaving : t.supplierPaySave),
            ),
          ],
        ),
      ),
    );
  }
}
