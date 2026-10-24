import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/domain/product.dart';
import 'sale_widgets.dart';

/// What the weight sheet decided: a new weight, or «حذف من السلة» (edit mode only).
class WeightResult {
  const WeightResult.weight(Quantity this.quantity) : remove = false;
  const WeightResult.remove() : quantity = null, remove = true;

  final Quantity? quantity;
  final bool remove;
}

/// M-02 weight sheet for a kg product: an in-app keypad near the thumb, kg or g entry, gram
/// precision, and the price preview rounded like the server (doc 15 §4).
Future<WeightResult?> showWeightSheet(BuildContext context, Product product, {Quantity? current}) =>
    showSaleSheet<WeightResult>(context, builder: (_) => WeightSheet(product: product, current: current));

enum _Unit { kg, g }

class WeightSheet extends StatefulWidget {
  const WeightSheet({super.key, required this.product, this.current});

  final Product product;

  /// The line's weight when editing an existing line.
  final Quantity? current;

  @override
  State<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<WeightSheet> {
  _Unit _unit = _Unit.kg;
  late String _text = widget.current == null ? '' : widget.current!.format(ProductUnit.kg);
  String? _error;

  bool get _editing => widget.current != null;

  /// The entry in grams (thousandths of a kg).
  int get _milli {
    if (_text.isEmpty) return 0;
    if (_unit == _Unit.g) return int.tryParse(_text) ?? 0;
    final parts = _text.split('.');
    final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    final fraction = parts.length > 1 ? int.parse('${parts[1]}000'.substring(0, 3)) : 0;
    return whole * 1000 + fraction;
  }

  void _press(String key) {
    var v = _text;
    if (key == 'back') {
      if (v.isNotEmpty) v = v.substring(0, v.length - 1);
    } else if (key == '.') {
      if (_unit == _Unit.g || v.contains('.')) return;
      v = v.isEmpty ? '0.' : '$v.';
    } else if (_unit == _Unit.g) {
      if (v.length >= 6 || (v.isEmpty && key == '0')) return;
      v = '$v$key';
    } else {
      final parts = v.split('.');
      // A fourth decimal is refused at the keypad rather than shown as an error (hi-fi M-02).
      if (parts.length == 2 && parts[1].length >= 3) return;
      if (parts.length == 1 && (parts[0].length >= 3 || parts[0] == '0')) {
        if (parts[0] != '0') return;
        v = key;
      } else {
        v = '$v$key';
      }
    }
    HapticFeedback.selectionClick();
    setState(() {
      _text = v;
      _error = null;
    });
  }

  void _setUnit(_Unit unit) {
    if (unit == _unit) return;
    final milli = _milli;
    setState(() {
      _unit = unit;
      _text = milli == 0 ? '' : (unit == _Unit.g ? '$milli' : Quantity.milli(milli).format(ProductUnit.kg));
      _error = null;
    });
  }

  void _confirm(AppLocalizations t) {
    final milli = _milli;
    if (milli <= 0) {
      setState(() => _error = t.weightErrorZero);
      return;
    }
    if (milli > 999999) {
      setState(() => _error = t.weightErrorTooBig);
      return;
    }
    Navigator.of(context).pop(WeightResult.weight(Quantity.milli(milli)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final milli = _milli;
    final kg = Quantity.milli(milli).format(ProductUnit.kg);
    final price = lineTotal(widget.product.price, Quantity.milli(milli));
    final empty = milli <= 0;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: _editing ? t.weightTitleEdit : t.weightTitle,
            closeLabel: t.cancel,
            subtitle: Text.rich(
              TextSpan(
                text: '${widget.product.name} · ',
                children: [
                  TextSpan(
                    text: shekel(widget.product.price),
                    style: const TextStyle(color: HisbahColors.ink, fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ' ${t.perKg}'),
                ],
              ),
              style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: HisbahColors.segmentTrack, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                for (final unit in _Unit.values)
                  Expanded(
                    child: _Segment(
                      label: unit == _Unit.kg ? t.unitKilogram : t.unitGram,
                      selected: _unit == unit,
                      onTap: () => _setUnit(unit),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: HisbahColors.raised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _error != null ? StatusTone.error.fg : HisbahColors.primary, width: 2),
              ),
              child: Column(
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Num(
                          _text.isEmpty ? (_unit == _Unit.g ? '0' : '0.000') : _text,
                          size: 36,
                          weight: FontWeight.w700,
                          color: _text.isEmpty ? HisbahColors.borderStrong : HisbahColors.ink,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _unit == _Unit.g ? t.gramShort : t.kgShort,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: HisbahColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: '${t.priceWord} ',
                      children: [
                        TextSpan(
                          text: shekel(price),
                          style: const TextStyle(color: HisbahColors.ink, fontWeight: FontWeight.w700),
                        ),
                        if (milli > 0 && _unit == _Unit.g)
                          TextSpan(text: '  ${t.gramsEquals(kg)}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_error != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.error.fg),
                const SizedBox(width: 6),
                Text(_error!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StatusTone.error.fg)),
              ],
            )
          else
            Text(
              _unit == _Unit.g ? t.weightHintGram : t.weightHintKg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
            ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.4,
              children: [
                for (final key in keys)
                  _Key(
                    keyLabel: key,
                    semantic: key == 'back' ? t.keyBackspace : (key == '.' ? t.keyDecimal : key),
                    disabled: key == '.' && (_unit == _Unit.g || _text.contains('.')),
                    onTap: () => _press(key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const Key('weight.confirm'),
            onPressed: empty ? null : () => _confirm(t),
            child: BusyLabel(
              busy: false,
              label: empty ? t.weightCtaEmpty : (_editing ? t.weightCtaUpdate(kg) : t.weightCtaAdd(kg)),
              amount: empty ? null : shekel(price),
            ),
          ),
          if (_editing)
            TextButton(
              onPressed: () => Navigator.of(context).pop(const WeightResult.remove()),
              style: TextButton.styleFrom(foregroundColor: HisbahColors.dangerSolid, minimumSize: const Size.fromHeight(44)),
              child: Text(t.removeFromCart, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? HisbahColors.raised : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? const [BoxShadow(color: Color(0x2614262E), blurRadius: 2, offset: Offset(0, 1))] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      ),
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.keyLabel, required this.semantic, required this.disabled, required this.onTap});

  final String keyLabel;
  final String semantic;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: disabled ? .35 : 1,
    child: Semantics(
      button: true,
      label: semantic,
      enabled: !disabled,
      child: Material(
        color: HisbahColors.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: HisbahColors.border),
        ),
        child: InkWell(
          key: Key('key.$keyLabel'),
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onTap,
          child: Center(
            child: keyLabel == 'back'
                ? const Icon(Icons.backspace_outlined, size: 22, color: HisbahColors.ink)
                : ExcludeSemantics(child: Num(keyLabel, size: 22, weight: FontWeight.w600)),
          ),
        ),
      ),
    ),
  );
}
