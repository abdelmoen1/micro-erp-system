import 'dart:convert';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/api/idempotency_key_store.dart';
import '../../../core/money/fixed_point.dart';
import '../../returns/domain/returns.dart';
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

  /// GET /purchases: newest first, 20 a page, of one supplier when [supplierId] is set.
  Future<RegisterPage<PurchaseRow>> purchases({String? from, String? to, int page = 1, int? supplierId}) async {
    final body = await _api.get(
      '/purchases',
      query: {'per_page': 20, 'page': page, 'from': ?from, 'to': ?to, 'supplier_id': ?supplierId},
    );
    return RegisterPage.fromBody(body, PurchaseRow.fromJson);
  }

  Future<PurchaseDetail> purchase(int purchaseId) async {
    final body = await _api.get('/purchases/$purchaseId');
    return PurchaseDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<RegisterPage<PurchaseReturnRecord>> purchaseReturns({String? from, String? to, int page = 1}) async {
    final body = await _api.get('/returns/purchases', query: {'per_page': 20, 'page': page, 'from': ?from, 'to': ?to});
    return RegisterPage.fromBody(body, PurchaseReturnRecord.fromJson);
  }

  /// POST /purchases/{id}/returns. The operation follows the body, so a retry of the same return
  /// is one return, and an edited one is new.
  Future<PurchaseReturnRecord> returnPurchase(int purchaseId, {required List<ReturnChoice> lines, required String reason}) async {
    final body = {
      'items': [
        for (final line in lines)
          {'purchase_item_id': line.id, 'quantity': line.quantity.toString(), 'from_stock': !line.flagged},
      ],
      'reason': reason,
    };
    final operationId = 'purchase-return-$purchaseId-${SaleRepository.stableHash(jsonEncode(body))}';
    final key = await _keys.keyFor(operationId);
    try {
      final answer = await _api.post('/purchases/$purchaseId/returns', body: body, idempotencyKey: key);
      await _keys.complete(operationId);
      return PurchaseReturnRecord.fromJson(answer['data'] as Map<String, dynamic>);
    } on ApiFailure catch (failure) {
      if (SaleRepository.isFinalAnswer(failure)) await _keys.complete(operationId);
      rethrow;
    }
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
