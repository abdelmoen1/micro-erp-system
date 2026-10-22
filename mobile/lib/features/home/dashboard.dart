import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

/// Today's figures for the Home tab, from `GET /dashboard?period=today`.
/// Amounts stay decimal strings as the API sends them ("1250.00"); they are only formatted.
class TodayDashboard {
  const TodayDashboard({
    required this.totalSales,
    required this.cashSales,
    required this.creditSales,
    required this.collectedToday,
    required this.outstandingDebt,
    required this.invoicesCount,
    required this.customersWithDebt,
    required this.recentInvoices,
    this.collectedAtSale = '0.00',
    this.debtRepayments = '0.00',
    this.overdueCount = 0,
    this.overdueAmount = '0.00',
    this.dueTodayCount = 0,
    this.lowStockCount = 0,
    this.negativeStockCount = 0,
  });

  factory TodayDashboard.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    final sales = json['sales'] as Map<String, dynamic>? ?? const {};
    final payments = json['payments'] as Map<String, dynamic>? ?? const {};
    final debts = json['debts'] as Map<String, dynamic>? ?? const {};
    final customers = json['customers'] as Map<String, dynamic>? ?? const {};
    final recent = json['recent_invoices'] as List<dynamic>? ?? const [];
    final collections = json['collections'] as Map<String, dynamic>? ?? const {};
    final insights = json['insights'] as Map<String, dynamic>? ?? const {};
    Map<String, dynamic> card(String key) => insights[key] as Map<String, dynamic>? ?? const {};
    int count(String key) => (card(key)['count'] as num?)?.toInt() ?? 0;

    return TodayDashboard(
      totalSales: '${sales['total'] ?? summary['total_sales'] ?? '0.00'}',
      cashSales: '${sales['cash'] ?? '0.00'}',
      creditSales: '${sales['credit'] ?? '0.00'}',
      collectedToday: '${payments['today'] ?? '0.00'}',
      outstandingDebt: '${debts['total_remaining'] ?? '0.00'}',
      invoicesCount: (summary['invoices_count'] as num?)?.toInt() ?? 0,
      customersWithDebt: (customers['with_outstanding_debts'] as num?)?.toInt() ?? 0,
      recentInvoices: [for (final row in recent) RecentInvoice.fromJson(row as Map<String, dynamic>)],
      collectedAtSale: '${collections['at_sale'] ?? '0.00'}',
      debtRepayments: '${collections['debt_repayments'] ?? '0.00'}',
      overdueCount: count('overdue'),
      overdueAmount: '${card('overdue')['amount'] ?? '0.00'}',
      dueTodayCount: count('due_today'),
      lowStockCount: count('low_stock'),
      negativeStockCount: count('negative_stock'),
    );
  }

  final String totalSales;
  final String cashSales;
  final String creditSales;
  final String collectedToday;

  /// All open debt of the store, not only today's.
  final String outstandingDebt;
  final int invoicesCount;
  final int customersWithDebt;
  final List<RecentInvoice> recentInvoices;

  /// US-0801 AC1: money taken at the till vs debt repayments (dashboard v2).
  final String collectedAtSale;
  final String debtRepayments;

  /// US-0801 AC3 insight cards (M-10 «يحتاج انتباهك»).
  final int overdueCount;
  final String overdueAmount;
  final int dueTodayCount;
  final int lowStockCount;
  final int negativeStockCount;

  bool get needsAttention => overdueCount + dueTodayCount + lowStockCount + negativeStockCount > 0;
}

class RecentInvoice {
  const RecentInvoice({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.onCredit,
    this.createdAt,
  });

  factory RecentInvoice.fromJson(Map<String, dynamic> json) => RecentInvoice(
    id: (json['id'] as num).toInt(),
    customerName: (json['customer'] as Map<String, dynamic>?)?['name'] as String?,
    amount: '${json['total_amount'] ?? '0.00'}',
    onCredit: json['type'] == 'credit',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
  );

  final int id;

  /// Null for a sale without a customer (walk-in, cash).
  final String? customerName;
  final String amount;
  final bool onCredit;
  final DateTime? createdAt;
}

final dashboardProvider = FutureProvider.autoDispose<TodayDashboard>((ref) async {
  final body = await ref.watch(apiClientProvider).get('/dashboard', query: {'period': 'today'});
  return TodayDashboard.fromJson(body['data'] as Map<String, dynamic>? ?? const {});
});

final _money = NumberFormat('#,##0.00', 'en');

/// "1250.5" → "1,250.50" (Western digits).
String formatMoney(String amount) => _money.format(num.tryParse(amount) ?? 0);
