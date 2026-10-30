import 'package:flutter/material.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/domain/product.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/goods.dart';

/// What the item page opens with: a scan fills what it can, a known product fills the rest.
class GoodsItemSeed {
  const GoodsItemSeed({this.product, this.barcode, this.name, this.kind});

  final Product? product;
  final String? barcode;
  final String? name;
  final GoodsKind? kind;
}

/// One item of the delivery, on its own page after the camera closes: carton or weight, how many,
/// and the selling price. Pops the finished [GoodsLine].
class GoodsItemScreen extends StatefulWidget {
  const GoodsItemScreen({super.key, this.seed = const GoodsItemSeed(), this.line});

  final GoodsItemSeed seed;

  /// The line being edited, when it was tapped in the list.
  final GoodsLine? line;

  @override
  State<GoodsItemScreen> createState() => _GoodsItemScreenState();
}

class _GoodsItemScreenState extends State<GoodsItemScreen> {
  late final _name = TextEditingController(text: widget.line?.name ?? widget.seed.product?.name ?? widget.seed.name);
  late final _cartons = TextEditingController(text: _lineCartons);
  late final _packSize = TextEditingController(text: _startingPackSize);
  late final _kilos = TextEditingController(text: _lineKilos);
  late final _sell = TextEditingController(text: widget.line?.sellingPrice ?? widget.seed.product?.sellingPrice);
  late GoodsKind _kind = widget.line?.kind ?? widget.seed.kind ?? _productKind;
  Map<String, String> _errors = const {};

  String get _lineCartons => widget.line != null && !widget.line!.isWeighed ? '${widget.line!.cartons}' : '';

  String get _lineKilos => widget.line?.isWeighed ?? false ? widget.line!.kilos.format(ProductUnit.kg) : '';

  String get _startingPackSize {
    final line = widget.line;
    if (line != null && !line.isWeighed) return '${line.packSize}';
    final size = widget.seed.product?.packSize;
    return size == null ? '' : '$size';
  }

  GoodsKind get _productKind => (widget.seed.product?.isWeighed ?? false) ? GoodsKind.weight : GoodsKind.carton;

  /// A known product keeps its unit: it was sold that way, and its stock is counted in it.
  bool get _kindLocked => widget.seed.product != null || (widget.line?.productId != null);

  String? get _barcode => widget.line?.barcode ?? widget.seed.barcode ?? widget.seed.product?.barcode;

  bool get _named => widget.seed.product != null || widget.line?.productId != null;

  @override
  void dispose() {
    for (final c in [_name, _cartons, _packSize, _kilos, _sell]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setKind(GoodsKind kind) => setState(() {
    _kind = kind;
    _errors = const {};
  });

  int? _whole(TextEditingController c) {
    final value = int.tryParse(c.text.trim());
    return value == null || value < 1 ? null : value;
  }

  Quantity? _kg() {
    try {
      final value = Quantity.parse(_kilos.text.trim());
      return value.milli > 0 ? value : null;
    } on FormatException {
      return null;
    }
  }

  Money? _price() {
    try {
      final value = Money.parse(_sell.text.trim());
      return value.isPositive ? value : null;
    } on FormatException {
      return null;
    }
  }

  void _save(AppLocalizations t) {
    final weighed = _kind == GoodsKind.weight;
    final errors = <String, String>{
      if (_name.text.trim().isEmpty) 'name': t.formNameRequired,
      if (!weighed && _whole(_cartons) == null) 'cartons': t.goodsNumberRequired,
      if (!weighed && _whole(_packSize) == null) 'pack': t.goodsNumberRequired,
      if (weighed && _kg() == null) 'kilos': t.goodsNumberRequired,
      if (_price() == null) 'sell': t.formPriceInvalid,
    };
    if (errors.isNotEmpty) return setState(() => _errors = errors);

    Navigator.of(context).pop(
      GoodsLine(
        productId: widget.line?.productId ?? widget.seed.product?.id,
        name: _name.text.trim(),
        // A weighed item has no barcode.
        barcode: weighed ? null : _barcode,
        kind: _kind,
        cartons: weighed ? 0 : _whole(_cartons)!,
        packSize: weighed ? 1 : _whole(_packSize)!,
        kilos: weighed ? _kg()! : Quantity.zero,
        sellingPrice: _price()!.toApi(),
        buyPrice: widget.line?.buyPrice,
      ),
    );
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    bool number = false,
    bool decimal = false,
    bool enabled = true,
  }) => GoodsField(
    fieldKey: Key('goodsItem.$key'),
    label: label,
    controller: controller,
    error: _errors[key],
    number: number,
    decimal: decimal,
    enabled: enabled,
    onChanged: () => setState(() {}),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final weighed = _kind == GoodsKind.weight;
    final cartons = _whole(_cartons);
    final size = _whole(_packSize);
    final barcode = _barcode;

    return Scaffold(
      appBar: AppBar(title: Text(widget.line == null ? t.formNewTitle : t.goodsItemEdit)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  if (barcode != null && !weighed) ...[
                    Container(
                      key: const Key('goodsItem.scanned'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: StatusTone.success.bg, borderRadius: BorderRadius.circular(HisbahRadius.field)),
                      child: Row(
                        children: [
                          Icon(Icons.check_rounded, size: 20, color: StatusTone.success.fg),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(t.goodsScanned, style: TextStyle(color: StatusTone.success.fg, fontWeight: FontWeight.w600)),
                          ),
                          Text(formatBarcode(barcode), textDirection: TextDirection.ltr, style: TextStyle(color: StatusTone.success.fg)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!_kindLocked) ...[
                    OptionRow(
                      children: [
                        for (final (kind, label) in [(GoodsKind.carton, t.goodsKindCarton), (GoodsKind.weight, t.goodsKindWeight)])
                          OptionButton(
                            key: Key('goodsItem.kind.${kind.name}'),
                            label: label,
                            selected: _kind == kind,
                            solid: true,
                            height: 48,
                            fontSize: 16,
                            onTap: () => _setKind(kind),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  _field('name', t.goodsName, _name, enabled: !_named),
                  const SizedBox(height: 14),
                  if (weighed)
                    _field('kilos', t.goodsKilos, _kilos, number: true, decimal: true)
                  else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _field('cartons', t.goodsCartons, _cartons, number: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _field('pack', t.goodsPackSize, _packSize, number: true)),
                      ],
                    ),
                    if (cartons != null && size != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('goodsItem.pieces'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: HisbahColors.primaryTint,
                          borderRadius: BorderRadius.circular(HisbahRadius.field),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(t.goodsQuantity, style: const TextStyle(color: HisbahColors.primary)),
                            Text(
                              t.goodsPieces('${cartons * size}'),
                              style: const TextStyle(color: HisbahColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  _field('sell', weighed ? t.goodsSellKilo : t.goodsSellPiece, _sell, number: true, decimal: true),
                ],
              ),
            ),
            ActionBar(
              child: FilledButton(
                key: const Key('goodsItem.save'),
                onPressed: () => _save(t),
                child: Text(widget.line == null ? t.goodsAddToList : t.goodsSaveLine),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A short label above the field: everything this flow asks for looks the same.
class GoodsField extends StatelessWidget {
  const GoodsField({
    super.key,
    required this.label,
    required this.controller,
    this.fieldKey,
    this.error,
    this.number = false,
    this.decimal = false,
    this.enabled = true,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final Key? fieldKey;
  final String? error;
  final bool number;
  final bool decimal;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        onChanged: (_) => onChanged?.call(),
        keyboardType: number ? TextInputType.numberWithOptions(decimal: decimal) : TextInputType.text,
        inputFormatters: number ? const [LatinDigitsFormatter()] : null,
        textDirection: number ? TextDirection.ltr : null,
        textAlign: number ? TextAlign.end : TextAlign.start,
        style: TextStyle(fontSize: number ? 19 : 17, fontWeight: number ? FontWeight.w600 : FontWeight.w400),
        decoration: InputDecoration(filled: true, fillColor: HisbahColors.raised, errorText: error),
      ),
    ],
  );
}
