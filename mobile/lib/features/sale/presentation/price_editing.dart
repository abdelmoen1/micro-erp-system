import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cart.dart';
import 'sale_widgets.dart';
import 'weight_sheet.dart';

/// One tap of − / + on a line's price: a whole shekel.
const priceStep = Money.cents(100);

/// «سعر القطعة / الكرتونة / الكيلو» for the unit this line sells.
String priceLabelOf(AppLocalizations t, CartLine line) =>
    line.pack ? t.priceOfPack : (line.product.isWeighed ? t.priceOfKg : t.priceOfPiece);

/// The line's price for this sale: − one shekel, the price (tap to type one), + one shekel
/// (2026-11-07). Teal once changed, orange when it goes below the cost price. Laid out
/// left-to-right like the quantity stepper, so − is always on the left.
class PriceStepper extends StatelessWidget {
  const PriceStepper({super.key, required this.line, required this.onChanged, this.compact = false, this.enabled = true});

  final CartLine line;

  /// The new price for this sale; the product's own price clears the change.
  final ValueChanged<Money> onChanged;

  /// The invoice uses a smaller stepper than the cart.
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final id = line.pack ? '${line.product.id}.pack' : '${line.product.id}';
    final price = line.unitPrice;
    final tone = line.belowCost ? StatusTone.warning : null;
    final edited = line.priceEdited;
    final border = tone?.fg ?? (edited ? HisbahColors.primary : HisbahColors.borderStrong);
    final fill = tone?.bg ?? (edited ? HisbahColors.primaryTint : HisbahColors.raised);
    final ink = tone?.fg ?? (edited ? HisbahColors.primary : HisbahColors.ink);
    final side = compact ? 40.0 : 44.0;
    final canLower = enabled && price > priceStep;

    Future<void> type() async {
      final picked = await showPriceSheet(context, line);
      if (picked != null) onChanged(picked);
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        height: side,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: HisbahColors.raised,
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PriceButton(
              key: Key('price.dec.$id'),
              label: t.priceDecrease(line.product.name),
              icon: Icons.remove_rounded,
              color: HisbahColors.ink,
              size: side,
              onTap: canLower ? () => onChanged(price - priceStep) : null,
            ),
            Semantics(
              button: true,
              label: t.priceType(line.product.name),
              value: shekel(price),
              excludeSemantics: true,
              child: Material(
                color: fill,
                child: InkWell(
                  key: Key('price.type.$id'),
                  onTap: enabled ? type : null,
                  child: Container(
                    constraints: BoxConstraints(minWidth: compact ? 60 : 68),
                    height: side,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      border: Border.symmetric(vertical: BorderSide(color: HisbahColors.border)),
                    ),
                    child: Num(shekel(price), key: Key('price.value.$id'), size: compact ? 15 : 16, weight: FontWeight.w700, color: ink),
                  ),
                ),
              ),
            ),
            _PriceButton(
              key: Key('price.inc.$id'),
              label: t.priceIncrease(line.product.name),
              icon: Icons.add_rounded,
              color: HisbahColors.primary,
              size: side,
              onTap: enabled ? () => onChanged(price + priceStep) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({super.key, required this.label, required this.icon, required this.color, required this.size, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, size: 18, color: onTap == null ? HisbahColors.disabledInk : color),
      ),
    ),
  );
}

/// Under a line whose price changed: «سعر معدّل · الأصلي ₪ 18» with «رجّع الأصلي», and the
/// below-cost warning. Nothing when the line is at its own price and above cost.
class PriceNotes extends StatelessWidget {
  const PriceNotes({super.key, required this.line, required this.onRestore, this.enabled = true});

  final CartLine line;
  final VoidCallback onRestore;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final id = line.pack ? '${line.product.id}.pack' : '${line.product.id}';
    final cost = line.unitCost;
    if (!line.priceEdited && !line.belowCost) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (line.belowCost && cost != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.warning.fg),
              const SizedBox(width: 4),
              Text(
                t.priceBelowCost(shekel(cost)),
                key: Key('price.belowCost.$id'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StatusTone.warning.fg),
              ),
            ],
          )
        else
          Text(
            t.priceEditedNote(shekel(line.listPrice)),
            key: Key('price.edited.$id'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HisbahColors.primary),
          ),
        if (line.priceEdited)
          TextButton(
            key: Key('price.restore.$id'),
            onPressed: enabled ? onRestore : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            child: Text(t.priceRestore),
          ),
      ],
    );
  }
}

/// Tapping the price: type an exact price for this sale with the in-app keypad. Returns the price
/// (the product's own price when «رجّع الأصلي» is pressed), or null when closed.
Future<Money?> showPriceSheet(BuildContext context, CartLine line) =>
    showSaleSheet<Money>(context, builder: (_) => PriceSheet(line: line));

class PriceSheet extends StatefulWidget {
  const PriceSheet({super.key, required this.line});

  final CartLine line;

  @override
  State<PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<PriceSheet> {
  late String _text = widget.line.unitPrice.toApi().replaceFirst(RegExp(r'\.00$'), '');
  String? _error;

  Money? get _value {
    final t = _text.endsWith('.') ? _text.substring(0, _text.length - 1) : _text;
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(t)) return null;
    return Money.parse(t);
  }

  void _press(String key) {
    var v = _text;
    if (key == 'back') {
      if (v.isNotEmpty) v = v.substring(0, v.length - 1);
    } else if (key == '.') {
      if (v.contains('.')) return;
      v = v.isEmpty ? '0.' : '$v.';
    } else {
      final parts = v.split('.');
      if (parts.length == 2 && parts[1].length >= 2) return;
      if (parts.length == 1 && parts[0].length >= 7) return;
      v = v == '0' ? key : '$v$key';
    }
    HapticFeedback.selectionClick();
    setState(() {
      _text = v;
      _error = null;
    });
  }

  void _nudge(int cents) {
    final next = Money.cents((_value ?? Money.zero).cents + cents);
    if (!next.isPositive) return;
    setState(() {
      _text = next.toApi().replaceFirst(RegExp(r'\.00$'), '');
      _error = null;
    });
  }

  void _confirm(AppLocalizations t) {
    final value = _value;
    if (value == null || !value.isPositive) {
      setState(() => _error = t.priceErrorZero);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final line = widget.line;
    final value = _value;
    final cost = line.unitCost;
    final ready = value != null && value.isPositive;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', 'back'];
    final nudges = [(-50, '−0.5'), (50, '+0.5'), (-500, '−5'), (500, '+5')];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: t.priceSheetTitle(line.product.name),
            closeLabel: t.cancel,
            subtitle: Text(
              [
                '${t.priceSheetOriginal(shekel(line.listPrice))} · ${priceLabelOf(t, line)}',
                if (cost != null) t.priceSheetCost(shekel(cost)),
              ].join(' · '),
              style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
            ),
          ),
          const SizedBox(height: 10),
          Text(t.priceSheetField, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: HisbahColors.raised,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _error != null ? StatusTone.error.fg : HisbahColors.primary, width: 2),
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('₪', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: HisbahColors.inkMuted)),
                    const SizedBox(width: 8),
                    Num(
                      _text.isEmpty ? '0' : _text,
                      key: const Key('price.sheet.value'),
                      size: 32,
                      weight: FontWeight.w700,
                      color: _text.isEmpty ? HisbahColors.borderStrong : HisbahColors.ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: StatusTone.error.fg)),
          ] else if (ready && cost != null && cost.isPositive && value < cost) ...[
            const SizedBox(height: 6),
            Text(t.priceBelowCost(shekel(cost)), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: StatusTone.warning.fg)),
          ],
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                for (final (cents, label) in nudges) ...[
                  if (cents != nudges.first.$1) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('price.nudge.$cents'),
                      onPressed: () => _nudge(cents),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: EdgeInsets.zero),
                      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: HisbahColors.primaryTint, borderRadius: BorderRadius.circular(12)),
            child: Text(
              t.priceSheetNote(shekel(line.listPrice)),
              style: const TextStyle(fontSize: 13, height: 1.6, color: HisbahColors.ink),
            ),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 2.6,
              children: [
                for (final key in keys)
                  SheetKey(
                    keyLabel: key,
                    semantic: key == 'back' ? t.keyBackspace : (key == '.' ? t.keyDecimal : key),
                    disabled: key == '.' && _text.contains('.'),
                    onTap: () => _press(key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('price.sheet.confirm'),
                  onPressed: ready ? () => _confirm(t) : null,
                  child: Text(ready ? t.priceSheetConfirm(shekel(value)) : t.priceErrorZero),
                ),
              ),
              if (line.priceEdited) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const Key('price.sheet.restore'),
                  onPressed: () => Navigator.of(context).pop(line.listPrice),
                  child: Text(t.priceRestore),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
