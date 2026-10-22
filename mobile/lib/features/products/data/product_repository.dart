import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../domain/product.dart';

/// Read side of the product API for the POS (T-1301-7: scan → lookup) and low-stock lists.
/// The camera scanner itself waits for the US-1305 spike; any barcode source calls [lookupByBarcode].
class ProductRepository {
  ProductRepository(this._api);

  final ApiClient _api;

  /// The active product of my store with this barcode, or null when there is none
  /// (404, also for inactive products: US-0401 AC3). Other failures are thrown.
  Future<Product?> lookupByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    try {
      final body = await _api.get('/products/lookup', query: {'barcode': code});
      return Product.fromJson(body['data'] as Map<String, dynamic>);
    } on NotFound {
      return null;
    }
  }

  /// Active products whose name contains [query] (or whose barcode is exactly [query]), by name.
  /// M-02 «بحث بالاسم».
  Future<List<Product>> search(String query) async {
    final q = query.trim();
    final body = await _api.get('/products', query: {if (q.isNotEmpty) 'search': q});
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }

  /// Active products at or below their threshold, lowest stock first (US-0403). First page.
  Future<List<Product>> lowStock() async {
    final body = await _api.get('/products/low-stock');
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }

  /// M-11: active products by name or barcode; [stock] narrows to `low` or `negative`.
  Future<List<Product>> list({String query = '', String? stock}) async {
    final q = query.trim();
    final body = await _api.get('/products', query: {'per_page': 50, if (q.isNotEmpty) 'search': q, 'stock': ?stock});
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }

  /// S3 · QR add: POST /products (Owner / Manager). Field problems come back as `ValidationFailed`
  /// (a barcode already used, a fraction for a piece product, …) and an employee gets `Forbidden`.
  Future<Product> create(NewProduct draft) async {
    final body = await _api.post('/products', body: draft.toJson());
    return Product.fromJson((body['data'] ?? body['product']) as Map<String, dynamic>);
  }
}

/// The fields of POST /products, as the owner confirmed them on the form.
class NewProduct {
  const NewProduct({
    required this.name,
    required this.unit,
    required this.sellingPrice,
    required this.currentStock,
    this.barcode,
    this.costPrice,
    this.minimumStock,
  });

  final String name;
  final String? barcode;
  final ProductUnit unit;
  final String sellingPrice;
  final String? costPrice;
  final String currentStock;
  final String? minimumStock;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'barcode': ?(barcode?.trim().isEmpty ?? true ? null : barcode!.trim()),
    'unit': unit.apiValue,
    'selling_price': sellingPrice.trim(),
    'cost_price': ?(costPrice?.trim().isEmpty ?? true ? null : costPrice!.trim()),
    'current_stock': currentStock.trim(),
    'minimum_stock': ?(minimumStock?.trim().isEmpty ?? true ? null : minimumStock!.trim()),
  };
}
