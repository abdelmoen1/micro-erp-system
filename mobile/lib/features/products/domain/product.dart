import '../../../core/money/fixed_point.dart';

/// A product as returned by the v1 product endpoints (docs/api/products.http, US-0401).
/// Money stays a decimal string exactly as the API sends it (never a double).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.barcode,
    required this.sellingPrice,
    required this.costPrice,
    required this.currentStock,
    required this.minimumStock,
    required this.isLowStock,
    required this.isActive,
    this.unit = ProductUnit.piece,
    this.packSize,
    this.packPrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    barcode: json['barcode'] as String?,
    unit: ProductUnit.fromApi(json['unit']),
    sellingPrice: json['selling_price'] as String? ?? '0.00',
    costPrice: json['cost_price'] as String?,
    currentStock: Quantity.parse(json['current_stock'] ?? 0),
    minimumStock: Quantity.parse(json['minimum_stock'] ?? 5),
    isLowStock: json['is_low_stock'] as bool? ?? false,
    isActive: json['status'] == 'active',
    packSize: (json['pack_size'] as num?)?.toInt(),
    packPrice: json['pack_price'] as String?,
  );

  final int id;
  final String name;
  final String? barcode;

  /// `piece` or `kg` (CR-13 modified). Prices and quantities are in this unit.
  final ProductUnit unit;

  /// e.g. `"6.50"` (ILS) per [unit].
  final String sellingPrice;
  final String? costPrice;

  /// Exact quantities in [unit]: whole pieces, or kg to the gram (doc 15 §4).
  final Quantity currentStock;
  final Quantity minimumStock;

  /// `current_stock <= minimum_stock` (US-0403), computed by the server.
  final bool isLowStock;
  final bool isActive;

  /// Wholesale carton (piece products only): [packSize] pieces for [packPrice]. Stock stays in pieces.
  final int? packSize;
  final String? packPrice;

  Money get price => Money.parse(sellingPrice);

  bool get isWeighed => unit == ProductUnit.kg;

  bool get hasPack => packSize != null && packPrice != null;

  /// The price of one whole carton.
  Money get packMoney => Money.parse(packPrice ?? '0');
}
