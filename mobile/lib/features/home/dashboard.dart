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
  });

  factory TodayDashboard.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    final sales = json['sales'] as Map<String, dynamic>? ?? const {};
    final payments = json['payments'] as Map<String, dynamic>? ?? const {};
    final debts = json['debts'] as Map<String, dynamic>? ?? const {};
    final customers = json['customers'] as Map<String, dynamic>? ?? const {};
    final recent = json['recent_invoices'] as List<dynamic>? ?? const [];

    return TodayDashboard(
      totalSales: '${sales['total'] ?? summary['total_sales'] ?? '0.00'}',
      cashSales: '${sales['cash'] ?? '0.00'}',
      creditSales: '${sales['credit'] ?? '0.00'}',
      collectedToday: '${payments['today'] ?? '0.00'}',
      outstandingDebt: '${debts['total_remaining'] ?? '0.00'}',
      invoicesCount: (summary['invoices_count'] as num?)?.toInt() ?? 0,
      customersWithDebt: (customers['with_outstanding_debts'] as num?)?.toInt() ?? 0,
      recentInvoices: [for (final row in recent) RecentInvoice.fromJson(row as Map<String, dynamic>)],
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
}

class RecentInvoice {
  const RecentInvoice({required this.id, required this.customerName, required this.amount, required this.onCredit, this.createdAt});

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
