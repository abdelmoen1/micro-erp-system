import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/api/idempotency_key_store.dart';
import '../../../core/money/fixed_point.dart';
import '../domain/cart.dart';

/// The body of POST /sales (docs/api/sales.http). Built from the cart; no prices are sent.
class SaleDraft {
  const SaleDraft({
    required this.cart,
    required this.paidAmount,
    this.customerId,
    this.paymentMethod,
    this.dueDate,
    this.notes,
    this.confirmOverLimit = false,
  });

  final Cart cart;
  final Money paidAmount;

  /// Required by the server when [paidAmount] is below the total (D-07).
  final int? customerId;

  /// `cash`, `jawwal_pay`, `palpay` or `bank_of_palestine`; required when [paidAmount] > 0.
  final String? paymentMethod;

  /// `YYYY-MM-DD`, only when a debt results.
  final String? dueDate;
  final String? notes;

  /// Owner / Manager only, after they confirmed the credit-limit warning (D-26).
  final bool confirmOverLimit;

  Money get debtPreview => cart.total > paidAmount ? cart.total - paidAmount : Money.zero;

  Map<String, Object?> toJson() => {
    'customer_id': ?customerId,
    'items': cart.toSaleItems(),
    'paid_amount': paidAmount.toApi(),
    'payment_method': ?paymentMethod,
    'due_date': ?dueDate,
    'notes': ?notes,
    if (confirmOverLimit) 'confirm_over_limit': true,
  };
}

/// A product the sale took below zero (D-27). Shown as a notice; it never blocks the sale.
class NegativeStockWarning {
  const NegativeStockWarning({required this.productId, required this.name, required this.balanceAfter});

  final int productId;
  final String name;

  /// In the product's unit, e.g. `"-3"` or `"-0.250"`.
  final String balanceAfter;
}

/// What the receipt (M-06) needs from a 201: sale number, total, paid, debt and warnings.
class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.total,
    required this.paid,
    required this.debt,
    required this.flags,
    required this.warnings,
  });

  factory SaleReceipt.fromJson(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    return SaleReceipt(
      id: (data['id'] as num).toInt(),
      total: Money.parse(data['total_amount'] as String),
      paid: Money.parse(data['paid_amount'] as String),
      debt: Money.parse(data['debt_amount'] as String? ?? '0.00'),
      flags: [for (final f in body['flags'] as List<dynamic>? ?? const []) f as String],
      warnings: [
        for (final w in body['warnings'] as List<dynamic>? ?? const [])
          if ((w as Map<String, dynamic>)['code'] == 'NEGATIVE_STOCK')
            NegativeStockWarning(
              productId: (w['product_id'] as num).toInt(),
              name: w['name'] as String? ?? '',
              balanceAfter: w['balance_after'] as String? ?? '',
            ),
      ],
    );
  }

  final int id;
  final Money total;
  final Money paid;
  final Money debt;
  final List<String> flags;
  final List<NegativeStockWarning> warnings;
}

/// POST /sales with a persisted Idempotency-Key (US-0506 AC3, 05 §4.1).
///
/// [operationId] names one checkout. Its key survives timeouts and app restarts, so retrying the
/// same checkout can never record two sales. The key is released only when the server has given a
/// final answer. A changed request (e.g. the confirmed credit-limit override) is a NEW operation.
class SaleRepository {
  SaleRepository(this._api, this._keys);

  final ApiClient _api;
  final IdempotencyKeyStore _keys;

  Future<SaleReceipt> submit(SaleDraft draft, {required String operationId}) async {
    final key = await _keys.keyFor(operationId);
    try {
      final body = await _api.post('/sales', body: draft.toJson(), idempotencyKey: key);
      await _keys.complete(operationId);
      return SaleReceipt.fromJson(body);
    } on ApiFailure catch (failure) {
      if (isFinalAnswer(failure)) await _keys.complete(operationId);
      rethrow;
    }
  }

  /// The server decided, so the same request must not be resent with this key. Unknown outcomes
  /// (no response, 5xx, throttling, an expired session the user will renew) keep the key.
  static bool isFinalAnswer(ApiFailure failure) => switch (failure) {
    NetworkFailure() || ServerError() || TooManyRequests() || Unauthenticated() => false,
    IdempotencyKeyReused() || IdempotencyKeyMissingOrInvalid() => false,
    _ => true,
  };
}
