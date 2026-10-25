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

/// One printed line of a sale (snapshots taken by the server at the sale).
class SaleLine {
  const SaleLine({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.packSize,
  });

  factory SaleLine.fromJson(Map<String, dynamic> json) => SaleLine(
    name: json['item_name'] as String? ?? '',
    unit: ProductUnit.fromApi(json['unit']),
    quantity: Quantity.parse(json['quantity'] ?? '0'),
    unitPrice: Money.parse(json['unit_price'] as String? ?? '0.00'),
    lineTotal: Money.parse((json['line_total'] ?? json['total']) as String? ?? '0.00'),
    packSize: (json['pack_size'] as num?)?.toInt(),
  );

  final String name;
  final ProductUnit unit;
  final Quantity quantity;
  final Money unitPrice;
  final Money lineTotal;

  /// Sold by the carton: [quantity] and [unitPrice] are per carton of [packSize] pieces.
  final int? packSize;

  bool get isPack => packSize != null;

  /// The pieces behind a carton line (or the quantity itself).
  Quantity get baseQuantity => isPack ? Quantity.milli(quantity.milli * packSize!) : quantity;
}

/// A recorded sale as the receipt (M-06) shows it: number, lines, totals, debt, who sold it, and
/// the server's NEGATIVE_STOCK warnings (D-27). Also the result of a void.
class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.total,
    required this.paid,
    required this.debt,
    required this.flags,
    required this.warnings,
    this.status = 'active',
    this.lines = const [],
    this.paymentMethod,
    this.customerName,
    this.customerPhone,
    this.sellerName,
    this.createdAt,
    this.dueDate,
    this.voidedAt,
    this.voidedByName,
    this.voidReason,
  });

  factory SaleReceipt.fromJson(Map<String, dynamic> body) {
    final data = body['data'] as Map<String, dynamic>;
    final customer = data['customer'] is Map<String, dynamic> ? data['customer'] as Map<String, dynamic> : null;
    final seller = data['seller'] is Map<String, dynamic> ? data['seller'] as Map<String, dynamic> : null;
    final debt = data['debt'] is Map<String, dynamic> ? data['debt'] as Map<String, dynamic> : null;
    return SaleReceipt(
      id: (data['id'] as num).toInt(),
      status: data['status'] as String? ?? 'active',
      total: Money.parse(data['total_amount'] as String),
      paid: Money.parse(data['paid_amount'] as String),
      debt: Money.parse(data['debt_amount'] as String? ?? '0.00'),
      paymentMethod: data['payment_method'] as String?,
      lines: [for (final l in data['items'] as List<dynamic>? ?? const []) SaleLine.fromJson(l as Map<String, dynamic>)],
      customerName: customer?['name'] as String?,
      customerPhone: customer?['phone'] as String?,
      sellerName: seller?['name'] as String?,
      createdAt: DateTime.tryParse(data['created_at'] as String? ?? '')?.toLocal(),
      dueDate: debt?['due_date'] as String?,
      voidedAt: DateTime.tryParse(data['voided_at'] as String? ?? '')?.toLocal(),
      voidedByName: data['voided_by_name'] as String?,
      voidReason: data['void_reason'] as String?,
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
  final String status;
  final Money total;
  final Money paid;
  final Money debt;
  final List<String> flags;
  final List<NegativeStockWarning> warnings;
  final List<SaleLine> lines;

  /// `cash`, `jawwal_pay`, `palpay`, `bank_of_palestine`, or null when nothing was paid.
  final String? paymentMethod;
  final String? customerName;
  final String? customerPhone;
  final String? sellerName;
  final DateTime? createdAt;

  /// `YYYY-MM-DD` of the debt, when one was set.
  final String? dueDate;
  final DateTime? voidedAt;
  final String? voidedByName;
  final String? voidReason;

  bool get isVoided => status == 'voided';

  /// Keeps the server's warnings from the sale itself when a void response (which has none) replaces it.
  SaleReceipt withWarningsFrom(SaleReceipt sale) => SaleReceipt(
    id: id,
    status: status,
    total: total,
    paid: paid,
    debt: debt,
    flags: sale.flags,
    warnings: sale.warnings,
    lines: lines,
    paymentMethod: paymentMethod,
    customerName: customerName,
    customerPhone: customerPhone,
    sellerName: sellerName,
    createdAt: createdAt,
    dueDate: dueDate ?? sale.dueDate,
    voidedAt: voidedAt,
    voidedByName: voidedByName,
    voidReason: voidReason,
  );
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

  /// POST /sales/{id}/void (US-0503, owner / manager). Same key discipline as [submit]: one key per
  /// sale, kept until a final answer, so a retried void never reverses stock twice.
  Future<SaleReceipt> voidSale(int saleId, {required String reason}) async {
    // The reason is part of the body, so an edited reason is a new operation (a reused key with a
    // different body is a 409). A second void of an already voided sale is refused by the server.
    final operationId = 'void-$saleId-${_stableHash(reason.trim())}';
    final key = await _keys.keyFor(operationId);
    try {
      final body = await _api.post('/sales/$saleId/void', body: {'reason': reason.trim()}, idempotencyKey: key);
      await _keys.complete(operationId);
      return SaleReceipt.fromJson(body);
    } on ApiFailure catch (failure) {
      if (isFinalAnswer(failure)) await _keys.complete(operationId);
      rethrow;
    }
  }

  /// Same value across app restarts (unlike [String.hashCode]).
  static String _stableHash(String text) {
    var hash = 0;
    for (final unit in text.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash.toRadixString(36);
  }

  /// The server decided, so the same request must not be resent with this key. Unknown outcomes
  /// (no response, 5xx, throttling, an expired session the user will renew) keep the key.
  static bool isFinalAnswer(ApiFailure failure) => switch (failure) {
    NetworkFailure() || ServerError() || TooManyRequests() || Unauthenticated() => false,
    IdempotencyKeyReused() || IdempotencyKeyMissingOrInvalid() => false,
    _ => true,
  };
}
