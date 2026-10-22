import '../../../core/money/fixed_point.dart';
import '../../products/domain/product.dart';

/// One product in the cart. The price shown here is a preview: the server prices the sale from
/// its own database (US-0501 AC1), so the client never sends it.
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;

  /// Whole for piece products; grams precision for kg products.
  final Quantity quantity;

  Money get unitPrice => product.price;

  /// round_half_up(quantity × unit price, 2), the same rule as the server.
  Money get total => lineTotal(unitPrice, quantity);

  /// D-27: selling more than the recorded stock is allowed; the UI only warns.
  bool get exceedsStock => quantity > product.currentStock;

  CartLine withQuantity(Quantity value) => CartLine(product: product, quantity: value);
}

/// Cart state for the POS (US-0505): one line per product, exact totals.
/// Immutable: every change returns a new cart, so Riverpod rebuilds only on real changes.
class Cart {
  const Cart([this.lines = const []]);

  static const empty = Cart();

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  Money get total => lines.fold(Money.zero, (sum, line) => sum + line.total);

  /// Lines whose quantity is above the recorded stock (NEGATIVE_STOCK preview).
  List<CartLine> get overStockLines => [
    for (final line in lines)
      if (line.exceedsStock) line,
  ];

  CartLine? lineFor(int productId) {
    for (final line in lines) {
      if (line.product.id == productId) return line;
    }
    return null;
  }

  /// A piece product: +1 on its line, or a new line of 1 (repeat scan +1, AC-02).
  Cart addPiece(Product product) {
    if (product.isWeighed) {
      throw ArgumentError.value(product.unit, 'product.unit', 'A kg product needs a weight; use setQuantity');
    }
    final existing = lineFor(product.id);
    return setQuantity(product, (existing?.quantity ?? Quantity.zero) + Quantity.one);
  }

  /// Sets a line to [quantity] (the weight sheet for kg, the stepper for pieces). Zero removes the line.
  /// A newer [product] snapshot replaces the old one (e.g. after a fresh lookup).
  Cart setQuantity(Product product, Quantity quantity) {
    if (quantity.isNegative) throw ArgumentError.value(quantity, 'quantity', 'must not be negative');
    if (!quantity.fits(product.unit)) {
      throw ArgumentError.value(quantity, 'quantity', 'a piece product needs a whole quantity');
    }
    if (quantity.isZero) return remove(product.id);

    final line = CartLine(product: product, quantity: quantity);
    final index = lines.indexWhere((l) => l.product.id == product.id);
    if (index < 0) return Cart([...lines, line]);
    return Cart([...lines]..[index] = line);
  }

  Cart remove(int productId) => Cart([
    for (final line in lines)
      if (line.product.id != productId) line,
  ]);

  /// `items` for POST /sales: product and quantity only, quantities as unit strings (doc 15 §4).
  List<Map<String, Object>> toSaleItems() => [
    for (final line in lines) {'product_id': line.product.id, 'quantity': line.quantity.format(line.product.unit)},
  ];
}
