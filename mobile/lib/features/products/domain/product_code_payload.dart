import 'dart:convert';

import '../../../core/money/fixed_point.dart';

/// What a scanned QR code (or a 2D / 1D barcode) really says about a product (S3 · QR add).
///
/// Nothing is invented: a field is filled only when the code carries it in a form we can verify.
/// There is no external product database (S3-Spec «ما يُقرأ من الرمز»).
sealed class ProductCodePayload {
  const ProductCodePayload();
}

/// The parts of a product the code carried. [fromCode] names the filled fields for the UI chip.
final class ProductCodeData extends ProductCodePayload {
  const ProductCodeData({this.barcode, this.name, this.sellingPrice, this.unit});

  final String? barcode;
  final String? name;

  /// A 2-decimal money string, e.g. "45.00".
  final String? sellingPrice;
  final ProductUnit? unit;

  Set<String> get fromCode => {
    if (barcode != null) 'barcode',
    if (name != null) 'name',
    if (sellingPrice != null) 'selling_price',
    if (unit != null) 'unit',
  };
}

/// A code with no product data we recognise (a web link, free text, …). [raw] is shown, never used.
final class UnreadableCode extends ProductCodePayload {
  const UnreadableCode(this.raw);

  final String raw;
}

final _plainCode = RegExp(r'^[0-9A-Za-z.\-]{4,64}$');
final _gs1Element = RegExp(r'^(?:\(01\)|01)(\d{14})');
final _price = RegExp(r'^\d{1,8}(\.\d{1,2})?$');

/// Reads a decoded code. Order: JSON object → GS1 Digital Link → GS1 element string → plain code.
ProductCodePayload parseProductCode(String raw) {
  final text = raw.replaceAll('\u001d', '').trim();
  if (text.isEmpty) return UnreadableCode(raw);

  if (text.startsWith('{')) return _fromJson(text) ?? UnreadableCode(raw);

  final link = Uri.tryParse(text);
  if (link != null && (link.scheme == 'http' || link.scheme == 'https')) {
    final gtin = _gtinFromDigitalLink(link);
    return gtin == null ? UnreadableCode(raw) : ProductCodeData(barcode: gtin);
  }

  final element = _gs1Element.firstMatch(text);
  if (element != null && text.length >= 16) return ProductCodeData(barcode: _normaliseGtin(element.group(1)!));

  if (_plainCode.hasMatch(text)) return ProductCodeData(barcode: text);
  return UnreadableCode(raw);
}

ProductCodeData? _fromJson(String text) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;

  String? str(List<String> keys) {
    for (final key in keys) {
      final value = decoded is Map<String, dynamic> ? decoded[key] : null;
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value is num) return '$value';
    }
    return null;
  }

  final rawCode = str(['barcode', 'gtin', 'ean', 'code']);
  final barcode = rawCode != null && _plainCode.hasMatch(rawCode) ? _normaliseGtin(rawCode) : null;
  final rawName = str(['name', 'product', 'title']);
  final name = rawName != null && rawName.length <= 255 ? rawName : null;
  final rawPrice = str(['price', 'selling_price']);
  final price = rawPrice != null && _price.hasMatch(rawPrice) ? Money.parse(rawPrice).toApi() : null;
  final unit = switch (str(['unit'])?.toLowerCase()) {
    'kg' => ProductUnit.kg,
    'piece' => ProductUnit.piece,
    _ => null,
  };

  final data = ProductCodeData(barcode: barcode, name: name, sellingPrice: price, unit: unit);
  return data.fromCode.isEmpty ? null : data;
}

/// `https://id.gs1.org/01/06281007041235/10/LOT` → `6281007041235`.
String? _gtinFromDigitalLink(Uri link) {
  final segments = link.pathSegments;
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == '01' && RegExp(r'^\d{8,14}$').hasMatch(segments[i + 1])) {
      return _normaliseGtin(segments[i + 1]);
    }
  }
  return null;
}

/// A GTIN-14 padded with a leading zero is the EAN-13 printed on the pack.
String _normaliseGtin(String code) => code.length == 14 && code.startsWith('0') ? code.substring(1) : code;
