import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_code_payload.dart';
import 'inventory_scanner_screen.dart';

/// S3 · add a product: choose «scan» or «manual» (sheet), then the form. True when one was added.
Future<bool> showAddProduct(BuildContext context) async {
  final choice = await showSaleSheet<String>(context, builder: (_) => const _AddChoiceSheet());
  if (choice == null || !context.mounted) return false;
  if (choice == 'manual') return _openForm(context, null);
  return _scanAndOpen(context);
}

/// «scan»: the inventory scanner, whose camera stays on while a compact form opens over it.
Future<bool> _scanAndOpen(BuildContext context) => openInventoryScanner(context);

Future<bool> _openForm(BuildContext context, ProductCodePayload? payload) async {
  final added = await Navigator.of(
    context,
    rootNavigator: true,
  ).push<bool>(MaterialPageRoute(builder: (_) => ProductFormScreen(payload: payload)));
  return added ?? false;
}

class _AddChoiceSheet extends StatelessWidget {
  const _AddChoiceSheet();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget option(String key, IconData icon, String title, String sub) => LineCard(
      child: InkWell(
        key: Key('addProduct.$key'),
        onTap: () => Navigator.of(context).pop(key),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: HisbahColors.primaryTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: HisbahColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(sub, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: t.addTitle, closeLabel: t.cancel),
          const SizedBox(height: 12),
          option('scan', Icons.qr_code_scanner_rounded, t.addScan, t.addScanSub),
          const SizedBox(height: 10),
          option('manual', Icons.edit_outlined, t.addManual, t.addManualSub),
        ],
      ),
    );
  }
}

enum _Stage { checking, duplicate, form, saving, saved }

/// The form, prefilled only with what the code really carried; or «already exists» when the
/// barcode is in the store; or the saved state.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, required this.payload});

  /// Null for manual entry.
  final ProductCodePayload? payload;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _minimum = TextEditingController();
  final _packSize = TextEditingController();
  final _packPrice = TextEditingController();
  final _cartons = TextEditingController();
  final _loose = TextEditingController();

  /// By the carton unless the code or the shared catalog says it is weighed.
  StockEntry _entry = StockEntry.carton;

  ProductUnit get _unit => _entry.unit;

  bool get _byCarton => _entry == StockEntry.carton;

  /// In screen order: a failed check focuses the first field with an error, which also scrolls it
  /// into view above the keyboard.
  final _focus = {
    for (final key in const [
      'name',
      'barcode',
      'selling_price',
      'cost_price',
      'cartons',
      'pack_size',
      'loose',
      'pack_price',
      'current_stock',
      'minimum_stock',
    ])
      key: FocusNode(),
  };
  _Stage _stage = _Stage.form;
  Product? _existing;
  Product? _saved;
  bool _lookupFailed = false;
  bool _fromCatalog = false;
  String? _banner;
  Map<String, String> _errors = const {};

  /// The person typed or changed something: leaving asks first.
  bool _edited = false;

  ProductCodeData? get _data => widget.payload is ProductCodeData ? widget.payload as ProductCodeData : null;

  @override
  void initState() {
    super.initState();
    final data = _data;
    if (data != null) {
      _name.text = data.name ?? '';
      _barcode.text = data.barcode ?? '';
      _price.text = data.sellingPrice ?? '';
      _entry = StockEntry.of(data.unit ?? ProductUnit.piece);
      if (data.barcode != null) {
        _stage = _Stage.checking;
        _checkDuplicate(data.barcode!);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _price, _cost, _stock, _minimum, _packSize, _packPrice, _cartons, _loose]) {
      c.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Before the form: «already exists» when my store has this barcode; otherwise the shared
  /// catalog's name and unit (another store saved it) so only price, cost and stock are left.
  Future<void> _checkDuplicate(String barcode) async {
    try {
      final match = await ref.read(productRepositoryProvider).catalogLookup(barcode);
      if (!mounted) return;
      setState(() {
        _existing = match.product;
        if (match.product == null && match.inCatalog) {
          _fromCatalog = true;
          _name.text = match.catalogName!;
          if (match.catalogUnit != null) _entry = StockEntry.of(match.catalogUnit!);
        }
        _stage = match.product == null ? _Stage.form : _Stage.duplicate;
      });
    } on ApiFailure {
      // The server rejects a duplicate barcode on save anyway (422), so the form can go on.
      if (!mounted) return;
      setState(() {
        _lookupFailed = true;
        _stage = _Stage.form;
      });
    }
  }

  Map<String, String> _validate(AppLocalizations t) => productFormErrors(
    t,
    unit: _unit,
    name: _name.text,
    price: _price.text,
    cost: _cost.text,
    stock: _stock.text,
    minimum: _minimum.text,
    packSize: _packSize.text,
    packPrice: _packPrice.text,
    cartonEntry: _byCarton,
    cartons: _cartons.text,
    loose: _loose.text,
  );

  Future<void> _save(AppLocalizations t) async {
    final errors = _validate(t);
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return _focusFirstError();
    setState(() => _stage = _Stage.saving);
    try {
      final product = await ref
          .read(productRepositoryProvider)
          .create(
            NewProduct(
              name: _name.text,
              barcode: _barcode.text,
              unit: _unit,
              sellingPrice: _price.text,
              costPrice: _cost.text,
              // By the carton the server gets the pieces: cartons × per carton + extras.
              currentStock: _byCarton ? '${cartonPieces(_packSize.text, _cartons.text, _loose.text)}' : _stock.text,
              minimumStock: _minimum.text,
              packSize: _byCarton ? _packSize.text : null,
              packPrice: _byCarton ? _packPrice.text : null,
            ),
          );
      if (!mounted) return;
      setState(() {
        _saved = product;
        _stage = _Stage.saved;
      });
    } on ValidationFailed catch (failure) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.form;
        _errors = {
          for (final e in failure.fieldErrors.entries)
            if (e.value.isNotEmpty) (_byCarton && e.key == 'current_stock' ? 'cartons' : e.key): e.value.first,
        };
        if (_errors.isEmpty) _banner = failure.message ?? t.formFailed;
      });
      _focusFirstError();
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.form;
        _banner = switch (failure) {
          Forbidden() => t.formForbidden,
          NetworkFailure() => t.formNetwork,
          _ => failure.message ?? t.formFailed,
        };
      });
    }
  }

  void _setEntry(StockEntry entry) => setState(() {
    _entry = entry;
    _errors = const {};
    _edited = true;
  });

  void _focusFirstError() {
    for (final entry in _focus.entries) {
      if (_errors.containsKey(entry.key)) {
        // After the frame that shows the errors (and the fields of an opened carton section).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && entry.value.context != null) entry.value.requestFocus();
        });
        return;
      }
    }
  }

  Future<void> _scanNext() async {
    final navigator = Navigator.of(context);
    final raw = await scanProductCode(context);
    if (raw == null || !mounted) return;
    await navigator.pushReplacement(
      MaterialPageRoute<bool>(builder: (_) => ProductFormScreen(payload: parseProductCode(raw))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final guarded = _stage == _Stage.form && _edited;
    return PopScope(
      canPop: _stage != _Stage.saving && !guarded,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !guarded) return;
        final navigator = Navigator.of(context);
        if (await confirmDiscard(context)) navigator.pop(false);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_stage == _Stage.duplicate ? t.addExistsTitle : t.formNewTitle)),
        body: SafeArea(
          child: switch (_stage) {
            _Stage.checking => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t.addChecking, style: const TextStyle(color: HisbahColors.inkMuted)),
                const SizedBox(height: 12),
                const LoadingView.detail(padding: EdgeInsets.zero),
              ],
            ),
            _Stage.duplicate => _duplicate(t),
            _Stage.saved => _done(t),
            _ => _form(t),
          },
        ),
      ),
    );
  }

  Widget _duplicate(AppLocalizations t) {
    final product = _existing!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ToneCard(
          tone: StatusTone.info,
          icon: Icons.info_outline_rounded,
          title: t.addExistsBody(isolateLtr(product.barcode ?? '')),
        ),
        const SizedBox(height: 12),
        LineCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  key: const Key('addProduct.existing'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isolateLtr(formatShekel(product.sellingPrice))} / ${product.unit == ProductUnit.kg ? t.prodPerKg : t.prodPerPiece} · ${isolateLtr(product.currentStock.format(product.unit))}',
                  style: const TextStyle(color: HisbahColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _scanNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
          child: Text(t.addScanAnother),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(t.savedBack),
        ),
      ],
    );
  }

  Widget _done(AppLocalizations t) {
    final product = _saved!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: StatusTone.success.bg, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 40, color: StatusTone.success.fg),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t.savedTitle(product.name),
            key: const Key('addProduct.saved'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '${isolateLtr(formatShekel(product.sellingPrice))} / ${product.unit == ProductUnit.kg ? t.prodPerKg : t.prodPerPiece} · ${isolateLtr(product.currentStock.format(product.unit))}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: HisbahColors.inkMuted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _scanNext,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
            child: Text(t.savedScanNext),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(t.savedBack),
          ),
        ],
      ),
    );
  }

  (StatusTone, String)? _codeNote(AppLocalizations t) => productCodeNote(t, widget.payload);

  Widget _form(AppLocalizations t) {
    final saving = _stage == _Stage.saving;
    final fromCode = _data?.fromCode ?? const <String>{};
    final note = _codeNote(t);
    final raw = widget.payload is UnreadableCode ? (widget.payload as UnreadableCode).raw : null;
    final placeholders = {
      'barcode': t.phBarcode,
      'current_stock': t.phOpeningStock,
      'pack_size': t.phPackSize,
      'pack_price': t.phPackPrice,
    };

    Widget field(
      String key,
      String label,
      TextEditingController controller, {
      bool optional = false,
      bool number = false,
      bool whole = false,
      String? hint,
      String? helper,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(label: label, required: !optional, fromCode: fromCode.contains(key)),
          const SizedBox(height: 6),
          TextField(
            key: Key('form.$key'),
            controller: controller,
            focusNode: _focus[key],
            enabled: !saving,
            onChanged: (_) {
              if (!_edited) setState(() => _edited = true);
            },
            textInputAction: TextInputAction.next,
            keyboardType: !number
                ? TextInputType.text
                : whole
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: number || key == 'barcode' ? const [LatinDigitsFormatter()] : null,
            textDirection: number || key == 'barcode' ? TextDirection.ltr : null,
            textAlign: number || key == 'barcode' ? TextAlign.left : TextAlign.start,
            decoration: InputDecoration(
              // What the field is for sits inside it, not as a note under it; only errors go below.
              hintText: helper ?? hint ?? placeholders[key],
              hintMaxLines: 2,
              hintTextDirection: Directionality.of(context),
              errorText: _errors[key],
              errorMaxLines: 3,
              filled: true,
              fillColor: HisbahColors.raised,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              if (_banner != null) ...[
                ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _banner!, alert: true),
                const SizedBox(height: 12),
              ],
              if (note != null) ...[
                ToneCard(
                  tone: note.$1,
                  icon: Icons.qr_code_2_rounded,
                  title: note.$2,
                  children: [if (raw != null) LtrValue(raw.length > 120 ? '${raw.substring(0, 120)}…' : raw)],
                ),
                const SizedBox(height: 8),
              ],
              if (_fromCatalog) ...[
                ToneCard(
                  key: const Key('addProduct.fromCatalog'),
                  tone: StatusTone.success,
                  icon: Icons.inventory_2_outlined,
                  title: t.addFromCatalog,
                ),
                const SizedBox(height: 8),
              ],
              if (_lookupFailed) ...[
                ToneCard(tone: StatusTone.warning, icon: Icons.wifi_off_rounded, title: t.addLookupFailed),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              field('name', t.formName, _name, hint: t.formNameHint),
              field('barcode', t.formBarcode, _barcode, optional: true),
              Row(
                children: [
                  Text(t.formSoldBy, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  if (fromCode.contains('unit')) ...[const SizedBox(width: 6), FromCodeChip(label: t.addFromCode)],
                ],
              ),
              const SizedBox(height: 6),
              StockEntryChoice(value: _entry, onChanged: _setEntry, enabled: !saving),
              if (_errors['unit'] != null)
                Text(_errors['unit']!, style: TextStyle(color: StatusTone.error.fg, fontSize: 13)),
              const SizedBox(height: 12),
              field(
                'selling_price',
                _byCarton ? t.piecePriceLabel : t.formPrice,
                _price,
                number: true,
                helper: _unit == ProductUnit.kg ? t.formPriceHelpKg : t.formPriceHelpPiece,
              ),
              field('cost_price', t.formCost, _cost, optional: true, number: true, helper: t.formCostHelp),
              if (_byCarton)
                // The sum and the per-piece hint follow what is typed.
                ListenableBuilder(
                  listenable: Listenable.merge([_price, _packSize, _packPrice, _cartons, _loose]),
                  builder: (context, _) => CartonStockSection(
                    size: _packSize,
                    cartons: _cartons,
                    loose: _loose,
                    packPrice: _packPrice,
                    piecePrice: _price.text,
                    errors: _errors,
                    fieldBuilder: (key, label, controller, {optional = false, hint}) => field(
                      key,
                      label,
                      controller,
                      number: true,
                      whole: key != 'pack_price',
                      optional: optional,
                      hint: hint,
                    ),
                  ),
                )
              else
                field(
                  'current_stock',
                  t.invOpeningStock(_unit == ProductUnit.kg ? t.prodPerKg : t.prodPerPiece),
                  _stock,
                  number: true,
                  whole: _unit == ProductUnit.piece,
                ),
              field(
                'minimum_stock',
                t.formMin,
                _minimum,
                optional: true,
                number: true,
                whole: _unit == ProductUnit.piece,
                helper: t.formMinHelp,
              ),
            ],
          ),
        ),
        ActionBar(
          bottomInset: MediaQuery.paddingOf(context).bottom,
          child: FilledButton(
            key: const Key('form.save'),
            onPressed: saving ? null : () => _save(t),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
            child: saving
                ? BusyLabel(busy: true, label: t.formSaving)
                : Text(_banner == t.formNetwork ? t.payRetry : t.formSave),
          ),
        ),
      ],
    );
  }
}

/// The new-product rules the server applies, checked before sending (same Arabic messages on the
/// full form and the quick sheet over the scanner).
Map<String, String> productFormErrors(
  AppLocalizations t, {
  required ProductUnit unit,
  required String name,
  required String price,
  required String cost,
  required String stock,
  String minimum = '',
  bool pack = false,
  String packSize = '',
  String packPrice = '',
  bool cartonEntry = false,
  String cartons = '',
  String loose = '',
}) {
  final quantity = unit == ProductUnit.kg ? RegExp(r'^\d{1,7}(\.\d{1,3})?$') : RegExp(r'^\d{1,7}$');
  final money = RegExp(r'^\d{1,8}(\.\d{1,2})?$');
  final whole = RegExp(r'^\d{1,6}$');
  final stockMessage = unit == ProductUnit.kg ? t.formStockKg : t.formStockPiece;
  final size = int.tryParse(packSize.trim());
  final priceOk = money.hasMatch(price.trim());
  final packPriceOk = money.hasMatch(packPrice.trim()) && Money.parse(packPrice.trim()).isPositive;
  // Same carton rules as the server (App\Support\Pack): pieces only, 2+ per carton, dearer than a piece.
  final checkPack = (pack || cartonEntry) && unit == ProductUnit.piece;
  final extra = int.tryParse(loose.trim());
  return {
    if (name.trim().isEmpty) 'name': t.formNameRequired,
    if (!priceOk || !Money.parse(price.trim()).isPositive) 'selling_price': t.formPriceInvalid,
    if (cost.trim().isNotEmpty && !money.hasMatch(cost.trim())) 'cost_price': t.formPriceInvalid,
    // By the carton the stock is the worked-out sum, so the carton count and the extras are checked.
    if (cartonEntry && !whole.hasMatch(cartons.trim())) 'cartons': t.cartonsInvalid,
    if (cartonEntry && loose.trim().isNotEmpty && !whole.hasMatch(loose.trim())) 'loose': t.cartonsInvalid,
    if (cartonEntry && extra != null && size != null && size >= 2 && extra >= size) 'loose': t.looseTooMany(size),
    if (!cartonEntry && !quantity.hasMatch(stock.trim())) 'current_stock': stockMessage,
    if (minimum.trim().isNotEmpty && !quantity.hasMatch(minimum.trim())) 'minimum_stock': stockMessage,
    if (checkPack && (size == null || size < 2 || size > 10000 || !RegExp(r'^\d+$').hasMatch(packSize.trim())))
      'pack_size': t.packSizeInvalid,
    if (checkPack && !packPriceOk) 'pack_price': t.formPriceInvalid,
    if (checkPack && packPriceOk && priceOk && !(Money.parse(packPrice.trim()) > Money.parse(price.trim())))
      'pack_price': t.packPriceNotAbovePiece,
  };
}

/// «يُباع بالكرتونة أيضاً»: a switch that opens the carton's two fields, with one line saying what a
/// piece costs inside the carton (so a per-piece price typed as the carton price shows at once).
class PackSection extends StatelessWidget {
  const PackSection({
    super.key,
    required this.enabled,
    required this.open,
    required this.onOpen,
    required this.size,
    required this.price,
    required this.piecePrice,
    required this.errors,
    required this.fieldBuilder,
  });

  final bool enabled;
  final bool open;
  final ValueChanged<bool> onOpen;
  final TextEditingController size;
  final TextEditingController price;
  final String piecePrice;
  final Map<String, String> errors;

  /// Builds one labelled numeric field in the caller's style: (key, label, controller).
  final Widget Function(String key, String label, TextEditingController controller) fieldBuilder;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pieces = int.tryParse(size.text.trim());
    final cartonPrice = RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(price.text.trim())
        ? Money.parse(price.text.trim())
        : null;
    final perPiece = pieces != null && pieces >= 2 && cartonPrice != null && cartonPrice.isPositive
        ? Money.cents((cartonPrice.cents / pieces).round())
        : null;
    final piece = RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(piecePrice.trim()) ? Money.parse(piecePrice.trim()) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('form.pack'),
          contentPadding: EdgeInsets.zero,
          value: open,
          onChanged: enabled ? onOpen : null,
          title: Text(t.packToggle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(t.packToggleSub, style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
        ),
        if (open) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fieldBuilder('pack_size', t.packSizeLabel, size)),
              const SizedBox(width: 10),
              Expanded(child: fieldBuilder('pack_price', t.packPriceLabel, price)),
            ],
          ),
          if (perPiece != null && errors['pack_price'] == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                piece == null ? t.packPerPiece(shekel(perPiece)) : t.packPerPieceVs(shekel(perPiece), shekel(piece)),
                key: const Key('form.packHint'),
                style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
              ),
            ),
        ],
      ],
    );
  }
}

/// What a new product is sold by. The carton is the main way in: the shopkeeper counts cartons,
/// not loose pieces; a product without a carton is entered by the piece or by weight.
enum StockEntry {
  carton,
  piece,
  kg;

  ProductUnit get unit => this == kg ? ProductUnit.kg : ProductUnit.piece;

  static StockEntry of(ProductUnit unit) => unit == ProductUnit.kg ? kg : carton;
}

/// Pieces on hand from a carton count: cartons × pieces per carton + extra pieces of an opened
/// carton. Null while a field is not a valid whole number (the form shows why).
int? cartonPieces(String size, String cartons, String loose) {
  final perCarton = int.tryParse(size.trim());
  final count = int.tryParse(cartons.trim());
  final extra = loose.trim().isEmpty ? 0 : int.tryParse(loose.trim());
  if (perCarton == null || perCarton < 2 || count == null || count < 0 || extra == null || extra < 0) return null;
  return count * perCarton + extra;
}

/// «يُباع»: by the carton (first), by the piece, or by weight.
class StockEntryChoice extends StatelessWidget {
  const StockEntryChoice({super.key, required this.value, required this.onChanged, required this.enabled});

  final StockEntry value;
  final ValueChanged<StockEntry> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OptionRow(
      children: [
        for (final (entry, label) in [
          (StockEntry.carton, t.formByCarton),
          (StockEntry.piece, t.formByPiece),
          (StockEntry.kg, t.formByKg),
        ])
          OptionButton(
            key: Key('form.unit.${entry.name}'),
            label: label,
            selected: value == entry,
            onTap: enabled ? () => onChanged(entry) : null,
          ),
      ],
    );
  }
}

/// The carton way in: pieces per carton and cartons on hand, extra pieces of an opened carton, and
/// the carton's wholesale price. The stock in pieces is worked out and shown as the sum, so the
/// shopkeeper sees what will be saved before saving.
class CartonStockSection extends StatelessWidget {
  const CartonStockSection({
    super.key,
    required this.size,
    required this.cartons,
    required this.loose,
    required this.packPrice,
    required this.piecePrice,
    required this.errors,
    required this.fieldBuilder,
  });

  final TextEditingController size;
  final TextEditingController cartons;
  final TextEditingController loose;
  final TextEditingController packPrice;
  final String piecePrice;
  final Map<String, String> errors;

  /// One numeric field in the caller's style: (key, label, controller, optional?, hint).
  final Widget Function(String key, String label, TextEditingController controller, {bool optional, String? hint})
  fieldBuilder;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final total = cartonPieces(size.text, cartons.text, loose.text);
    final money = RegExp(r'^\d{1,8}(\.\d{1,2})?$');
    final pieces = int.tryParse(size.text.trim());
    final carton = money.hasMatch(packPrice.text.trim()) ? Money.parse(packPrice.text.trim()) : null;
    final perPiece = pieces != null && pieces >= 2 && carton != null && carton.isPositive
        ? Money.cents((carton.cents / pieces).round())
        : null;
    final piece = money.hasMatch(piecePrice.trim()) ? Money.parse(piecePrice.trim()) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: fieldBuilder('cartons', t.cartonsLabel, cartons, hint: t.cartonsHint)),
            const SizedBox(width: 10),
            Expanded(child: fieldBuilder('pack_size', t.packSizeLabel, size, hint: t.phPackSize)),
          ],
        ),
        fieldBuilder('loose', t.looseLabel, loose, optional: true, hint: t.looseHint),
        if (total != null && errors['loose'] == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              key: const Key('form.cartonTotal'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: HisbahColors.primaryTint, borderRadius: BorderRadius.circular(10)),
              child: Text(
                t.cartonTotal(total),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HisbahColors.primary),
              ),
            ),
          ),
        fieldBuilder('pack_price', t.cartonPriceLabel, packPrice, hint: t.phPackPrice),
        if (perPiece != null && errors['pack_price'] == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              piece == null ? t.packPerPiece(shekel(perPiece)) : t.packPerPieceVs(shekel(perPiece), shekel(piece)),
              key: const Key('form.packHint'),
              style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
            ),
          ),
      ],
    );
  }
}

/// What a scanned code gave: one sentence naming the filled fields, or why nothing was used.
(StatusTone, String)? productCodeNote(AppLocalizations t, ProductCodePayload? payload) {
  if (payload == null) return (StatusTone.info, t.addManualNote);
  if (payload is UnreadableCode) return (StatusTone.warning, t.addUnreadable);
  final filled = (payload as ProductCodeData).fromCode;
  if (filled.length == 1 && filled.contains('barcode')) return (StatusTone.info, t.addBarcodeOnly);
  final names = [
    if (filled.contains('name')) t.addFieldName,
    if (filled.contains('barcode')) t.addFieldBarcode,
    if (filled.contains('selling_price')) t.addFieldPrice,
    if (filled.contains('unit')) t.addFieldUnit,
  ];
  return (StatusTone.info, t.addReadFields(names.join('، ')));
}

/// «Discard what you typed?» before a back gesture or a close throws away an unsaved product.
/// True when the person chose to leave.
Future<bool> confirmDiscard(BuildContext context) async {
  final t = AppLocalizations.of(context);
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.discardTitle),
      content: Text(t.discardBody),
      actions: [
        TextButton(
          key: const Key('discard.keep'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.discardKeep),
        ),
        TextButton(
          key: const Key('discard.leave'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: StatusTone.error.fg),
          child: Text(t.discardConfirm),
        ),
      ],
    ),
  );
  return leave ?? false;
}

/// A field's label: «*» on the fields the server requires (read as «مطلوب»), «(اختياري)» on the
/// others, and the «from the code» chip when the scan filled it. Wraps on narrow screens.
class FieldLabel extends StatelessWidget {
  const FieldLabel({super.key, required this.label, this.required = false, this.fromCode = false});

  final String label;
  final bool required;
  final bool fromCode;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  semanticsLabel: ' ${t.formRequiredA11y}',
                  style: TextStyle(color: StatusTone.error.fg),
                ),
              if (!required)
                TextSpan(
                  text: '  (${t.formOptional})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: HisbahColors.inkMuted),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        if (fromCode) FromCodeChip(label: t.addFromCode),
      ],
    );
  }
}

class FromCodeChip extends StatelessWidget {
  const FromCodeChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(color: StatusTone.info.bg, borderRadius: BorderRadius.circular(999)),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: StatusTone.info.fg),
    ),
  );
}
