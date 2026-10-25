import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/api/idempotency_key_store.dart';
import '../../sale/data/sale_repository.dart';
import '../domain/product.dart';

/// POST /stock-adjustments (Owner / Manager): goods received for a product already in the store.
/// Same key discipline as a sale: [operationId] names one adjustment, its Idempotency-Key survives a
/// timeout, so retrying it can never add the quantity twice.
class StockRepository {
  StockRepository(this._api, this._keys);

  final ApiClient _api;
  final IdempotencyKeyStore _keys;

  /// The product as the server holds it after the movement (its new stock).
  Future<Product> addStock(
    Product product, {
    required String quantity,
    required String reason,
    required String operationId,
    bool pack = false,
  }) async {
    final key = await _keys.keyFor(operationId);
    try {
      final body = await _api.post(
        '/stock-adjustments',
        // `unit: pack`: [quantity] is whole cartons; the server adds cartons × pack size pieces.
        body: {
          'product_id': product.id,
          'quantity': quantity.trim(),
          'reason': reason.trim(),
          if (pack) 'unit': 'pack',
        },
        idempotencyKey: key,
      );
      await _keys.complete(operationId);
      return Product.fromJson(body['product'] as Map<String, dynamic>);
    } on ApiFailure catch (failure) {
      if (SaleRepository.isFinalAnswer(failure)) await _keys.complete(operationId);
      rethrow;
    }
  }
}
