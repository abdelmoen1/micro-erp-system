import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../more/presentation/more_widgets.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/add_product_flow.dart' show productFormErrors;
import '../../products/presentation/product_detail_screen.dart' show AdjustStockSheet, unitWord;
import '../../scanner/presentation/scan_sheets.dart' show BarcodeLine;
import '../application/cart_controller.dart';
import '../domain/cart.dart';
import 'cart_widgets.dart';
import 'sale_widgets.dart';

// Selling while the shop is still being counted: a code the store does not know yet becomes a
// product at the till (name, price, what is on the shelf), and a product whose shelf ran out is
// counted right there. Owners and managers only, as everywhere products and stock change.

/// Owners and managers add products and correct stock; an employee only sells.
bool canStockAtTill(WidgetRef ref) {
  final session = ref.read(sessionProvider);
  return session is SignedIn && session.user.canOverride;
}

/// «نفد المخزون»: what is left of [product] for this cart, in its unit; nothing when the shelf is empty.
ScanFeedback outOfStockFeedback(AppLocalizations t, Cart cart, Product product, {required bool canCount, bool pack = false}) {
  final room = cart.roomFor(product, pack: pack);
  return ScanFeedback(
    ScanFeedbackKind.outOfStock,
    productName: product.name,
    quantity: room.isPositive ? '${room.format(product.unit)} ${unitWord(t, product)}' : '',
    canCount: canCount,
  );
}

/// «جرد»: the count sheet over the till. Returns the product with its new stock, or null when the
/// count was left or the fresh product could not be read.
Future<Product?> countAtTill(BuildContext context, WidgetRef ref, Product product) async {
  final message = await showSaleSheet<String>(context, builder: (_) => AdjustStockSheet(product: product));
  if (message == null || !context.mounted) return null;
  showNote(context, message);
  try {
    return await ref.read(productRepositoryProvider).product(product.id);
  } on ApiFailure {
    return null;
  }
}

/// The till's stock rules for the cart tab and the camera over it: every way into the cart goes
/// through here, so neither sells below zero, and both offer «جرد» and the new-product sheet.
mixin TillActions<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// The one-message slot under the search row (or under the camera frame).
  void showFeedback(ScanFeedback? feedback, {bool flash = false});

  /// Highlights the line just changed.
  void markJust(int productId);

  /// The weight sheet for a kg product (it sets the line through [applyWeight]).
  Future<void> openWeight(Product product);

  /// Runs [sheet] while the screen behind it must stay still (the camera pauses there).
  Future<R> covered<R>(String reason, Future<R> Function() sheet) => sheet();

  Product? _outOfStock;
  bool _outOfStockPack = false;

  CartController get till => ref.read(cartControllerProvider.notifier);

  /// «نفد المخزون» for [product]: the cart is unchanged, «جرد» is offered to owners and managers.
  void showOutOfStock(Product product, {bool pack = false}) {
    _outOfStock = product;
    _outOfStockPack = pack;
    unawaited(HapticFeedback.mediumImpact());
    showFeedback(
      outOfStockFeedback(
        AppLocalizations.of(context),
        ref.read(cartControllerProvider),
        product,
        canCount: canStockAtTill(ref),
        pack: pack,
      ),
    );
  }

  /// One more of [product] from search, a new product or a fresh count: +1 piece, or the weight.
  Future<void> addToTill(Product product, {bool pack = false}) async {
    if (product.isWeighed) return openWeight(product);
    final change = pack ? till.addPack(product) : till.addProduct(product);
    if (change == CartChange.outOfStock) {
      showOutOfStock(product, pack: pack);
      return;
    }
    final line = ref.read(cartControllerProvider).lineFor(product.id, pack: pack)!;
    markJust(product.id);
    showFeedback(
      ScanFeedback(
        line.quantity > Quantity.one ? ScanFeedbackKind.updated : ScanFeedbackKind.added,
        productName: product.name,
        quantity: line.quantity.format(pack ? ProductUnit.piece : product.unit),
      ),
      flash: true,
    );
  }

  /// The stepper's «+» on a line.
  void increment(CartLine line) {
    final change = till.setQuantity(line.product, line.quantity + Quantity.one, pack: line.pack);
    if (change == CartChange.outOfStock) return showOutOfStock(line.product, pack: line.pack);
    markJust(line.product.id);
  }

  /// The weight sheet's answer. False when the weight is more than the shelf holds.
  bool applyWeight(Product product, Quantity quantity) {
    if (till.setQuantity(product, quantity) == CartChange.done) return true;
    showOutOfStock(product);
    return false;
  }

  /// «جرد» on the out-of-stock message: count the shelf, then the product goes in as asked.
  Future<void> countOutOfStock() async {
    final product = _outOfStock;
    if (product == null) return;
    final pack = _outOfStockPack;
    showFeedback(null);
    final fresh = await covered('count', () => countAtTill(context, ref, product));
    if (fresh == null || !mounted) return;
    await addToTill(fresh, pack: pack && fresh.hasPack);
  }

  /// A code the store does not know: owners and managers add it here and it goes straight into
  /// the cart; an employee (or a closed sheet) gets the «unknown code» message with search.
  Future<void> addUnknown(String code) async {
    if (!canStockAtTill(ref)) {
      showFeedback(ScanFeedback(ScanFeedbackKind.unknown, code: code));
      return;
    }
    showFeedback(null);
    final product = await covered('quickAdd', () => showQuickAddProduct(context, barcode: code));
    if (!mounted) return;
    if (product == null) {
      showFeedback(ScanFeedback(ScanFeedbackKind.unknown, code: code));
      return;
    }
    showNote(context, AppLocalizations.of(context).quickAddDone(product.name));
    await addToTill(product);
  }
}

/// A code the store does not know: add it as a product here and sell it. Returns the new product.
Future<Product?> showQuickAddProduct(BuildContext context, {required String barcode}) =>
    showSaleSheet<Product>(context, dismissible: false, builder: (_) => QuickAddProductSheet(barcode: barcode));

/// Name, how it is sold, the price, the cost (optional) and how many are on the shelf now. The
/// shelf count is the product's opening stock, so this is the shop's stock count, item by item.
class QuickAddProductSheet extends ConsumerStatefulWidget {
  const QuickAddProductSheet({super.key, required this.barcode});

  final String barcode;

  @override
  ConsumerState<QuickAddProductSheet> createState() => _QuickAddProductSheetState();
}

class _QuickAddProductSheetState extends ConsumerState<QuickAddProductSheet> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _shelf = TextEditingController();
  ProductUnit _unit = ProductUnit.piece;
  Map<String, String> _errors = const {};
  String? _banner;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  /// The shared catalog may know the code: its name and unit fill in, the price stays the shop's.
  Future<void> _prefill() async {
    try {
      final match = await ref.read(productRepositoryProvider).catalogLookup(widget.barcode);
      if (!mounted || !match.inCatalog || _name.text.isNotEmpty) return;
      setState(() {
        _name.text = match.catalogName!;
        _unit = match.catalogUnit ?? _unit;
      });
    } on ApiFailure {
      // Offline or unknown: the cashier types it.
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _shelf]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppLocalizations t) async {
    final errors = productFormErrors(
      t,
      unit: _unit,
      name: _name.text,
      price: _price.text,
      cost: _cost.text,
      stock: _shelf.text,
    );
    if (!errors.containsKey('current_stock') && !Quantity.parse(_shelf.text.trim()).isPositive) {
      errors['current_stock'] = t.quickAddShelfInvalid;
    }
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      final product = await ref
          .read(productRepositoryProvider)
          .create(
            NewProduct(
              name: _name.text,
              barcode: widget.barcode,
              unit: _unit,
              sellingPrice: _price.text,
              costPrice: _cost.text,
              currentStock: _shelf.text,
            ),
          );
      if (mounted) Navigator.of(context).pop(product);
    } on ValidationFailed catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = {
          for (final e in failure.fieldErrors.entries)
            if (e.value.isNotEmpty) e.key: e.value.first,
        };
        // The barcode is not a field here: a clash with another product shows on top.
        _banner = _errors.remove('barcode') ?? (_errors.isEmpty ? failure.message : null);
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
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
    final weighed = _unit == ProductUnit.kg;
    final money = const TextInputType.numberWithOptions(decimal: true);

    return FormSheet(
      header: SheetHeader(
        title: t.quickAddTitle,
        subtitle: BarcodeLine(barcode: widget.barcode),
        closeLabel: t.cancel,
        onClose: _saving ? null : () => Navigator.of(context).pop(),
      ),
      action: FilledButton(
        key: const Key('quickAdd.save'),
        onPressed: _saving ? null : () => _save(t),
        child: BusyLabel(busy: _saving, label: t.quickAddSave),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(t.quickAddBody, style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted)),
        ),
        if (_banner != null) ...[
          ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _banner!, alert: true),
          const SizedBox(height: 12),
        ],
        MoreField(
          fieldKey: 'quickAdd.name',
          label: t.formName,
          controller: _name,
          hint: t.formNameHint,
          required: true,
          error: _errors['name'],
          enabled: !_saving,
        ),
        GroupLabel(t.formSoldBy),
        const SizedBox(height: 8),
        OptionRow(
          children: [
            for (final (unit, label) in [(ProductUnit.piece, t.formByPiece), (ProductUnit.kg, t.formByKg)])
              OptionButton(
                key: Key('quickAdd.unit.${unit.name}'),
                label: label,
                selected: _unit == unit,
                onTap: _saving ? null : () => setState(() => _unit = unit),
              ),
          ],
        ),
        const SizedBox(height: 14),
        MoreField(
          fieldKey: 'quickAdd.price',
          label: t.formPrice,
          controller: _price,
          required: true,
          ltr: true,
          keyboard: money,
          helper: weighed ? t.formPriceHelpKg : t.formPriceHelpPiece,
          error: _errors['selling_price'],
          enabled: !_saving,
        ),
        MoreField(
          fieldKey: 'quickAdd.shelf',
          label: '${t.quickAddShelf} (${weighed ? t.prodPerKg : t.prodPerPiece})',
          controller: _shelf,
          required: true,
          ltr: true,
          keyboard: weighed ? money : TextInputType.number,
          hint: t.phOpeningStock,
          error: _errors['current_stock'],
          enabled: !_saving,
        ),
        MoreField(
          fieldKey: 'quickAdd.cost',
          label: t.formCost,
          controller: _cost,
          ltr: true,
          keyboard: money,
          helper: t.formCostHelp,
          error: _errors['cost_price'],
          enabled: !_saving,
          action: TextInputAction.done,
          onSubmitted: () => _save(t),
        ),
      ],
    );
  }
}
