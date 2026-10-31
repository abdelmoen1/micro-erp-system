import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/api/idempotency_key_store.dart';
import '../../../core/money/fixed_point.dart';
import '../../sale/data/sale_repository.dart';
import '../domain/goods.dart';

/// Goods from suppliers. Writes keep the sale's key discipline: one [operationId] is one delivery
/// or payment, and its Idempotency-Key survives a timeout, so a retry can never count it twice.
class GoodsRepository {
  GoodsRepository(this._api, this._keys);

  final ApiClient _api;
  final IdempotencyKeyStore _keys;

  Future<List<Supplier>> suppliers() async {
    final body = await _api.get('/suppliers');
    return [for (final row in body['data'] as List<dynamic>? ?? const []) Supplier.fromJson(row as Map<String, dynamic>)];
  }

  Future<SupplierDetail> supplier(int supplierId) async {
    final body = await _api.get('/suppliers/$supplierId');
    return SupplierDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<ProductInvoices> productInvoices(int supplierId, int productId) async {
    final body = await _api.get('/suppliers/$supplierId/products/$productId');
    return ProductInvoices.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Saved on the supplier's account in full; payments are recorded there afterwards.
  Future<GoodsReceipt> record({
    required String supplierName,
    required List<GoodsLine> lines,
    required String operationId,
  }) async {
    final key = await _keys.keyFor(operationId);
    try {
      final body = await _api.post(
        '/purchases',
        body: {
          'supplier_name': supplierName.trim(),
          'lines': [for (final line in lines) line.toApi()],
        },
        idempotencyKey: key,
      );
      await _keys.complete(operationId);
      return GoodsReceipt.fromJson(body['data'] as Map<String, dynamic>);
    } on ApiFailure catch (failure) {
      if (SaleRepository.isFinalAnswer(failure)) await _keys.complete(operationId);
      rethrow;
    }
  }

  Future<void> pay({
    required int supplierId,
    required Money amount,
    required String method,
    required String operationId,
  }) async {
    final key = await _keys.keyFor(operationId);
    try {
      await _api.post(
        '/suppliers/$supplierId/payments',
        body: {'amount': amount.toApi(), 'method': method},
        idempotencyKey: key,
      );
      await _keys.complete(operationId);
    } on ApiFailure catch (failure) {
      if (SaleRepository.isFinalAnswer(failure)) await _keys.complete(operationId);
      rethrow;
    }
  }
}
