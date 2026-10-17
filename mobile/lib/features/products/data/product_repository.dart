import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
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

  /// Active products at or below their threshold, lowest stock first (US-0403). First page.
  Future<List<Product>> lowStock() async {
    final body = await _api.get('/products/low-stock');
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }
}
