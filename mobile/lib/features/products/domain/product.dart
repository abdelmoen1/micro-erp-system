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
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    barcode: json['barcode'] as String?,
    sellingPrice: json['selling_price'] as String? ?? '0.00',
    costPrice: json['cost_price'] as String?,
    currentStock: (json['current_stock'] as num?)?.toInt() ?? 0,
    minimumStock: (json['minimum_stock'] as num?)?.toInt() ?? 5,
    isLowStock: json['is_low_stock'] as bool? ?? false,
    isActive: json['status'] == 'active',
  );

  final int id;
  final String name;
  final String? barcode;

  /// e.g. `"6.50"` (ILS).
  final String sellingPrice;
  final String? costPrice;

  /// Integer quantities (CR-13).
  final int currentStock;
  final int minimumStock;

  /// `current_stock <= minimum_stock` (US-0403), computed by the server.
  final bool isLowStock;
  final bool isActive;
}
