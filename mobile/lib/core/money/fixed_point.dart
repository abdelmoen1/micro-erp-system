/// Exact money and quantities for the POS (D-09, CR-13 modified, doc 15 §4). No doubles:
/// money is whole agorot, a quantity is whole thousandths (1 g for kg, 0.001 piece unused).
/// The API carries both as strings: money `"12.50"`, quantity `"3"` (piece) or `"0.750"` (kg).
library;

/// How a product is sold. Prices are per unit.
enum ProductUnit {
  piece,
  kg;

  /// Unknown or missing values fall back to [piece], the API default.
  static ProductUnit fromApi(Object? value) => value == 'kg' ? kg : piece;

  String get apiValue => name;
}

/// An amount in ILS, held as whole agorot.
class Money implements Comparable<Money> {
  const Money.cents(this.cents);

  static const zero = Money.cents(0);

  /// Parses an API money string such as `"12.50"`, `"12.5"` or `"12"` (at most 2 decimals).
  factory Money.parse(String value) => Money.cents(_parseScaled(value, 2));

  final int cents;

  bool get isZero => cents == 0;
  bool get isNegative => cents < 0;
  bool get isPositive => cents > 0;

  Money operator +(Money other) => Money.cents(cents + other.cents);
  Money operator -(Money other) => Money.cents(cents - other.cents);

  /// API form, always 2 decimals: `"45.00"`.
  String toApi() => _formatScaled(cents, 2);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  bool operator >(Money other) => cents > other.cents;
  bool operator >=(Money other) => cents >= other.cents;
  bool operator <=(Money other) => cents <= other.cents;
  bool operator <(Money other) => cents < other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => toApi();
}

/// A stock or sale quantity, held as whole thousandths.
class Quantity implements Comparable<Quantity> {
  const Quantity.milli(this.milli);

  static const zero = Quantity.milli(0);
  static const one = Quantity.milli(1000);

  factory Quantity.whole(int pieces) => Quantity.milli(pieces * 1000);

  /// Parses `"3"`, `"0.750"`, `"2.5"` (at most 3 decimals). Also accepts a JSON number from
  /// servers older than the CR-13 contract change, which sent integers.
  factory Quantity.parse(Object value) => switch (value) {
    final int v => Quantity.whole(v),
    final num v => Quantity.milli((v * 1000).round()),
    final String v => Quantity.milli(_parseScaled(v, 3)),
    _ => throw FormatException('Invalid quantity', value),
  };

  final int milli;

  bool get isZero => milli == 0;
  bool get isNegative => milli < 0;
  bool get isPositive => milli > 0;
  bool get isWhole => milli % 1000 == 0;

  /// True when the quantity is valid for [unit]: pieces are whole; kg has gram precision.
  bool fits(ProductUnit unit) => unit == ProductUnit.kg || isWhole;

  Quantity operator +(Quantity other) => Quantity.milli(milli + other.milli);
  Quantity operator -(Quantity other) => Quantity.milli(milli - other.milli);

  /// API form in [unit]: `"3"` for pieces, `"0.750"` for kg.
  String format(ProductUnit unit) =>
      unit == ProductUnit.kg ? _formatScaled(milli, 3) : _formatScaled(milli, 3).replaceFirst(RegExp(r'\.0+$'), '');

  @override
  int compareTo(Quantity other) => milli.compareTo(other.milli);

  bool operator >(Quantity other) => milli > other.milli;
  bool operator >=(Quantity other) => milli >= other.milli;
  bool operator <=(Quantity other) => milli <= other.milli;
  bool operator <(Quantity other) => milli < other.milli;

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => _formatScaled(milli, 3);
}

/// Line total = round_half_up(quantity × unit price, 2), exactly as the server computes it
/// (SaleService / Money::times). 0.333 kg × 7.50 = 2.4975 → 2.50.
Money lineTotal(Money unitPrice, Quantity quantity) {
  final exact = BigInt.from(unitPrice.cents) * BigInt.from(quantity.milli); // agorot × 1000
  final thousand = BigInt.from(1000);
  final half = BigInt.from(500);
  final rounded = exact.isNegative ? -((-exact + half) ~/ thousand) : (exact + half) ~/ thousand;
  return Money.cents(rounded.toInt());
}

int _parseScaled(String raw, int scale) {
  final value = raw.trim();
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(value);
  if (match == null) throw FormatException('Invalid decimal', raw);

  final fraction = match.group(3) ?? '';
  if (fraction.length > scale) throw FormatException('More than $scale decimals', raw);

  final digits = int.parse(match.group(2)!) * _pow10(scale) + int.parse(fraction.padRight(scale, '0'));
  return match.group(1) == '-' ? -digits : digits;
}

String _formatScaled(int value, int scale) {
  final negative = value < 0;
  final abs = value.abs();
  final base = _pow10(scale);
  final whole = abs ~/ base;
  final fraction = (abs % base).toString().padLeft(scale, '0');
  return '${negative ? '-' : ''}$whole.$fraction';
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}
