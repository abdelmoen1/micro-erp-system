import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../guide/coach_tour.dart';
import '../../more/presentation/more_widgets.dart' show pushScreen;
import '../../products/domain/product.dart';
import '../../products/domain/product_code_payload.dart';
import '../../products/presentation/add_product_flow.dart' show confirmDiscard;
import '../../sale/presentation/sale_widgets.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../domain/goods.dart';
import 'goods_item_screen.dart';
import 'supplier_screens.dart' show fullTime;

/// «تسجيل بضاعة». True when a delivery was recorded.
Future<bool> openGoodsFlow(BuildContext context) async {
  final done = await pushScreen<bool>(context, const GoodsFlowScreen());
  return done ?? false;
}

enum _Step { items, supplier, invoice }

/// Two steps on a page of their own: what came in, then from whom and at what prices. The delivery
/// is saved on the supplier's account and shown as an invoice; payments are recorded per product.
/// Totals are computed here for the screen and again by the server; nobody types them.
class GoodsFlowScreen extends ConsumerStatefulWidget {
  const GoodsFlowScreen({super.key});

  @override
  ConsumerState<GoodsFlowScreen> createState() => _GoodsFlowScreenState();
}

class _GoodsFlowScreenState extends ConsumerState<GoodsFlowScreen> {
  final _supplier = TextEditingController();

  /// Prices by line, kept across steps. Same order as [_lines].
  final List<TextEditingController> _buy = [];
  final List<TextEditingController> _carton = [];
  final List<GoodsLine> _lines = [];
  final String _operationId = 'goods-${DateTime.now().microsecondsSinceEpoch}';

  _Step _step = _Step.items;
  List<Supplier> _known = const [];
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
    for (final c in [..._buy, ..._carton]) {
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

  void _addLine(GoodsLine line, {Money? buy, Money? carton}) {
    _lines.add(line);
    _buy.add(TextEditingController(text: buy?.toApi() ?? ''));
    _carton.add(TextEditingController(text: carton?.toApi() ?? ''));
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
    if (barcode != null) {
      setState(() => _checking = true);
      try {
        final match = await ref.read(productRepositoryProvider).catalogLookup(barcode);
        product = match.product;
        catalogName = match.catalogName;
      } on ApiFailure {
        // The server finds the product by its barcode when the delivery is saved.
      }
      if (!mounted) return;
      setState(() => _checking = false);
    }

    final line = await navigator.push<GoodsLine>(
      MaterialPageRoute(
        builder: (_) => GoodsItemScreen(
          seed: GoodsItemSeed(product: product, barcode: barcode, name: catalogName ?? code?.name),
        ),
      ),
    );
    if (line == null || !mounted) return;
    setState(() => _addLine(line, buy: _lastCost(line, product), carton: _lastCarton(line, product)));
  }

  /// The last prices are the likely ones: shown ready on the supplier step, still changeable.
  Money? _lastCost(GoodsLine line, Product? product) {
    final cost = product?.costPrice;
    if (cost == null) return null;
    final unit = Money.parse(cost);
    return line.isWeighed ? unit : Money.cents(unit.cents * line.packSize);
  }

  Money? _lastCarton(GoodsLine line, Product? product) {
    final price = product?.packPrice;
    return price == null || product?.packSize != line.packSize ? null : Money.parse(price);
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
    _carton.removeAt(index).dispose();
  });

  Money? _money(String text) {
    try {
      final value = Money.parse(text.trim());
      return value.isPositive ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// [_lines] with the prices typed so far.
  List<GoodsLine> get _priced => [
    for (var i = 0; i < _lines.length; i++)
      _lines[i].withPrices(buy: _money(_buy[i].text), carton: _money(_carton[i].text)),
  ];

  Money get _total => _priced.fold(Money.zero, (sum, line) => sum + line.total);

  Future<void> _save(AppLocalizations t) async {
    final lines = _priced;
    final ready = _supplier.text.trim().isNotEmpty && lines.every((l) => l.buyPrice != null && l.cartonPriceOk);
    if (!ready) {
      return setState(() {
        _showErrors = true;
        _banner = t.formFixErrors;
      });
    }

    setState(() {
      _busy = true;
      _banner = null;
    });
    try {
      final receipt = await ref
          .read(goodsRepositoryProvider)
          .record(supplierName: _supplier.text, lines: lines, operationId: _operationId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _step = _Step.invoice;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final dirty = _lines.isNotEmpty && _step == _Step.items;

    return PopScope(
      canPop: !dirty && _step != _Step.supplier && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _busy) return;
        if (_step == _Step.supplier) {
          return setState(() {
            _banner = null;
            _step = _Step.items;
          });
        }
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_step == _Step.invoice ? t.goodsInvoiceTitle : t.goodsTitle),
          automaticallyImplyLeading: _step != _Step.invoice,
        ),
        body: SafeArea(
          child: switch (_step) {
            _Step.items => _items(t),
            _Step.supplier => _supplierStep(t),
            _Step.invoice => _invoice(t),
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
                _PriceTile(
                  key: Key('goods.buy.$i'),
                  index: i,
                  line: priced[i],
                  buy: _buy[i],
                  carton: _carton[i],
                  showErrors: _showErrors,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        if (_banner != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: MessageBanner(icon: Icons.warning_amber_rounded, text: _banner!),
          ),
        _TotalBar(
          label: t.goodsTotal,
          total: _total,
          child: FilledButton(
            key: const Key('goods.save'),
            style: FilledButton.styleFrom(backgroundColor: HisbahColors.raised, foregroundColor: HisbahColors.primary),
            onPressed: _busy ? null : () => _save(t),
            child: BusyLabel(busy: _busy, label: _busy ? t.formSaving : t.goodsSave),
          ),
        ),
      ],
    );
  }

  /// The delivery as it was saved, for the supplier: every item, its prices and the total.
  Widget _invoice(AppLocalizations t) {
    final receipt = _receipt!;
    final lines = _priced;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                key: const Key('goods.invoice'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(HisbahRadius.card)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.supplierName,
                      style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(fullTime(receipt.at), style: const TextStyle(color: HisbahColors.onPrimaryMuted, fontSize: 14)),
                    const SizedBox(height: 10),
                    Text(t.goodsTotal, style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 16)),
                    Num(shekel(receipt.total), size: 34, weight: FontWeight.w700, color: HisbahColors.onPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LineCard(
                child: Column(
                  children: [
                    for (var i = 0; i < lines.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _InvoiceRow(line: lines[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ActionBar(
          child: FilledButton(
            key: const Key('goods.finish'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.goodsFinish),
          ),
        ),
      ],
    );
  }
}

/// Where the person is: البضاعة، المورد.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final labels = [t.goodsStepItems, t.goodsStepSupplier];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: i <= current ? HisbahColors.primary : HisbahColors.progressTrack,
                ),
              ),
            _StepDot(number: i + 1, done: i < current, active: i == current),
            const SizedBox(width: 6),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 15,
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                color: i == current ? HisbahColors.ink : HisbahColors.inkMuted,
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

String _amount(AppLocalizations t, GoodsLine line) => line.isWeighed
    ? t.goodsKilosValue(line.kilos.format(ProductUnit.kg))
    : t.goodsCartonsValue('${line.cartons}', '${line.pieces}');

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
                    Text(_amount(t, line), style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted)),
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

/// What the item cost and what a whole carton sells for, with the line's total under them.
class _PriceTile extends StatelessWidget {
  const _PriceTile({
    super.key,
    required this.index,
    required this.line,
    required this.buy,
    required this.carton,
    required this.showErrors,
    required this.onChanged,
  });

  final int index;
  final GoodsLine line;
  final TextEditingController buy;
  final TextEditingController carton;
  final bool showErrors;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cost = line.pieceCost;
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(line.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(_amount(t, line), style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GoodsField(
                    fieldKey: Key('goods.buyPrice.$index'),
                    label: line.isWeighed ? t.goodsBuyKilo : t.goodsBuyCarton,
                    controller: buy,
                    number: true,
                    decimal: true,
                    error: showErrors && line.buyPrice == null ? t.goodsBuyRequired : null,
                    onChanged: onChanged,
                  ),
                ),
                if (line.sellsByCarton) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: GoodsField(
                      fieldKey: Key('goods.cartonPrice.$index'),
                      label: t.goodsSellCarton,
                      controller: carton,
                      number: true,
                      decimal: true,
                      error: showErrors && !line.cartonPriceOk ? t.goodsCartonPriceLow : null,
                      onChanged: onChanged,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    cost == null ? t.goodsLineTotal : t.goodsPieceCost(shekel(cost)),
                    style: const TextStyle(color: HisbahColors.inkMuted),
                  ),
                ),
                Num(shekel(line.total), size: 16, weight: FontWeight.w700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.line});

  final GoodsLine line;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(_amount(t, line), style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
              ],
            ),
          ),
          Num(shekel(line.total), size: 16, weight: FontWeight.w700),
        ],
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
