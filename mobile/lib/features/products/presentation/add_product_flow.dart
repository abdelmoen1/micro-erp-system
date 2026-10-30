import 'package:flutter/material.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';

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
  const FieldLabel({super.key, required this.label, this.required = false});

  final String label;
  final bool required;

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
      ],
    );
  }
}
