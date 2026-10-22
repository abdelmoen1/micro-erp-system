import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_code_payload.dart';

/// S3 · add a product: choose «scan» or «manual» (sheet), then the form. True when one was added.
Future<bool> showAddProduct(BuildContext context) async {
  final choice = await showSaleSheet<String>(context, builder: (_) => const _AddChoiceSheet());
  if (choice == null || !context.mounted) return false;
  if (choice == 'manual') return _openForm(context, null);
  return _scanAndOpen(context);
}

Future<bool> _scanAndOpen(BuildContext context) async {
  final raw = await scanProductCode(context);
  if (raw == null || !context.mounted) return false;
  return _openForm(context, parseProductCode(raw));
}

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
  ProductUnit _unit = ProductUnit.piece;
  _Stage _stage = _Stage.form;
  Product? _existing;
  Product? _saved;
  bool _lookupFailed = false;
  String? _banner;
  Map<String, String> _errors = const {};

  ProductCodeData? get _data => widget.payload is ProductCodeData ? widget.payload as ProductCodeData : null;

  @override
  void initState() {
    super.initState();
    final data = _data;
    if (data != null) {
      _name.text = data.name ?? '';
      _barcode.text = data.barcode ?? '';
      _price.text = data.sellingPrice ?? '';
      _unit = data.unit ?? ProductUnit.piece;
      if (data.barcode != null) {
        _stage = _Stage.checking;
        _checkDuplicate(data.barcode!);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _barcode, _price, _cost, _stock, _minimum]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Duplicate detection before the form: an active product with this barcode already exists.
  Future<void> _checkDuplicate(String barcode) async {
    try {
      final found = await ref.read(productRepositoryProvider).lookupByBarcode(barcode);
      if (!mounted) return;
      setState(() {
        _existing = found;
        _stage = found == null ? _Stage.form : _Stage.duplicate;
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

  Map<String, String> _validate(AppLocalizations t) {
    final quantity = _unit == ProductUnit.kg ? RegExp(r'^\d{1,7}(\.\d{1,3})?$') : RegExp(r'^\d{1,7}$');
    final money = RegExp(r'^\d{1,8}(\.\d{1,2})?$');
    final stockMessage = _unit == ProductUnit.kg ? t.formStockKg : t.formStockPiece;
    return {
      if (_name.text.trim().isEmpty) 'name': t.formNameRequired,
      if (!money.hasMatch(_price.text.trim()) || !Money.parse(_price.text.trim()).isPositive)
        'selling_price': t.formPriceInvalid,
      if (_cost.text.trim().isNotEmpty && !money.hasMatch(_cost.text.trim())) 'cost_price': t.formPriceInvalid,
      if (!quantity.hasMatch(_stock.text.trim())) 'current_stock': stockMessage,
      if (_minimum.text.trim().isNotEmpty && !quantity.hasMatch(_minimum.text.trim())) 'minimum_stock': stockMessage,
    };
  }

  Future<void> _save(AppLocalizations t) async {
    final errors = _validate(t);
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
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
              currentStock: _stock.text,
              minimumStock: _minimum.text,
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
            if (e.value.isNotEmpty) e.key: e.value.first,
        };
        if (_errors.isEmpty) _banner = failure.message ?? t.formFailed;
      });
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
    return PopScope(
      canPop: _stage != _Stage.saving,
      child: Scaffold(
        appBar: AppBar(title: Text(_stage == _Stage.duplicate ? t.addExistsTitle : t.formNewTitle)),
        body: SafeArea(
          child: switch (_stage) {
            _Stage.checking => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [const LoadingView(), Text(t.addChecking)]),
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

  /// What the code gave: one sentence naming the filled fields, or why nothing was used.
  (StatusTone, String)? _codeNote(AppLocalizations t) {
    final payload = widget.payload;
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

  Widget _form(AppLocalizations t) {
    final saving = _stage == _Stage.saving;
    final fromCode = _data?.fromCode ?? const <String>{};
    final note = _codeNote(t);
    final raw = widget.payload is UnreadableCode ? (widget.payload as UnreadableCode).raw : null;

    Widget field(
      String key,
      String label,
      TextEditingController controller, {
      bool optional = false,
      bool number = false,
      String? hint,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              if (optional)
                Text('  (${t.formOptional})', style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
              if (fromCode.contains(key)) ...[const SizedBox(width: 6), _FromCodeChip(label: t.addFromCode)],
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            key: Key('form.$key'),
            controller: controller,
            enabled: !saving,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            textDirection: number || key == 'barcode' ? TextDirection.ltr : null,
            textAlign: number || key == 'barcode' ? TextAlign.left : TextAlign.start,
            decoration: InputDecoration(
              hintText: hint,
              errorText: _errors[key],
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
                  if (fromCode.contains('unit')) ...[const SizedBox(width: 6), _FromCodeChip(label: t.addFromCode)],
                ],
              ),
              const SizedBox(height: 6),
              OptionRow(
                children: [
                  OptionButton(
                    label: t.formByPiece,
                    selected: _unit == ProductUnit.piece,
                    onTap: saving ? null : () => setState(() => _unit = ProductUnit.piece),
                  ),
                  OptionButton(
                    label: t.formByKg,
                    selected: _unit == ProductUnit.kg,
                    onTap: saving ? null : () => setState(() => _unit = ProductUnit.kg),
                  ),
                ],
              ),
              if (_errors['unit'] != null)
                Text(_errors['unit']!, style: TextStyle(color: StatusTone.error.fg, fontSize: 13)),
              const SizedBox(height: 12),
              field('selling_price', t.formPrice, _price, number: true),
              field('cost_price', t.formCost, _cost, optional: true, number: true),
              field('current_stock', t.formStock, _stock, number: true),
              field('minimum_stock', t.formMin, _minimum, optional: true, number: true),
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

class _FromCodeChip extends StatelessWidget {
  const _FromCodeChip({required this.label});

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
