import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../more/presentation/more_widgets.dart';
import '../../sale/presentation/sale_detail_screen.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'add_product_flow.dart' show PackSection, productFormErrors;

/// The product and its stock ledger, loaded together so the balance and the movements agree.
final productDetailProvider = FutureProvider.autoDispose.family<(Product, List<StockMove>), int>((ref, id) async {
  final repository = ref.watch(productRepositoryProvider);
  final results = await Future.wait([repository.product(id), repository.movements(id)]);
  return (results[0] as Product, results[1] as List<StockMove>);
});

/// Opens a product page; true when something changed (the list reloads).
Future<bool> openProduct(BuildContext context, int productId) async =>
    await pushScreen<bool>(context, ProductDetailScreen(productId: productId)) ?? false;

final _when = DateFormat('dd/MM · HH:mm', 'en');

String unitWord(AppLocalizations t, Product p) => p.isWeighed ? t.prodPerKg : t.prodPerPiece;

/// Inventory management for one product: what it sells for, what is on the shelf, every movement,
/// and for the owner or a manager: count or adjust the stock, edit it, deactivate it.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _changed = false;

  void _refresh() {
    _changed = true;
    ref.invalidate(productDetailProvider(widget.productId));
  }

  Future<void> _adjust(Product product) async {
    final message = await showSaleSheet<String>(context, builder: (_) => AdjustStockSheet(product: product));
    if (message == null || !mounted) return;
    _refresh();
    showNote(context, message);
  }

  Future<void> _edit(Product product) async {
    final saved = await showSaleSheet<bool>(context, builder: (_) => EditProductSheet(product: product));
    if (saved != true || !mounted) return;
    _refresh();
    showNote(context, AppLocalizations.of(context).prodSaved);
  }

  Future<void> _deactivate(Product product) async {
    final t = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: t.prodDeactivateTitle(product.name),
      body: t.prodDeactivateBody,
      action: t.prodDeactivate,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(productRepositoryProvider).deactivate(product.id);
      if (!mounted) return;
      showNote(context, t.prodDeactivated(product.name));
      Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (mounted) showNote(context, failure is Forbidden ? t.prodViewOnly : (failure.message ?? t.staffActionError));
    }
  }

  Future<void> _reactivate(Product product) async {
    final t = AppLocalizations.of(context);
    try {
      await ref.read(productRepositoryProvider).reactivate(product.id);
      if (!mounted) return;
      _refresh();
      showNote(context, t.prodReactivated);
    } on ApiFailure catch (failure) {
      if (mounted) showNote(context, failure is Forbidden ? t.prodViewOnly : (failure.message ?? t.staffActionError));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final manager = session is SignedIn && session.user.canOverride;
    final page = ref.watch(productDetailProvider(widget.productId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(page.value?.$1.name ?? '')),
        body: page.when(
          loading: () => const LoadingView.detail(),
          error: (_, _) => ErrorView(message: t.prodDetailError, onRetry: () => ref.invalidate(productDetailProvider(widget.productId))),
          data: (data) {
            final (p, moves) = data;
            return RefreshIndicator(
              onRefresh: () => ref.refresh(productDetailProvider(widget.productId).future),
              child: ListView(
                key: const Key('product.list'),
                padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (!p.isActive) ...[
                    ToneCard(tone: StatusTone.voided, icon: Icons.block_rounded, title: t.prodInactiveNote),
                    const SizedBox(height: 12),
                  ],
                  _Summary(product: p),
                  const SizedBox(height: 12),
                  if (manager && p.isActive) ...[
                    FilledButton.icon(
                      key: const Key('product.adjust'),
                      onPressed: () => _adjust(p),
                      icon: const Icon(Icons.inventory_outlined),
                      label: Text(t.prodAdjust),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('product.edit'),
                      onPressed: () => _edit(p),
                      icon: const Icon(Icons.edit_outlined),
                      label: Text(t.prodEdit),
                    ),
                  ] else if (manager)
                    FilledButton.icon(
                      key: const Key('product.reactivate'),
                      onPressed: () => _reactivate(p),
                      icon: const Icon(Icons.restore_rounded),
                      label: Text(t.prodReactivate),
                    )
                  else
                    Text(t.prodViewOnly, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                  const SizedBox(height: 18),
                  GroupLabel(t.prodMovements),
                  const SizedBox(height: 8),
                  if (moves.isEmpty)
                    Text(t.prodNoMovements, style: const TextStyle(color: HisbahColors.inkMuted))
                  else
                    LineCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < moves.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                            _MoveRow(move: moves[i], product: p),
                          ],
                        ],
                      ),
                    ),
                  if (manager && p.isActive) ...[
                    const SizedBox(height: 18),
                    TextButton(
                      key: const Key('product.deactivate'),
                      onPressed: () => _deactivate(p),
                      style: TextButton.styleFrom(foregroundColor: HisbahColors.dangerSolid),
                      child: Text(t.prodDeactivate),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = product;
    final stock = p.currentStock;
    final tone = stock.isNegative || stock.isZero
        ? StatusTone.error
        : p.isLowStock
        ? StatusTone.warning
        : StatusTone.success;
    const muted = TextStyle(fontSize: 13, color: HisbahColors.inkMuted);
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      if (p.barcode != null) LtrValue(p.barcode!, style: muted),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(t.prodStockNowLabel, style: muted),
                    Text(
                      '${isolateLtr(stock.format(p.unit))} ${unitWord(t, p)}',
                      key: const Key('product.stock'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tone.fg),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24, color: HisbahColors.border),
            Text(
              '${isolateLtr(formatShekel(p.sellingPrice))} / ${unitWord(t, p)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Wrap(
              spacing: 10,
              children: [
                if (p.costPrice != null) Text(t.prodCostLabel(isolateLtr(formatShekel(p.costPrice!))), style: muted),
                Text(t.prodMinimumLabel(isolateLtr(p.minimumStock.format(p.unit))), style: muted),
                if (p.hasPack) Text(t.prodPackLabel(p.packSize!, isolateLtr(formatShekel(p.packPrice!))), style: muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.move, required this.product});

  final StockMove move;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final m = move;
    final label = switch (m.type) {
      'opening' => t.moveOpening,
      'sale' => t.moveSale,
      'sale_void' => t.moveVoid,
      'sale_return' => t.moveReturn,
      'adjustment_in' => t.moveIn,
      'adjustment_out' => t.moveOut,
      _ => m.type,
    };
    final invoice = m.invoiceId;
    final tone = m.quantity.isNegative ? StatusTone.debt : StatusTone.success;
    return InkWell(
      onTap: invoice == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: invoice))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice == null ? label : '$label · ${t.custDebtSale(invoice)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [if (m.createdAt != null) isolateLtr(_when.format(m.createdAt!)), ?m.reason].join(' · '),
                    style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isolateLtr('${m.quantity.isPositive ? '+' : ''}${m.quantity.format(product.unit)}'),
                  style: TextStyle(fontWeight: FontWeight.w800, color: tone.fg),
                ),
                Text(t.moveAfter(isolateLtr(m.balanceAfter.format(product.unit))), style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _AdjustMode { count, delta, cartons }

/// Count the shelf, add or remove a quantity, or receive whole cartons; always with a reason.
/// Shows the recorded stock and the stock after the change before anything is sent. Pops with
/// the confirmation to show.
class AdjustStockSheet extends ConsumerStatefulWidget {
  const AdjustStockSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends ConsumerState<AdjustStockSheet> {
  final _quantity = TextEditingController();
  _AdjustMode _mode = _AdjustMode.count;
  String? _reason;
  bool _saving = false;
  String? _error;

  /// One adjustment, one Idempotency-Key: a retry after a timeout never applies it twice.
  late String _operation = _newOperation();

  String _newOperation() => 'adjust-${widget.product.id}-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  /// The change to send (signed, in the product's unit or in cartons), or null while invalid.
  Quantity? _change() {
    final p = widget.product;
    final text = _quantity.text.trim();
    final whole = _mode == _AdjustMode.cartons || !p.isWeighed;
    final pattern = switch (_mode) {
      _AdjustMode.count => whole ? RegExp(r'^\d{1,7}$') : RegExp(r'^\d{1,7}(\.\d{1,3})?$'),
      _AdjustMode.delta => whole ? RegExp(r'^-?\d{1,7}$') : RegExp(r'^-?\d{1,7}(\.\d{1,3})?$'),
      _AdjustMode.cartons => RegExp(r'^\d{1,5}$'),
    };
    if (!pattern.hasMatch(text)) return null;
    final value = Quantity.parse(text);
    return _mode == _AdjustMode.count ? value - p.currentStock : value;
  }

  /// The stock after the change, in the product's unit.
  Quantity? _after(Quantity? change) {
    if (change == null) return null;
    final p = widget.product;
    final pieces = _mode == _AdjustMode.cartons ? Quantity.milli(change.milli * p.packSize!) : change;
    return p.currentStock + pieces;
  }

  Future<void> _save(AppLocalizations t) async {
    final change = _change();
    final after = _after(change);
    if (change == null || after == null || change.isZero || after.isNegative) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final p = widget.product;
    try {
      final updated = await ref
          .read(stockRepositoryProvider)
          .addStock(
            p,
            quantity: change.format(_mode == _AdjustMode.cartons ? ProductUnit.piece : p.unit),
            reason: _reason ?? _defaultReason(t),
            operationId: _operation,
            pack: _mode == _AdjustMode.cartons,
          );
      if (mounted) Navigator.of(context).pop(t.adjDone('${updated.currentStock.format(updated.unit)} ${unitWord(t, updated)}'));
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (failure) {
          Forbidden() => t.prodViewOnly,
          ValidationFailed(:final fieldErrors) => fieldErrors.values.expand((e) => e).firstOrNull ?? failure.message,
          NetworkFailure() => t.formNetwork,
          _ => failure.message ?? t.staffActionError,
        };
      });
    }
  }

  String _defaultReason(AppLocalizations t) => switch (_mode) {
    _AdjustMode.count => t.adjReasonCount,
    _AdjustMode.delta || _AdjustMode.cartons => t.adjReasonReceived,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = widget.product;
    final unit = unitWord(t, p);
    final change = _change();
    final after = _after(change);
    final typed = _quantity.text.trim().isNotEmpty;
    final problem = !typed
        ? null
        : change == null
        ? (p.isWeighed && _mode != _AdjustMode.cartons ? t.adjInvalidKg : t.adjInvalidPiece)
        : change.isZero
        ? t.adjNoChange
        : after!.isNegative
        ? t.adjNegative
        : null;
    final reasons = [t.adjReasonCount, t.adjReasonReceived, t.adjReasonDamaged, t.adjReasonFix];
    final reason = _reason ?? _defaultReason(t);

    return FormSheet(
      header: SheetHeader(title: t.adjTitle(p.name), closeLabel: t.cancel, onClose: _saving ? null : () => Navigator.of(context).pop()),
      action: FilledButton(
        key: const Key('adjust.save'),
        onPressed: _saving || problem != null || change == null ? null : () => _save(t),
        child: BusyLabel(busy: _saving, label: t.adjSave),
      ),
      children: [
            OptionRow(
              gap: 4,
              children: [
                for (final (mode, label) in [
                  (_AdjustMode.count, t.adjCount),
                  (_AdjustMode.delta, t.adjDelta),
                  if (p.hasPack) (_AdjustMode.cartons, t.adjCartons),
                ])
                  OptionButton(
                    key: Key('adjust.mode.${mode.name}'),
                    label: label,
                    fontSize: 13,
                    selected: _mode == mode,
                    onTap: _saving
                        ? null
                        : () => setState(() {
                            _mode = mode;
                            _quantity.clear();
                            _operation = _newOperation();
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            MoreField(
              fieldKey: 'adjust.quantity',
              hint: t.phAdjustQty,
              label: switch (_mode) {
                _AdjustMode.count => t.adjCountLabel(unit),
                _AdjustMode.delta => t.adjDeltaLabel(unit),
                _AdjustMode.cartons => t.adjCartonsLabel(p.packSize ?? 0),
              },
              controller: _quantity,
              required: true,
              ltr: true,
              keyboard: TextInputType.numberWithOptions(
                signed: _mode == _AdjustMode.delta,
                decimal: p.isWeighed && _mode != _AdjustMode.cartons,
              ),
              error: problem,
              enabled: !_saving,
              action: TextInputAction.done,
              onChanged: (_) => setState(() => _operation = _newOperation()),
            ),
            if (after != null && problem == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  t.adjPreview(
                    '${isolateLtr(p.currentStock.format(p.unit))} $unit',
                    '${isolateLtr(after.format(p.unit))} $unit',
                  ),
                  key: const Key('adjust.preview'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            GroupLabel(t.adjReason),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: reason == r,
                    onSelected: _saving ? null : (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _error!, alert: true),
            ],
      ],
    );
  }
}

/// Name, prices, the low-stock alert and the carton of a product. The stock is not here: it
/// changes only by sales and adjustments. Pops true when saved.
class EditProductSheet extends ConsumerStatefulWidget {
  const EditProductSheet({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<EditProductSheet> createState() => _EditProductSheetState();
}

class _EditProductSheetState extends ConsumerState<EditProductSheet> {
  late final _name = TextEditingController(text: widget.product.name);
  late final _price = TextEditingController(text: widget.product.sellingPrice);
  late final _cost = TextEditingController(text: widget.product.costPrice ?? '');
  late final _minimum = TextEditingController(text: widget.product.minimumStock.format(widget.product.unit));
  late final _packSize = TextEditingController(text: widget.product.packSize?.toString() ?? '');
  late final _packPrice = TextEditingController(text: widget.product.packPrice ?? '');
  late bool _pack = widget.product.hasPack;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _banner;

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _minimum, _packSize, _packPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppLocalizations t) async {
    final p = widget.product;
    final errors = productFormErrors(
      t,
      unit: p.unit,
      name: _name.text,
      price: _price.text,
      cost: _cost.text,
      stock: '0',
      minimum: _minimum.text,
      pack: _pack,
      packSize: _packSize.text,
      packPrice: _packPrice.text,
    );
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
    final withPack = _pack && !p.isWeighed;
    final fields = <String, Object?>{
      'name': _name.text.trim(),
      'selling_price': _price.text.trim(),
      'cost_price': _cost.text.trim().isEmpty ? null : _cost.text.trim(),
      if (_minimum.text.trim().isNotEmpty) 'minimum_stock': _minimum.text.trim(),
      // A carton is sent whole or cleared whole, never half-set.
      if (withPack) ...{'pack_size': _packSize.text.trim(), 'pack_price': _packPrice.text.trim()},
      if (!withPack && p.hasPack) ...{'pack_size': null, 'pack_price': null},
    };
    setState(() => _saving = true);
    try {
      await ref.read(productRepositoryProvider).update(p.id, fields);
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationFailed catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errors = {
            for (final e in failure.fieldErrors.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
          if (_errors.isEmpty) _banner = failure.message;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _banner = failure is Forbidden ? t.prodViewOnly : (failure is NetworkFailure ? t.formNetwork : failure.message ?? t.formFailed);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = widget.product;
    final unit = unitWord(t, p);
    final whole = !p.isWeighed;
    return FormSheet(
      header: SheetHeader(title: t.prodEdit, closeLabel: t.cancel, onClose: _saving ? null : () => Navigator.of(context).pop()),
      action: FilledButton(
        key: const Key('edit.save'),
        onPressed: _saving ? null : () => _save(t),
        child: BusyLabel(busy: _saving, label: t.storeSave),
      ),
      children: [
            if (_banner != null) ...[
              ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _banner!, alert: true),
              const SizedBox(height: 12),
            ],
            MoreField(fieldKey: 'edit.name', label: t.formName, controller: _name, hint: t.formNameHint, required: true, error: _errors['name'], enabled: !_saving),
            MoreField(
              fieldKey: 'edit.selling_price',
              label: t.formPrice,
              controller: _price,
              required: true,
              ltr: true,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              helper: p.isWeighed ? t.formPriceHelpKg : t.formPriceHelpPiece,
              error: _errors['selling_price'],
              enabled: !_saving,
            ),
            MoreField(
              fieldKey: 'edit.cost_price',
              label: t.formCost,
              controller: _cost,
              ltr: true,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              helper: t.formCostHelp,
              error: _errors['cost_price'],
              enabled: !_saving,
            ),
            MoreField(
              fieldKey: 'edit.minimum_stock',
              label: '${t.formMin} ($unit)',
              controller: _minimum,
              ltr: true,
              keyboard: whole ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
              helper: t.formMinHelp,
              error: _errors['minimum_stock'],
              enabled: !_saving,
            ),
            if (whole)
              ListenableBuilder(
                listenable: Listenable.merge([_price, _packSize, _packPrice]),
                builder: (context, _) => PackSection(
                  enabled: !_saving,
                  open: _pack,
                  onOpen: (open) => setState(() => _pack = open),
                  size: _packSize,
                  price: _packPrice,
                  piecePrice: _price.text,
                  errors: _errors,
                  fieldBuilder: (key, label, controller) => MoreField(
                    fieldKey: 'form.$key',
                    hint: key == 'pack_size' ? t.phPackSize : t.phPackPrice,
                    label: label,
                    controller: controller,
                    required: true,
                    ltr: true,
                    keyboard: key == 'pack_size' ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
                    error: _errors[key],
                    enabled: !_saving,
                  ),
                ),
              ),
      ],
    );
  }
}
