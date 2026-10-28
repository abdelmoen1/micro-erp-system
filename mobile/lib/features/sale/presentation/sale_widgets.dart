import 'package:flutter/material.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';

/// `₪ 1,245.50` for exact [Money] (design-system §1).
String shekel(Money amount) => formatShekel(amount.toApi());

/// `dd/MM/yyyy` (Western digits, UI-D1).
String dayMonthYear(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// `YYYY-MM-DD` from the API → `dd/MM/yyyy`.
String isoToDayMonthYear(String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : dayMonthYear(d);
}

const _numberStyle = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

/// Opens a sale-flow sheet (weight, picker, override, void): rounded top, scrim, keyboard-aware.
Future<T?> showSaleSheet<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) =>
    showModalBottomSheet<T>(
      context: context,
      // Over the whole screen, bottom navigation included (hi-fi M-02 · M-05 sheets).
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: HisbahColors.surface,
      barrierColor: HisbahColors.scrim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      // The keypad pushes the sheet up; otherwise its last button stays clear of the Android
      // navigation buttons (the sheet itself is drawn under them).
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SafeArea(top: false, child: builder(sheetContext)),
      ),
    );

/// Handle, title (optionally with a subtitle) and the round close button of every sheet.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle, required this.closeLabel, this.onClose});

  final String title;
  final Widget? subtitle;
  final String closeLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 40,
          height: 5,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: HisbahColors.sheetHandle, borderRadius: BorderRadius.circular(3)),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.4)),
                ),
                if (subtitle != null) ...[const SizedBox(height: 2), subtitle!],
              ],
            ),
          ),
          RoundIconButton(icon: Icons.close_rounded, label: closeLabel, onPressed: onClose ?? () => Navigator.of(context).pop()),
        ],
      ),
    ],
  );
}

/// 44 dp round ground-coloured icon button (sheet close).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: HisbahColors.ground,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 18, color: HisbahColors.ink)),
      ),
    ),
  );
}

/// A card that carries a status: an icon, a bold title and its explanation (warning, restriction,
/// submit outcome). Colour is never the only carrier.
class ToneCard extends StatelessWidget {
  const ToneCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.children = const [],
    this.alert = false,
    this.strongBorder = false,
  });

  final StatusTone tone;
  final IconData icon;
  final String title;
  final List<Widget> children;

  /// A restriction or an error (announced at once) rather than a note.
  final bool alert;
  final bool strongBorder;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: alert,
    container: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.line, width: strongBorder ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: tone.fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: tone.fg, height: 1.45)),
              ),
            ],
          ),
          for (final child in children) ...[const SizedBox(height: 8), child],
        ],
      ),
    ),
  );
}

/// Plain body text inside a [ToneCard] or a summary.
class BodyText extends StatelessWidget {
  const BodyText(this.text, {super.key, this.size = 14, this.color = HisbahColors.ink, this.weight = FontWeight.w400});

  final String text;
  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: size, height: 1.6, color: color, fontWeight: weight));
}

/// Label above a form group, with an optional note at the far end («اختياري» / «مطلوب»).
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.note, this.noteColor = HisbahColors.inkMuted});

  final String text;
  final String? note;
  final Color noteColor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
      if (note != null) Text(note!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: noteColor)),
    ],
  );
}

/// One option of a group (sale mode, payment method, due date, weight unit).
/// [solid]: the selected option fills with teal (sale mode); otherwise it gets a tint and a 2 dp
/// teal border.
class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.solid = false,
    this.height = 44,
    this.fontSize = 14,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? iconColor;
  final bool solid;
  final double height;
  final double fontSize;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? (solid ? HisbahColors.primary : HisbahColors.primaryTint) : HisbahColors.raised;
    final fg = selected && solid ? HisbahColors.onPrimary : HisbahColors.ink;
    final border = selected
        ? BorderSide(color: HisbahColors.primary, width: solid ? 1.5 : 2)
        : const BorderSide(color: HisbahColors.borderStrong, width: 1.5);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: border),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheck && selected) ...[
                  const Icon(Icons.check_rounded, size: 16, color: HisbahColors.primary),
                  const SizedBox(width: 6),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 16, color: selected && solid ? HisbahColors.onPrimary : iconColor ?? fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: fontSize, color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of [OptionButton]s with equal widths.
class OptionRow extends StatelessWidget {
  const OptionRow({super.key, required this.children, this.gap = 6});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: children[i]),
      ],
    ],
  );
}

/// The fixed bar at the bottom of a sale screen (cart total, confirm, new sale).
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.child, this.bottomInset = 0});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: HisbahColors.surface,
      boxShadow: [BoxShadow(color: HisbahColors.border, offset: Offset(0, -1))],
    ),
    child: Padding(padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomInset), child: child),
  );
}

/// Busy state of a primary button: a small ring before the label.
class BusyLabel extends StatelessWidget {
  const BusyLabel({super.key, required this.busy, required this.label, this.amount});

  final bool busy;
  final String label;
  final String? amount;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (busy) ...[
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: HisbahColors.disabledInk),
        ),
        const SizedBox(width: 8),
      ],
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      if (amount != null) ...[const SizedBox(width: 6), Text(amount!, textDirection: TextDirection.ltr, style: _numberStyle)],
    ],
  );
}

/// A number or money value isolated LTR inside Arabic text.
class Num extends StatelessWidget {
  const Num(this.text, {super.key, this.size = 14, this.weight = FontWeight.w600, this.color = HisbahColors.ink});

  final String text;
  final double size;
  final FontWeight weight;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textDirection: TextDirection.ltr,
    style: TextStyle(fontSize: size, fontWeight: weight, color: color).merge(_numberStyle),
  );
}

/// The avatar circle with a customer's initial.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.initial, {super.key, this.size = 44});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: HisbahColors.primaryTint, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(fontSize: size * 0.39, fontWeight: FontWeight.w700, color: HisbahColors.primary),
      ),
    ),
  );
}

/// White rounded card with the hairline border used for lists and summaries.
class LineCard extends StatelessWidget {
  const LineCard({super.key, required this.child, this.color = HisbahColors.surface, this.radius = 18});

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: HisbahColors.border),
      boxShadow: const [BoxShadow(color: HisbahColors.shadow, blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: child,
  );
}
