import '../../../core/money/fixed_point.dart';

/// A debt repayment or one group of them, as the day's collections list it.
class CollectedPayment {
  const CollectedPayment({required this.amount, required this.method, this.customerName, this.at, this.reversed = false});

  factory CollectedPayment.fromJson(Map<String, dynamic> json) => CollectedPayment(
    amount: Money.parse(json['total_amount'] as String? ?? '0'),
    method: json['method'] as String?,
    customerName: (json['customer'] as Map<String, dynamic>?)?['name'] as String?,
    at: DateTime.tryParse(json['paid_at'] as String? ?? '')?.toLocal(),
    reversed: json['is_reversed'] == true,
  );

  final Money amount;
  final String? method;
  final String? customerName;
  final DateTime? at;
  final bool reversed;
}

/// A customer with open debts, from GET /debts/balances.
class Debtor {
  const Debtor({required this.customer, required this.openCount, this.oldestDue});

  factory Debtor.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    return Debtor(
      customer: Customer(
        id: (customer['id'] as num).toInt(),
        name: customer['name'] as String? ?? '',
        phone: customer['phone'] as String? ?? '',
        balance: Money.parse(json['total_remaining'] as String? ?? '0'),
        creditLimit: null,
      ),
      openCount: (json['open_count'] as num?)?.toInt() ?? 0,
      oldestDue: json['oldest_due'] as String?,
    );
  }

  final Customer customer;
  final int openCount;

  /// `YYYY-MM-DD`; null when no debt has a due date.
  final String? oldestDue;
}

/// A customer as the picker (M-05) and checkout (M-04) need it: who, how to reach them, what they
/// owe now and their credit limit (null = no limit, US-0305).
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
    required this.creditLimit,
    this.overdue = Money.zero,
    this.isActive = true,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    balance: Money.parse(json['balance'] as String? ?? '0.00'),
    creditLimit: json['credit_limit'] == null ? null : Money.parse(json['credit_limit'] as String),
    overdue: Money.parse(json['overdue'] as String? ?? '0.00'),
    isActive: (json['status'] ?? 'active') == 'active',
  );

  final int id;
  final String name;
  final String phone;

  /// Σ remaining of the customer's open debts.
  final Money balance;
  final Money? creditLimit;

  /// Σ remaining past its due date (M-07 «متأخر» badge).
  final Money overdue;

  /// Inactive customers stay payable but are hidden from new sales (US-0301 AC4).
  final bool isActive;

  /// The avatar letter: the name without the kunya «أبو» / «أم» (hi-fi M-05).
  String get initial {
    final bare = name.replaceFirst(RegExp(r'^(أبو|أم)\s+'), '').trim();
    return bare.isEmpty ? '' : String.fromCharCode(bare.runes.first);
  }

  /// `0599123456` → `059 912 3456`.
  String get phoneDisplay =>
      phone.length == 10 ? '${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6)}' : phone;

  /// D-26: would a new debt of [debt] take the customer above the limit?
  bool wouldExceedLimit(Money debt) {
    final limit = creditLimit;
    return limit != null && debt.isPositive && balance + debt > limit;
  }
}
