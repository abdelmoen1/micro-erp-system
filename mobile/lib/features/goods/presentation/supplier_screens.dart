import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import 'goods_item_screen.dart' show GoodsField;

final suppliersProvider = FutureProvider.autoDispose<List<Supplier>>((ref) => ref.watch(goodsRepositoryProvider).suppliers());

final supplierProvider = FutureProvider.autoDispose.family<SupplierDetail, int>(
  (ref, id) => ref.watch(goodsRepositoryProvider).supplier(id),
);

final productInvoicesProvider = FutureProvider.autoDispose.family<ProductInvoices, (int, int)>(
  (ref, ids) => ref.watch(goodsRepositoryProvider).productInvoices(ids.$1, ids.$2),
);

final _clock = DateFormat('dd/MM/yyyy  HH:mm', 'en');

String fullTime(DateTime at) => _clock.format(at);

Color _owedColor(Money balance) => balance.isPositive ? StatusTone.debt.fg : StatusTone.success.fg;

/// A row that opens something: a name on one side, an amount on the other.
class _Row extends StatelessWidget {
  const _Row({super.key, required this.title, required this.trailing, required this.onTap, this.sub});

  final String title;
  final String? sub;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (sub != null) Text(sub!, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    ),
  );
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => LineCard(
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 1), rows[i]],
      ],
    ),
  );
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('supplier.balance'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(HisbahRadius.card)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 16)),
        const SizedBox(height: 4),
        Num(shekel(amount), size: 34, weight: FontWeight.w700, color: HisbahColors.onPrimary),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
  );
}

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
              ? EmptyView(icon: Icons.local_shipping_outlined, title: t.suppliersEmpty)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Rows(
                      rows: [
                        for (final supplier in rows)
                          _Row(
                            key: Key('suppliers.row.${supplier.id}'),
                            title: supplier.name,
                            trailing: Num(shekel(supplier.balance), size: 16, weight: FontWeight.w700, color: _owedColor(supplier.balance)),
                            onTap: () async {
                              await pushScreen<void>(context, SupplierScreen(supplierId: supplier.id, name: supplier.name));
                              ref.invalidate(suppliersProvider);
                            },
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One supplier: what is owed in all, the products bought, the payments, and «سجّل دفعة».
class SupplierScreen extends ConsumerWidget {
  const SupplierScreen({super.key, required this.supplierId, required this.name});

  final int supplierId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final detail = ref.watch(supplierProvider(supplierId));
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: detail.when(
          loading: () => const LoadingView.detail(),
          error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(supplierProvider(supplierId))),
          data: (data) => Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _BalanceCard(label: t.supplierOwed, amount: data.supplier.balance),
                    _SectionTitle(t.supplierProducts),
                    _Rows(
                      rows: [
                        for (final product in data.products)
                          _Row(
                            key: Key('supplier.product.${product.id}'),
                            title: product.name,
                            trailing: Num(shekel(product.total), size: 16, weight: FontWeight.w700),
                            onTap: () => pushScreen<void>(
                              context,
                              SupplierProductScreen(supplierId: supplierId, productId: product.id, name: product.name),
                            ),
                          ),
                      ],
                    ),
                    _SectionTitle(t.supplierPayments),
                    if (data.payments.isEmpty)
                      Text(t.supplierNoPayments, style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted))
                    else
                      _Rows(
                        rows: [
                          for (var i = 0; i < data.payments.length; i++)
                            _Row(
                              key: Key('supplier.payment.$i'),
                              title: paymentMethodLabel(t, data.payments[i].method),
                              sub: fullTime(data.payments[i].at),
                              trailing: Num(shekel(data.payments[i].amount), size: 16, weight: FontWeight.w700, color: StatusTone.success.fg),
                              onTap: () => showSaleSheet<void>(context, builder: (_) => _PaymentSheet(payment: data.payments[i])),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (data.supplier.balance.isPositive)
                ActionBar(
                  child: FilledButton(
                    key: const Key('supplier.pay'),
                    onPressed: () async {
                      final paid = await showSaleSheet<bool>(
                        context,
                        builder: (_) => SupplierPaySheet(supplierId: supplierId, balance: data.supplier.balance),
                      );
                      if (paid ?? false) ref.invalidate(supplierProvider(supplierId));
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

/// A product at a supplier: only its invoice, or its invoices when it was bought more than once.
class SupplierProductScreen extends ConsumerWidget {
  const SupplierProductScreen({super.key, required this.supplierId, required this.productId, required this.name});

  final int supplierId;
  final int productId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final provider = productInvoicesProvider((supplierId, productId));
    final invoices = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: invoices.when(
          loading: () => const LoadingView.detail(),
          error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(provider)),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final invoice in data.invoices) ...[
                _InvoiceCard(key: Key('supplier.invoice.${invoice.number}'), invoice: invoice, weighed: data.weighed),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted)),
        Flexible(child: Num(value, size: strong ? 22 : 16, weight: strong ? FontWeight.w700 : FontWeight.w600)),
      ],
    ),
  );
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({super.key, required this.invoice, required this.weighed});

  final ProductInvoice invoice;
  final bool weighed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cartons = invoice.cartons;
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.supplierInvoiceNumber('${invoice.number}'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            _Fact(t.supplierTime, fullTime(invoice.at)),
            if (weighed) ...[
              _Fact(t.goodsBuyKilo, shekel(invoice.buyPrice)),
              _Fact(t.goodsKilos, invoice.quantity),
            ] else ...[
              _Fact(t.goodsBuyCarton, shekel(invoice.buyPrice)),
              if (cartons != null) _Fact(t.goodsCartons, '$cartons'),
              if (invoice.packSize != null) _Fact(t.goodsPackSize, '${invoice.packSize}'),
              _Fact(t.supplierPieces, invoice.quantity),
            ],
            if (invoice.by != null) _Fact(t.supplierBy, invoice.by!),
            const Divider(height: 16),
            _Fact(t.supplierFinalPrice, shekel(invoice.total), strong: true),
          ],
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.title, required this.facts});

  final String title;
  final List<Widget> facts;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + MediaQuery.paddingOf(context).bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title, closeLabel: AppLocalizations.of(context).goodsFinish),
        const SizedBox(height: 8),
        ...facts,
      ],
    ),
  );
}

class _PaymentSheet extends StatelessWidget {
  const _PaymentSheet({required this.payment});

  final SupplierPayment payment;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return _DetailSheet(
      title: t.supplierPaymentDetail,
      facts: [
        _Fact(t.supplierAmount, shekel(payment.amount), strong: true),
        _Fact(t.supplierMethod, paymentMethodLabel(t, payment.method)),
        _Fact(t.supplierTime, fullTime(payment.at)),
        if (payment.by != null) _Fact(t.supplierBy, payment.by!),
      ],
    );
  }
}

/// How the supplier was paid, in the checkout's order.
class MethodChoices extends StatelessWidget {
  const MethodChoices({super.key, required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        for (var row = 0; row < (paymentMethods.length + 1) ~/ 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          OptionRow(
            children: [
              for (final method in paymentMethods.skip(row * 2).take(2))
                OptionButton(
                  key: Key('goods.method.$method'),
                  label: paymentMethodLabel(t, method),
                  selected: selected == method,
                  onTap: () => onPick(method),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A payment to the supplier. Pops true when it was recorded.
class SupplierPaySheet extends ConsumerStatefulWidget {
  const SupplierPaySheet({super.key, required this.supplierId, required this.balance});

  final int supplierId;
  final Money balance;

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
    if (amount > widget.balance) return setState(() => _error = t.supplierPayTooMuch);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(goodsRepositoryProvider)
          .pay(supplierId: widget.supplierId, amount: amount, method: _method, operationId: _operationId);
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
    final left = widget.balance - (_value ?? Money.zero);
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
                  Num(shekel(widget.balance), size: 16, weight: FontWeight.w700, color: StatusTone.debt.fg),
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
