import '../../../core/money/fixed_point.dart';
import '../../products/domain/product.dart';

/// One product in the cart, in one unit: its own unit (piece / kg), or whole cartons ([pack]) at
/// the carton price. Pieces and cartons of one product are two lines. The price shown here is a
/// preview: the server prices the sale from its own database (US-0501 AC1), so the client never
/// sends it.
class CartLine {
  const CartLine({required this.product, required this.quantity, this.pack = false});

  final Product product;

  /// Whole for piece products and for cartons; grams precision for kg products.
  final Quantity quantity;

  /// Sold by the carton: [quantity] counts cartons of `product.packSize` pieces.
  final bool pack;

  /// Per carton for a carton line, per piece / kg otherwise; never mixed.
  Money get unitPrice => pack ? product.packMoney : product.price;

  /// round_half_up(quantity × unit price, 2), the same rule as the server.
  Money get total => lineTotal(unitPrice, quantity);

  /// What leaves the shelf, in the product's own unit (a carton of 24 is 24 pieces).
  Quantity get baseQuantity => pack ? Quantity.milli(quantity.milli * (product.packSize ?? 1)) : quantity;

  CartLine withQuantity(Quantity value) => CartLine(product: product, quantity: value, pack: pack);

  bool same(int productId, bool byPack) => product.id == productId && pack == byPack;
}

/// Cart state for the POS (US-0505): one line per product and unit, exact totals.
/// Immutable: every change returns a new cart, so Riverpod rebuilds only on real changes.
class Cart {
  const Cart([this.lines = const []]);

  static const empty = Cart();

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;

  Money get total => lines.fold(Money.zero, (sum, line) => sum + line.total);

  /// Pieces (or kg) of [productId] across its lines: cartons count with all their pieces.
  Quantity baseQuantityOf(int productId) =>
      lines.where((line) => line.product.id == productId).fold(Quantity.zero, (sum, line) => sum + line.baseQuantity);

  /// D-27: selling more than the recorded stock is allowed; the UI only warns. Counts every line of
  /// the product, so 2 cartons of 24 against 30 in stock are over it.
  bool exceedsStock(CartLine line) => baseQuantityOf(line.product.id) > line.product.currentStock;

  /// Lines whose product would go above the recorded stock (NEGATIVE_STOCK preview).
  List<CartLine> get overStockLines => [
    for (final line in lines)
      if (exceedsStock(line)) line,
  ];

  CartLine? lineFor(int productId, {bool pack = false}) {
    for (final line in lines) {
      if (line.same(productId, pack)) return line;
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

  /// +1 carton on the product's carton line, or a new carton line.
  Cart addPack(Product product) {
    if (!product.hasPack) throw ArgumentError.value(product.id, 'product', 'This product is not sold by the carton');
    final existing = lineFor(product.id, pack: true);
    return setQuantity(product, (existing?.quantity ?? Quantity.zero) + Quantity.one, pack: true);
  }

  /// Sets a line to [quantity] (the weight sheet for kg, the stepper for pieces and cartons). Zero
  /// removes the line. A newer [product] snapshot replaces the old one (e.g. after a fresh lookup).
  Cart setQuantity(Product product, Quantity quantity, {bool pack = false}) {
    if (quantity.isNegative) throw ArgumentError.value(quantity, 'quantity', 'must not be negative');
    if (pack && !product.hasPack) {
      throw ArgumentError.value(product.id, 'product', 'This product is not sold by the carton');
    }
    if (!quantity.fits(pack ? ProductUnit.piece : product.unit)) {
      throw ArgumentError.value(quantity, 'quantity', 'pieces and cartons need a whole quantity');
    }
    if (quantity.isZero) return remove(product.id, pack: pack);

    final line = CartLine(product: product, quantity: quantity, pack: pack);
    final index = lines.indexWhere((l) => l.same(product.id, pack));
    if (index < 0) return Cart([...lines, line]);
    return Cart([...lines]..[index] = line);
  }

  Cart remove(int productId, {bool pack = false}) => Cart([
    for (final line in lines)
      if (!line.same(productId, pack)) line,
  ]);

  /// `items` for POST /sales: product, quantity and, for cartons, `sale_unit: pack` (doc 15 §4).
  List<Map<String, Object>> toSaleItems() => [
    for (final line in lines)
      {
        'product_id': line.product.id,
        'quantity': line.quantity.format(line.pack ? ProductUnit.piece : line.product.unit),
        if (line.pack) 'sale_unit': 'pack',
      },
  ];
}
