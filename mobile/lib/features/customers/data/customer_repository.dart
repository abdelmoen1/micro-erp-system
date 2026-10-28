import '../../../core/api/api_client.dart';
import '../../../core/money/fixed_point.dart';
import '../domain/customer.dart';
import '../domain/ledger.dart';

/// The customer endpoints of the sale flow (M-05 picker, quick-create) and of the customer tab
/// (M-07 list, M-08 detail, M-09 payment).
class CustomerRepository {
  CustomerRepository(this._api);

  final ApiClient _api;

  /// By name or phone; an empty [query] lists the newest customers. Each row carries its balance.
  /// The POS picker sees active customers only (US-0301 AC4); the customer tab passes [all], since
  /// an inactive customer stays payable.
  Future<List<Customer>> search(String query, {bool all = false}) async {
    final q = query.trim();
    final body = await _api.get(
      '/customers',
      query: {'per_page': 30, if (q.isNotEmpty) 'search': q, if (all) 'status': 'all'},
    );
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Customer.fromJson(row as Map<String, dynamic>)];
  }

  /// POST /customers with the name and phone only; the credit limit is set later by an owner.
  /// Validation failures (e.g. a phone already used) are thrown as `ValidationFailed`.
  Future<Customer> create({required String name, required String phone}) async {
    final body = await _api.post('/customers', body: {'name': name.trim(), 'phone': phone.trim()});
    final json = (body['customer'] ?? body['data']) as Map<String, dynamic>;
    return Customer.fromJson({...json, 'balance': json['balance'] ?? '0.00'});
  }

  Future<CustomerSummary> summary(int customerId) async {
    final body = await _api.get('/customers/$customerId/summary');
    return CustomerSummary.fromJson(body['data'] as Map<String, dynamic>? ?? const {});
  }

  /// Open debts, oldest due first (the order a payment pays them).
  Future<List<OpenDebt>> openDebts(int customerId) async {
    final body = await _api.get(
      '/debts',
      query: {'customer_id': customerId, 'bucket': 'open', 'sort': 'due', 'per_page': 50},
    );
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) OpenDebt.fromJson(row as Map<String, dynamic>)];
  }

  Future<List<PaymentRow>> payments(int customerId) async {
    final body = await _api.get('/payments', query: {'customer_id': customerId, 'per_page': 10});
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) PaymentRow.fromJson(row as Map<String, dynamic>)];
  }

  /// POST /debts: an old debt from before Hisbah (owner or manager). It is an obligation only; the
  /// server records no sale, stock movement or payment. The same [idempotencyKey] on a retry can
  /// never record it twice. Returns the new debt's remaining amount.
  Future<Money> recordLegacyDebt({
    required int customerId,
    required Money amount,
    required String idempotencyKey,
    String? originatedOn,
    String? dueDate,
    String? note,
  }) async {
    final body = await _api.post(
      '/debts',
      body: {
        'customer_id': customerId,
        'amount': amount.toApi(),
        'originated_on': ?originatedOn,
        'due_date': ?dueDate,
        'note': ?note,
      },
      idempotencyKey: idempotencyKey,
    );
    final debt = (body['data'] as Map<String, dynamic>? ?? const {})['debt'] as Map<String, dynamic>? ?? const {};
    return Money.parse('${debt['remaining_amount'] ?? amount.toApi()}');
  }

  /// US-0705: the whole balance when [amount] is null, else that amount to the oldest debts first.
  /// The same [idempotencyKey] on a retry can never record the payment twice (AC3).
  Future<PaymentReceipt> pay({
    required int customerId,
    required String method,
    required String idempotencyKey,
    Money? amount,
  }) async {
    final body = await _api.post(
      '/customers/$customerId/debts/pay-all',
      body: {'method': method, 'amount': ?amount?.toApi()},
      idempotencyKey: idempotencyKey,
    );
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return PaymentReceipt(
      paid: Money.parse('${data['total_paid'] ?? '0.00'}'),
      remainingAfter: Money.parse('${data['remaining_after'] ?? '0.00'}'),
    );
  }
}
