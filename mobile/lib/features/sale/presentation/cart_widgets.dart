import 'package:flutter/material.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cart.dart';
import 'product_search_sheet.dart';
import 'sale_widgets.dart';

// Shared by the cart tab (M-02) and the cart panel over the sale scanner: one cart line with its
// stepper or weight button, and the one-message scan feedback slot.

/// The scan feedback slot: one message at a time, the newest replaces the older (hi-fi M-02).
enum ScanFeedbackKind { loading, added, updated, weighedAdded, duplicate, unknown, networkError }

class ScanFeedback {
  const ScanFeedback(this.kind, {this.code = '', this.productName = '', this.quantity = ''});

  final ScanFeedbackKind kind;
  final String code;
  final String productName;
  final String quantity;
}

class ScanFeedbackCard extends StatelessWidget {
  const ScanFeedbackCard({super.key, required this.feedback, this.onAction});

  final ScanFeedback feedback;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (tone, icon, title, text, action) = switch (feedback.kind) {
      ScanFeedbackKind.loading => (StatusTone.neutral, Icons.schedule_rounded, t.scanLookingUp, t.barcodeWord, null),
      ScanFeedbackKind.added => (StatusTone.success, Icons.check_rounded, t.scanAdded, feedback.productName, null),
      ScanFeedbackKind.updated => (
        StatusTone.success,
        Icons.check_rounded,
        t.scanIncremented(feedback.productName),
        t.scanQuantityNow(feedback.quantity),
        null,
      ),
      ScanFeedbackKind.weighedAdded => (
        StatusTone.success,
        Icons.check_rounded,
        t.scanAddedWeighed,
        feedback.productName,
        null,
      ),
      ScanFeedbackKind.duplicate => (
        StatusTone.neutral,
        Icons.repeat_rounded,
        t.scanDuplicate,
        t.scanDuplicateBody,
        null,
      ),
      ScanFeedbackKind.unknown => (
        StatusTone.error,
        Icons.warning_amber_rounded,
        t.scanUnknown,
        t.scanUnknownBody,
        t.searchByName,
      ),
      ScanFeedbackKind.networkError => (
        StatusTone.error,
        Icons.wifi_off_rounded,
        t.scanLookupFailed,
        t.scanLookupFailedBody,
        t.retry,
      ),
    };
    final showCode = feedback.kind == ScanFeedbackKind.unknown || feedback.kind == ScanFeedbackKind.loading;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: Key('cart.feedback.${feedback.kind.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tone.fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tone.fg, height: 1.45),
                  ),
                  Wrap(
                    spacing: 4,
                    children: [
                      Text(text, style: const TextStyle(fontSize: 13, height: 1.5, color: HisbahColors.ink)),
                      if (showCode && feedback.code.isNotEmpty) Num(feedback.code, size: 13),
                    ],
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: HisbahColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CartLineRow extends StatelessWidget {
  const CartLineRow({
    super.key,
    required this.line,
    required this.divider,
    required this.justAdded,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditWeight,
    required this.onRemove,
    this.overStock = false,
    this.onAddPack,
  });

  final CartLine line;

  /// The product's lines together (cartons with all their pieces) go above the recorded stock.
  final bool overStock;

  /// «+ كرتونة» on a piece line of a product that is also sold by the carton.
  final VoidCallback? onAddPack;
  final bool divider;
  final bool justAdded;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditWeight;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final product = line.product;
    final kg = product.isWeighed;
    final pack = line.pack;
    final qty = line.quantity.format(pack ? ProductUnit.piece : product.unit);
    // Keys of the carton line carry «.pack», so the piece and carton lines of one product differ.
    final id = pack ? '${product.id}.pack' : '${product.id}';
    final justText = kg ? t.justAddedWeighed : (line.quantity > Quantity.one ? t.justIncremented : t.justNew);
    final unitText = kg ? t.kgShort : (pack ? t.packPer(product.packSize!) : t.pieceWord);

    return Container(
      color: justAdded ? HisbahColors.highlightRow : HisbahColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider ? const Border(top: BorderSide(color: HisbahColors.border)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      UnitChip(
                        label: kg ? t.unitChipWeighed : (pack ? t.unitChipPack(product.packSize!) : t.unitChipPiece),
                      ),
                      if (justAdded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: HisbahColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            justText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: HisbahColors.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Num(shekel(line.total), size: 17, weight: FontWeight.w700),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: shekel(line.unitPrice)),
                            TextSpan(text: ' / $unitText'),
                          ],
                        ),
                        style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                      ),
                      if (pack)
                        Text(
                          t.packEquals(line.baseQuantity.format(ProductUnit.piece)),
                          key: Key('cart.base.$id'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HisbahColors.ink),
                        ),
                      if (product.barcode != null)
                        Num(product.barcode!, size: 12, weight: FontWeight.w400, color: HisbahColors.inkSubtle),
                    ],
                  ),
                ),
                if (kg)
                  Row(
                    children: [
                      _BoxButton(
                        key: Key('cart.edit.${product.id}'),
                        label: t.editWeightOf(product.name),
                        onTap: onEditWeight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Num(qty, size: 17, weight: FontWeight.w700),
                            const SizedBox(width: 4),
                            Text(t.kgShort, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 16, color: HisbahColors.primary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _BoxButton(
                        label: t.removeItem(product.name),
                        onTap: onRemove,
                        width: 48,
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: HisbahColors.dangerSolid),
                      ),
                    ],
                  )
                else
                  _Stepper(
                    keyId: id,
                    quantity: qty,
                    isLast: line.quantity <= Quantity.one,
                    decLabel: line.quantity <= Quantity.one ? t.removeItem(product.name) : t.decreaseItem(product.name),
                    incLabel: t.increaseItem(product.name),
                    onDecrement: onDecrement,
                    onIncrement: onIncrement,
                  ),
              ],
            ),
            if (onAddPack != null && !pack && product.hasPack) ...[
              const SizedBox(height: 6),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: Key('cart.addPack.${product.id}'),
                  onPressed: onAddPack,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text(t.addPackLine(product.packSize!, shekel(product.packMoney))),
                ),
              ),
            ],
            if (overStock) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: StatusTone.warning.bg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.warning.fg),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.lineStockNote(product.currentStock.format(product.unit)),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: StatusTone.warning.fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.keyId,
    required this.quantity,
    required this.isLast,
    required this.decLabel,
    required this.incLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String keyId;
  final String quantity;
  final bool isLast;
  final String decLabel;
  final String incLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HisbahColors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HisbahColors.borderStrong, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            key: Key('cart.dec.$keyId'),
            label: decLabel,
            icon: isLast ? Icons.delete_outline_rounded : Icons.remove_rounded,
            color: isLast ? HisbahColors.dangerSolid : HisbahColors.ink,
            onTap: onDecrement,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: HisbahColors.border)),
            ),
            child: Num(quantity, key: Key('cart.qty.$keyId'), size: 17, weight: FontWeight.w700),
          ),
          _StepButton(
            key: Key('cart.inc.$keyId'),
            label: incLabel,
            icon: Icons.add_rounded,
            color: HisbahColors.primary,
            onTap: onIncrement,
          ),
        ],
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 18, color: color)),
    ),
  );
}

class _BoxButton extends StatelessWidget {
  const _BoxButton({super.key, required this.label, required this.onTap, required this.child, this.width});

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: HisbahColors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HisbahColors.borderStrong, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          width: width,
          padding: width == null ? const EdgeInsets.symmetric(horizontal: 12) : null,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  );
}
