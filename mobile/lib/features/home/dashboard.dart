import 'dart:async';

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
    this.collectedTotal = '0.00',
    this.refunded = '0.00',
    this.collectedNet = '0.00',
    this.returnsCount = 0,
    this.returnsTotal = '0.00',
    this.purchasesCount = 0,
    this.purchasesTotal,
    this.owedToSuppliers = '0.00',
    this.profit,
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
    final returns = json['returns'] as Map<String, dynamic>? ?? const {};
    final purchases = json['purchases'] as Map<String, dynamic>?;
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
      collectedTotal: '${collections['total'] ?? payments['today'] ?? '0.00'}',
      refunded: '${collections['refunded'] ?? '0.00'}',
      collectedNet: '${collections['net'] ?? collections['total'] ?? '0.00'}',
      returnsCount: (returns['count'] as num?)?.toInt() ?? 0,
      returnsTotal: '${returns['total'] ?? '0.00'}',
      purchasesCount: (purchases?['count'] as num?)?.toInt() ?? 0,
      purchasesTotal: purchases?['total'] as String?,
      owedToSuppliers: '${purchases?['owed_to_suppliers'] ?? '0.00'}',
      profit: json['profit'] is Map<String, dynamic> ? NetProfit.fromJson(json['profit'] as Map<String, dynamic>) : null,
    );
  }

  /// Null for an employee, or from a server without the figure: Home then shows the collections.
  final NetProfit? profit;

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

  /// Money in today at the till and on debts, then less the cash refunded to customers.
  final String collectedTotal;
  final String refunded;
  final String collectedNet;

  final int returnsCount;
  final String returnsTotal;

  /// Null for an employee: costs stay with the owner and managers.
  final String? purchasesTotal;
  final int purchasesCount;
  final String owedToSuppliers;

  bool get needsAttention => overdueCount + dueTodayCount + lowStockCount + negativeStockCount > 0;
}

/// «صافي الربح»: what the day earned away from the capital in stock and the running costs.
/// net = salesProfit − discounts − returnsProfit − obligations (the server's arithmetic).
class NetProfit {
  const NetProfit({
    required this.salesProfit,
    required this.discounts,
    required this.returnsProfit,
    required this.obligations,
    required this.net,
    this.uncostedLines = 0,
  });

  factory NetProfit.fromJson(Map<String, dynamic> json) => NetProfit(
    salesProfit: '${json['sales_profit'] ?? '0.00'}',
    discounts: '${json['discounts'] ?? '0.00'}',
    returnsProfit: '${json['returns_profit'] ?? '0.00'}',
    obligations: '${json['obligations'] ?? '0.00'}',
    net: '${json['net'] ?? '0.00'}',
    uncostedLines: (json['uncosted_lines'] as num?)?.toInt() ?? 0,
  );

  /// Each sold line's price past its cost.
  final String salesProfit;
  final String discounts;

  /// Profit undone by goods brought back.
  final String returnsProfit;

  /// Today's share of rent, electricity, salaries…
  final String obligations;
  final String net;

  /// Sold lines whose product has no cost price: left out of the figure.
  final int uncostedLines;

  bool get isLoss => net.startsWith('-');
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

/// One period's sales as the dashboard counts them (active sales, voided ones left out).
class SalesSummary {
  const SalesSummary({required this.total, required this.cash, required this.credit, required this.count});

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    final sales = json['sales'] as Map<String, dynamic>? ?? const {};
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return SalesSummary(
      total: '${sales['total'] ?? summary['total_sales'] ?? '0.00'}',
      cash: '${sales['cash'] ?? '0.00'}',
      credit: '${sales['credit'] ?? '0.00'}',
      count: (summary['invoices_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String total;
  final String cash;
  final String credit;
  final int count;
}

/// `today`, `this_week` (Monday on) or `this_month`, in the store's own time zone.
final salesSummaryProvider = FutureProvider.autoDispose.family<SalesSummary, String>((ref, period) async {
  final body = await ref.watch(apiClientProvider).get('/dashboard', query: {'period': period});
  return SalesSummary.fromJson(body['data'] as Map<String, dynamic>? ?? const {});
});

/// The eye on the green card: amounts hidden from whoever stands at the counter. Kept on the phone.
class HideAmounts extends Notifier<bool> {
  static const _key = 'home.hide_amounts';

  @override
  bool build() {
    unawaited(_restore());
    return false;
  }

  Future<void> _restore() async {
    try {
      final saved = await ref.read(keyValueStoreProvider).read(_key);
      if (ref.mounted && saved == '1') state = true;
    } on Object {
      // Unreadable: amounts show.
    }
  }

  Future<void> toggle() async {
    state = !state;
    try {
      await ref.read(keyValueStoreProvider).write(_key, state ? '1' : '0');
    } on Object {
      // The choice still holds until the app closes.
    }
  }
}

final hideAmountsProvider = NotifierProvider<HideAmounts, bool>(HideAmounts.new);

/// What a hidden amount shows instead of the figure.
const hiddenAmount = '••••';

final _money = NumberFormat('#,##0.00', 'en');

/// "1250.5" → "1,250.50" (Western digits).
String formatMoney(String amount) => _money.format(num.tryParse(amount) ?? 0);
