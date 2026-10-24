import 'package:flutter/material.dart';

/// `"13"` / `"13.5"` / `"1245.50"` → `₪ 13.00` / `₪ 13.50` / `₪ 1,245.50` (design-system §1).
/// Works on the API's decimal string; never goes through a double.
String formatShekel(String amount) {
  var value = amount.trim();
  final negative = value.startsWith('-');
  if (negative) value = value.substring(1);
  final dot = value.indexOf('.');
  final whole = dot < 0 ? value : value.substring(0, dot);
  var fraction = dot < 0 ? '' : value.substring(dot + 1);
  if (fraction.length < 2) fraction = fraction.padRight(2, '0');

  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  return '${negative ? '-' : ''}₪ ${grouped.isEmpty ? '0' : grouped}.$fraction';
}

/// Groups retail codes the way they are printed under the bars: EAN-13 `6 221007 012345`,
/// EAN-8 `1234 5670`. Anything else is shown as typed.
String formatBarcode(String code) {
  final isDigits = RegExp(r'^\d+$').hasMatch(code);
  if (isDigits && code.length == 13) return '${code[0]} ${code.substring(1, 7)} ${code.substring(7)}';
  if (isDigits && code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
  return code;
}

/// A value that is always an isolated LTR run inside Arabic text (money, barcodes):
/// one line, never wrapped; shrinks instead of clipping when the space is too small.
class LtrValue extends StatelessWidget {
  const LtrValue(this.text, {super.key, this.style, this.alignment = AlignmentDirectional.centerStart});

  final String text;
  final TextStyle? style;
  final AlignmentDirectional alignment;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: Text(
      text,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      softWrap: false,
      style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    ),
  );
}

/// [LtrValue] for an amount from the API (`"13.00"` → `₪ 13.00`).
class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style});

  final String amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => LtrValue(formatShekel(amount), style: style);
}

/// Wraps [text] in Unicode LTR isolate marks (LRI … PDI) for use inside an Arabic [TextSpan].
String isolateLtr(String text) => String.fromCharCode(0x2066) + text + String.fromCharCode(0x2069);
