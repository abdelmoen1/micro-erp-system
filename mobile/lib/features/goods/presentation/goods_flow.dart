import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../guide/coach_tour.dart';
import '../../customers/presentation/record_payment_screen.dart' show paymentMethods;
import '../../more/presentation/more_widgets.dart' show pushScreen;
import '../../products/domain/product.dart';
import '../../products/domain/product_code_payload.dart';
import '../../products/presentation/add_product_flow.dart' show confirmDiscard;
import '../../sale/presentation/checkout_screen.dart' show paymentMethodLabel;
import '../../sale/presentation/sale_widgets.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../domain/goods.dart';
import 'goods_item_screen.dart';
import 'supplier_screens.dart';

/// «تسجيل بضاعة». True when a delivery was recorded.
Future<bool> openGoodsFlow(BuildContext context) async {
  final done = await pushScreen<bool>(context, const GoodsFlowScreen());
  return done ?? false;
}

enum _Step { items, supplier, payment, done }

/// Three steps on a page of their own: what came in, from whom and at what price, what was paid.
/// Totals are computed here for the screen and again by the server; nobody types them.
class GoodsFlowScreen extends ConsumerStatefulWidget {
  const GoodsFlowScreen({super.key});

  @override
  ConsumerState<GoodsFlowScreen> createState() => _GoodsFlowScreenState();
}

class _GoodsFlowScreenState extends ConsumerState<GoodsFlowScreen> {
  final _supplier = TextEditingController();
  final _paid = TextEditingController();

  /// Buying prices by line, kept across steps. Same order as [_lines].
  final List<TextEditingController> _buy = [];
  final List<GoodsLine> _lines = [];
  final String _operationId = 'goods-${DateTime.now().microsecondsSinceEpoch}';

  _Step _step = _Step.items;
  List<Supplier> _known = const [];
  String _method = paymentMethods.first;
  bool _busy = false;
  bool _checking = false;
  bool _showErrors = false;
  String? _banner;
  GoodsReceipt? _receipt;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _supplier.dispose();
    _paid.dispose();
    for (final c in _buy) {
      c.dispose();
    }
    super.dispose();
  }

  /// Only for suggestions: a typed name works without them.
  Future<void> _loadSuppliers() async {
    try {
      final rows = await ref.read(goodsRepositoryProvider).suppliers();
      if (mounted) setState(() => _known = rows);
    } on ApiFailure {
      // Nothing to suggest.
    }
  }

  void _addLine(GoodsLine line) {
    _lines.add(line);
    _buy.add(TextEditingController(text: line.buyPrice?.toApi() ?? ''));
  }

  Future<void> _scan() async {
    final navigator = Navigator.of(context);
    final raw = await scanProductCode(context);
    if (raw == null || !mounted) return;
    final data = parseProductCode(raw);
    final code = data is ProductCodeData ? data : null;
    final barcode = code?.barcode;

    final repeated = barcode == null ? -1 : _lines.indexWhere((l) => l.barcode == barcode);
    if (repeated >= 0) return _edit(repeated);

    Product? product;
    String? catalogName;
    ProductUnit? catalogUnit;
    if (barcode != null) {
      setState(() => _checking = true);
      try {
        final match = await ref.read(productRepositoryProvider).catalogLookup(barcode);
        product = match.product;
        catalogName = match.catalogName;
        catalogUnit = match.catalogUnit;
      } on ApiFailure {
        // The server finds the product by its barcode when the delivery is saved.
      }
      if (!mounted) return;
      setState(() => _checking = false);
    }

    final unit = catalogUnit ?? code?.unit;
    final line = await navigator.push<GoodsLine>(
      MaterialPageRoute(
        builder: (_) => GoodsItemScreen(
          seed: GoodsItemSeed(
            product: product,
            barcode: barcode,
            name: catalogName ?? code?.name,
            kind: unit == ProductUnit.kg ? GoodsKind.weight : null,
          ),
        ),
      ),
    );
    if (line != null && mounted) setState(() => _addLine(_withKnownCost(line, product)));
  }

  /// The last cost is the likely one: shown ready on the supplier step, still changeable.
  GoodsLine _withKnownCost(GoodsLine line, Product? product) {
    final cost = product?.costPrice;
    if (cost == null) return line;
    final piece = Money.parse(cost);
    return line.withBuyPrice(line.isWeighed ? piece : Money.cents(piece.cents * line.packSize));
  }

  Future<void> _addByHand() async {
    final line = await Navigator.of(context).push<GoodsLine>(MaterialPageRoute(builder: (_) => const GoodsItemScreen()));
    if (line != null && mounted) setState(() => _addLine(line));
  }

  Future<void> _edit(int index) async {
    final line = await Navigator.of(context).push<GoodsLine>(
      MaterialPageRoute(builder: (_) => GoodsItemScreen(line: _lines[index])),
    );
    if (line != null && mounted) setState(() => _lines[index] = line);
  }

  void _remove(int index) => setState(() {
    _lines.removeAt(index);
    _buy.removeAt(index).dispose();
  });

  Money? _money(String text) {
    try {
      return Money.parse(text.trim());
    } on FormatException {
      return null;
    }
  }

  /// [_lines] with the prices typed so far.
  List<GoodsLine> get _priced {
    return [
      for (var i = 0; i < _lines.length; i++)
        _lines[i].withBuyPrice(switch (_money(_buy[i].text)) {
          final Money price when price.isPositive => price,
          _ => null,
        }),
    ];
  }

  Money get _total => _priced.fold(Money.zero, (sum, line) => sum + line.total);

  Money get _paidNow => _money(_paid.text) ?? Money.zero;

  void _toPayment() {
    final ready = _supplier.text.trim().isNotEmpty && _priced.every((l) => l.buyPrice != null);
    setState(() {
      _showErrors = !ready;
      if (ready) _step = _Step.payment;
    });
  }

  Future<void> _save(AppLocalizations t) async {
    setState(() {
      _busy = true;
      _banner = null;
    });
    try {
      final receipt = await ref
          .read(goodsRepositoryProvider)
          .record(
            supplierName: _supplier.text,
            lines: _priced,
            paid: _paidNow,
            method: _method,
            operationId: _operationId,
          );
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _step = _Step.done;
        _busy = false;
      });
    } on ValidationFailed catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = failure.fieldErrors.values.expand((e) => e).firstOrNull ?? failure.message ?? t.formFailed;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _banner = switch (failure) {
          Forbidden() => t.formForbidden,
          NetworkFailure() => t.formNetwork,
          _ => failure.message ?? t.formFailed,
        };
      });
    }
  }

  void _back() => setState(() {
    _banner = null;
    _step = _step == _Step.payment ? _Step.supplier : _Step.items;
  });

  void _again() => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const GoodsFlowScreen()));

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dirty = _lines.isNotEmpty && _step != _Step.done;

    return PopScope(
      canPop: !dirty && _step != _Step.supplier && _step != _Step.payment && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        if (_step == _Step.supplier || _step == _Step.payment) return _back();
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_step == _Step.done ? t.goodsSaved : t.goodsTitle), automaticallyImplyLeading: _step != _Step.done),
        body: SafeArea(
          child: switch (_step) {
            _Step.items => _items(t),
            _Step.supplier => _supplierStep(t),
            _Step.payment => _payment(t),
            _Step.done => _done(t),
          },
        ),
      ),
    );
  }

  Widget _items(AppLocalizations t) => Column(
    children: [
      const _Steps(current: 0),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: CoachTarget(
                id: CoachStep.scan,
                child: FilledButton.icon(
                  key: const Key('goods.scan'),
                  onPressed: _checking ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: Text(t.goodsScan),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('goods.manual'),
                onPressed: _addByHand,
                icon: const Icon(Icons.add_rounded),
                label: Text(t.goodsManual),
              ),
            ),
          ],
        ),
      ),
      if (_checking) const LinearProgressIndicator(minHeight: 2),
      Expanded(
        child: _lines.isEmpty
            ? Center(
                child: Text(t.goodsEmpty, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted)),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _lines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _LineTile(
                  key: Key('goods.line.$i'),
                  line: _lines[i],
                  onTap: () => _edit(i),
                  onRemove: () => _remove(i),
                ),
              ),
      ),
      if (_lines.isNotEmpty)
        ActionBar(
          child: CoachTarget(
            id: CoachStep.next,
            child: FilledButton(
              key: const Key('goods.toSupplier'),
              onPressed: () => setState(() {
                _showErrors = false;
                _step = _Step.supplier;
              }),
              child: Text(t.goodsNextSupplier),
            ),
          ),
        ),
    ],
  );

  Widget _supplierStep(AppLocalizations t) {
    final typed = _supplier.text.trim();
    final matches = typed.isEmpty
        ? _known.take(4).toList()
        : _known.where((s) => s.name.contains(typed) && s.name != typed).take(4).toList();
    final priced = _priced;

    return Column(
      children: [
        const _Steps(current: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              GoodsField(
                fieldKey: const Key('goods.supplier'),
                label: t.goodsSupplierName,
                controller: _supplier,
                error: _showErrors && typed.isEmpty ? t.goodsSupplierRequired : null,
                onChanged: () => setState(() {}),
              ),
              if (matches.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final supplier in matches)
                      ActionChip(
                        key: Key('goods.supplier.${supplier.id}'),
                        label: Text(supplier.name),
                        onPressed: () => setState(() => _supplier.text = supplier.name),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              for (var i = 0; i < priced.length; i++) ...[
                _BuyTile(
                  key: Key('goods.buy.$i'),
                  line: priced[i],
                  controller: _buy[i],
                  fieldKey: Key('goods.buyPrice.$i'),
                  missing: _showErrors && priced[i].buyPrice == null,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        _TotalBar(
          label: t.goodsTotal,
          total: _total,
          child: FilledButton(
            key: const Key('goods.toPayment'),
            style: FilledButton.styleFrom(backgroundColor: HisbahColors.raised, foregroundColor: HisbahColors.primary),
            onPressed: _toPayment,
            child: Text(t.goodsNextPay),
          ),
        ),
      ],
    );
  }

  Widget _payment(AppLocalizations t) {
    final total = _total;
    final paid = _paidNow;
    final left = total - paid;
    final over = left.isNegative;
    final tone = over ? StatusTone.error : (left.isZero ? StatusTone.success : StatusTone.debt);
    final label = over ? t.goodsOverpaid : (left.isZero ? t.goodsPaidFull : t.goodsRemaining);
    final shown = over ? paid - total : left;

    return Column(
      children: [
        const _Steps(current: 2),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Container(
                key: const Key('goods.total'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(HisbahRadius.card)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 18, color: HisbahColors.onPrimary),
                        const SizedBox(width: 6),
                        Text(t.goodsTotal, style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Num(shekel(total), size: 34, weight: FontWeight.w700, color: HisbahColors.onPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GoodsField(
                fieldKey: const Key('goods.paid'),
                label: t.goodsPaid,
                controller: _paid,
                number: true,
                decimal: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 8),
              OptionRow(
                children: [
                  OptionButton(
                    key: const Key('goods.paidAll'),
                    label: t.goodsPaidAll,
                    selected: false,
                    onTap: () => setState(() => _paid.text = total.toApi()),
                  ),
                  OptionButton(
                    key: const Key('goods.allDebt'),
                    label: t.goodsAllDebt,
                    selected: false,
                    onTap: () => setState(_paid.clear),
                  ),
                ],
              ),
              if (paid.isPositive) ...[
                const SizedBox(height: 12),
                MethodChoices(selected: _method, onPick: (m) => setState(() => _method = m)),
              ],
              const SizedBox(height: 14),
              Container(
                key: const Key('goods.remaining'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(HisbahRadius.card)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(label, style: TextStyle(color: tone.fg, fontSize: 16, fontWeight: FontWeight.w600))),
                    Num(shekel(shown), size: 24, weight: FontWeight.w700, color: tone.fg),
                  ],
                ),
              ),
              if (_banner != null) ...[
                const SizedBox(height: 12),
                MessageBanner(icon: Icons.warning_amber_rounded, text: _banner!),
              ],
            ],
          ),
        ),
        ActionBar(
          child: FilledButton(
            key: const Key('goods.save'),
            onPressed: _busy || over ? null : () => _save(t),
            child: BusyLabel(busy: _busy, label: _busy ? t.formSaving : t.goodsSave),
          ),
        ),
      ],
    );
  }

  Widget _done(AppLocalizations t) {
    final receipt = _receipt!;
    Widget row(String label, Money amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, color: strong ? StatusTone.debt.fg : HisbahColors.inkMuted))),
          Num(
            shekel(amount),
            size: strong ? 22 : 16,
            weight: strong ? FontWeight.w700 : FontWeight.w600,
            color: strong ? StatusTone.debt.fg : HisbahColors.ink,
          ),
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
            children: [
              Icon(Icons.check_circle_rounded, size: 72, color: StatusTone.success.fg),
              const SizedBox(height: 12),
              Text(
                t.goodsSaved,
                key: const Key('goods.saved'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                t.goodsStockUp('${receipt.lines}'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted),
              ),
              const SizedBox(height: 20),
              LineCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.goodsStepSupplier, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted)),
                          Flexible(child: Text(receipt.supplierName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      row(t.goodsTotal, receipt.total),
                      row(t.goodsPaid, receipt.paid),
                      const Divider(height: 16),
                      row(t.goodsRemaining, receipt.remaining, strong: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                key: const Key('goods.account'),
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => SupplierAccountScreen(supplierId: receipt.supplierId)),
                ),
                child: Text(t.supplierAccount),
              ),
              const SizedBox(height: 8),
              OutlinedButton(key: const Key('goods.another'), onPressed: _again, child: Text(t.goodsAnother)),
              const SizedBox(height: 4),
              TextButton(
                key: const Key('goods.finish'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(t.goodsFinish),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Where the person is: البضاعة، المورد، الدفع.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final labels = [t.goodsStepItems, t.goodsStepSupplier, t.goodsStepPay];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(width: 14, height: 2, color: i <= current ? HisbahColors.primary : HisbahColors.progressTrack),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepDot(number: i + 1, done: i < current, active: i == current),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                        color: i == current ? HisbahColors.ink : HisbahColors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.number, required this.done, required this.active});

  final int number;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? HisbahColors.primary : (done ? HisbahColors.primaryTint : null),
      border: active || done ? null : Border.all(color: HisbahColors.borderStrong, width: 2),
    ),
    child: done
        ? const Icon(Icons.check_rounded, size: 16, color: HisbahColors.primary)
        : Text(
            '$number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? HisbahColors.onPrimary : HisbahColors.inkMuted,
            ),
          ),
  );
}

class _LineTile extends StatelessWidget {
  const _LineTile({super.key, required this.line, required this.onTap, required this.onRemove});

  final GoodsLine line;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return LineCard(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    Text(
                      line.isWeighed
                          ? t.goodsKilosValue(line.kilos.format(ProductUnit.kg))
                          : t.goodsCartonsValue('${line.cartons}', '${line.pieces}'),
                      style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t.goodsRemove,
                icon: const Icon(Icons.delete_outline_rounded, color: HisbahColors.inkMuted),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyTile extends StatelessWidget {
  const _BuyTile({
    super.key,
    required this.line,
    required this.controller,
    required this.fieldKey,
    required this.missing,
    required this.onChanged,
  });

  final GoodsLine line;
  final TextEditingController controller;
  final Key fieldKey;
  final bool missing;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cost = line.pieceCost;
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        line.isWeighed
                            ? t.goodsKilosValue(line.kilos.format(ProductUnit.kg))
                            : t.goodsCartonsValue('${line.cartons}', '${line.pieces}'),
                        style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
                      ),
                      if (cost != null)
                        Text(t.goodsPieceCost(shekel(cost)), style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: GoodsField(
                    fieldKey: fieldKey,
                    label: line.isWeighed ? t.goodsBuyKilo : t.goodsBuyCarton,
                    controller: controller,
                    number: true,
                    decimal: true,
                    error: missing ? t.goodsBuyRequired : null,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.goodsLineTotal, style: const TextStyle(color: HisbahColors.inkMuted)),
                Num(shekel(line.total), size: 16, weight: FontWeight.w700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The running total in the brand teal, above the step's button.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.label, required this.total, required this.child});

  final String label;
  final Money total;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    color: HisbahColors.primary,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 16))),
            Num(shekel(total), key: const Key('goods.barTotal'), size: 24, weight: FontWeight.w700, color: HisbahColors.onPrimary),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
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

