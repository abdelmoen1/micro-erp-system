import '../../../core/money/fixed_point.dart';

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
