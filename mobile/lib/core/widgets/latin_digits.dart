import 'package:flutter/services.dart';

/// `٢٫٥٠` → `2.50`. Arabic keyboards type Arabic-Indic digits (٠-٩, and Persian ۰-۹ on some
/// phones) and the Arabic decimal separator `٫`; prices, quantities, phones and barcodes are read
/// with Western digits only, by the app and by the server.
String latinDigits(String text) {
  if (!text.codeUnits.any((c) => (c >= 0x0660 && c <= 0x066B) || (c >= 0x06F0 && c <= 0x06F9))) return text;
  return String.fromCharCodes(
    text.codeUnits.map((c) {
      if (c >= 0x0660 && c <= 0x0669) return 0x30 + c - 0x0660;
      if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + c - 0x06F0;
      if (c == 0x066B) return 0x2E; // ٫ Arabic decimal separator → .
      return c;
    }),
  );
}

/// Converts Arabic digits as they are typed, so `٥` shows as `5` instead of being refused (or
/// silently dropped by a digits-only filter). One character for one character: the cursor stays.
class LatinDigitsFormatter extends TextInputFormatter {
  const LatinDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = latinDigits(newValue.text);
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }
}
