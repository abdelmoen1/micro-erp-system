import '../../../core/money/fixed_point.dart';

/// M-08 header: what the customer owes, from GET /customers/{id}/summary (US-0302).
class CustomerSummary {
  const CustomerSummary({
    required this.remaining,
    required this.overdue,
    required this.openDebts,
    required this.creditLimit,
  });

  factory CustomerSummary.fromJson(Map<String, dynamic> json) => CustomerSummary(
    remaining: Money.parse('${json['remaining'] ?? '0.00'}'),
    overdue: Money.parse('${json['overdue'] ?? '0.00'}'),
    openDebts: (json['open_debts_count'] as num?)?.toInt() ?? 0,
    creditLimit: json['credit_limit'] == null ? null : Money.parse('${json['credit_limit']}'),
  );

  final Money remaining;
  final Money overdue;
  final int openDebts;
  final Money? creditLimit;
}

/// One open debt on M-08 (GET /debts?customer_id=…&bucket=open).
class OpenDebt {
  const OpenDebt({
    required this.id,
    required this.invoiceId,
    required this.isOpening,
    required this.remaining,
    required this.dueDate,
  });

  factory OpenDebt.fromJson(Map<String, dynamic> json) => OpenDebt(
    id: (json['id'] as num).toInt(),
    invoiceId: (json['invoice_id'] as num?)?.toInt(),
    isOpening: json['source'] == 'opening_debt',
    remaining: Money.parse('${json['remaining_amount'] ?? '0.00'}'),
    dueDate: DateTime.tryParse('${json['due_date'] ?? ''}'),
  );

  final int id;
  final int? invoiceId;
  final bool isOpening;
  final Money remaining;
  final DateTime? dueDate;

  /// Past its due date by the phone's calendar (the store and its phones share one timezone).
  bool isOverdue(DateTime today) {
    final due = dueDate;
    return due != null && remaining.isPositive && due.isBefore(DateTime(today.year, today.month, today.day));
  }
}

/// One payment operation on M-08 (a pay-all group is one row).
class PaymentRow {
  const PaymentRow({
    required this.amount,
    required this.paidAt,
    required this.by,
    required this.method,
    required this.reversed,
  });

  factory PaymentRow.fromJson(Map<String, dynamic> json) => PaymentRow(
    amount: Money.parse('${json['total_amount'] ?? '0.00'}'),
    paidAt: DateTime.tryParse('${json['paid_at'] ?? ''}')?.toLocal(),
    by: json['created_by'] as String?,
    method: json['method'] as String? ?? 'cash',
    reversed: json['is_reversed'] == true,
  );

  final Money amount;
  final DateTime? paidAt;
  final String? by;
  final String method;
  final bool reversed;
}

/// The server's answer to a payment: what was paid and what is left (US-0705).
class PaymentReceipt {
  const PaymentReceipt({required this.paid, required this.remainingAfter});

  final Money paid;
  final Money remainingAfter;
}
