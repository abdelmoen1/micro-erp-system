import '../../../core/money/fixed_point.dart';

DateTime _time(Object? value) => DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();

/// One line of a return. [flagged] is «تالفة» on a customer's return and «خارج المخزن» on a return
/// to the supplier: either way the line did not move the shelf stock.
class ReturnedLine {
  const ReturnedLine({required this.name, required this.unit, required this.quantity, required this.total, this.flagged = false});

  final String name;
  final ProductUnit unit;
  final Quantity quantity;
  final Money total;
  final bool flagged;
}

/// What came back from a customer: the debt went down first, the rest was refunded in cash.
class SaleReturnRecord {
  const SaleReturnRecord({
    required this.id,
    required this.invoiceId,
    required this.total,
    required this.toDebt,
    required this.refund,
    required this.reason,
    required this.at,
    required this.lines,
    this.customerName,
    this.by,
  });

  factory SaleReturnRecord.fromJson(Map<String, dynamic> json) => SaleReturnRecord(
    id: (json['id'] as num).toInt(),
    invoiceId: (json['invoice_id'] as num).toInt(),
    total: Money.parse(json['total_amount'] as String? ?? '0'),
    toDebt: Money.parse(json['debt_reduction'] as String? ?? '0'),
    refund: Money.parse(json['refund_amount'] as String? ?? '0'),
    reason: json['reason'] as String? ?? '',
    at: _time(json['created_at']),
    customerName: (json['customer'] as Map<String, dynamic>?)?['name'] as String?,
    by: json['created_by'] as String?,
    lines: [
      for (final row in json['items'] as List<dynamic>? ?? const [])
        ReturnedLine(
          name: (row as Map<String, dynamic>)['item_name'] as String? ?? '',
          unit: ProductUnit.fromApi(row['unit']),
          quantity: Quantity.parse(row['quantity'] ?? '0'),
          total: Money.parse(row['total'] as String? ?? '0'),
          flagged: row['damaged'] == true,
        ),
    ],
  );

  final int id;
  final int invoiceId;
  final Money total;
  final Money toDebt;
  final Money refund;
  final String reason;
  final DateTime at;
  final String? customerName;
  final String? by;
  final List<ReturnedLine> lines;
}

/// What went back to a supplier: the balance went down first, the rest came back as a refund.
class PurchaseReturnRecord {
  const PurchaseReturnRecord({
    required this.id,
    required this.invoiceId,
    required this.total,
    required this.toBalance,
    required this.refund,
    required this.reason,
    required this.at,
    required this.lines,
    this.supplierName,
    this.by,
  });

  factory PurchaseReturnRecord.fromJson(Map<String, dynamic> json) => PurchaseReturnRecord(
    id: (json['id'] as num).toInt(),
    invoiceId: (json['purchase_invoice_id'] as num).toInt(),
    total: Money.parse(json['total_amount'] as String? ?? '0'),
    toBalance: Money.parse(json['balance_reduction'] as String? ?? '0'),
    refund: Money.parse(json['refund_amount'] as String? ?? '0'),
    reason: json['reason'] as String? ?? '',
    at: _time(json['created_at']),
    supplierName: (json['supplier'] as Map<String, dynamic>?)?['name'] as String?,
    by: json['created_by'] as String?,
    lines: [
      for (final row in json['items'] as List<dynamic>? ?? const [])
        ReturnedLine(
          name: (row as Map<String, dynamic>)['item_name'] as String? ?? '',
          unit: ProductUnit.fromApi(row['unit']),
          quantity: Quantity.parse(row['quantity'] ?? '0'),
          total: Money.parse(row['total'] as String? ?? '0'),
          flagged: row['from_stock'] == false,
        ),
    ],
  );

  final int id;
  final int invoiceId;
  final Money total;
  final Money toBalance;
  final Money refund;
  final String reason;
  final DateTime at;
  final String? supplierName;
  final String? by;
  final List<ReturnedLine> lines;
}

/// A line chosen on the return form. [flagged] as on [ReturnedLine].
class ReturnChoice {
  const ReturnChoice({required this.id, required this.quantity, required this.flagged});

  final int id;
  final Quantity quantity;
  final bool flagged;
}

/// One page of a register, newest first.
class RegisterPage<T> {
  const RegisterPage({required this.rows, required this.hasMore});

  factory RegisterPage.fromBody(Map<String, dynamic> body, T Function(Map<String, dynamic>) row) {
    final meta = body['meta'] is Map<String, dynamic> ? body['meta'] as Map<String, dynamic> : const {};
    return RegisterPage(
      rows: [for (final item in body['data'] as List<dynamic>? ?? const []) row(item as Map<String, dynamic>)],
      hasMore: ((meta['current_page'] as num?) ?? 1) < ((meta['last_page'] as num?) ?? 1),
    );
  }

  final List<T> rows;
  final bool hasMore;
}
