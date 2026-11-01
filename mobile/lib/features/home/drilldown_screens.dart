import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/money/fixed_point.dart';
import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/ltr_value.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../customers/domain/customer.dart';
import '../customers/presentation/customer_detail_screen.dart';
import '../more/presentation/more_widgets.dart' show pushScreen;
import '../sale/presentation/checkout_screen.dart' show paymentMethodLabel;
import '../sale/presentation/sale_widgets.dart';
import 'dashboard.dart';

final _clock = DateFormat('HH:mm', 'en');

final todayCollectionsProvider = FutureProvider.autoDispose<List<CollectedPayment>>(
  (ref) => ref.watch(customerRepositoryProvider).collectedToday(),
);

final debtorsProvider = FutureProvider.autoDispose<List<Debtor>>((ref) => ref.watch(customerRepositoryProvider).debtors());

/// «تحصيل اليوم» opened: where today's money came from, what went back, and each debt repayment.
class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key, required this.today});

  final TodayDashboard today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final payments = ref.watch(todayCollectionsProvider);

    Widget line(String label, String amount, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 16 : 15, fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
          MoneyText(amount, style: TextStyle(fontSize: strong ? 18 : 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(t.homeCollectedToday)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LineCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  line(t.collectionsAtSale, today.collectedAtSale),
                  line(t.collectionsRepayments, today.debtRepayments),
                  if (Money.parse(today.refunded).isPositive) line(t.collectionsRefunded, '-${today.refunded}'),
                  const Divider(height: 18),
                  line(t.collectionsNet, today.collectedNet, strong: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          GroupLabel(t.collectionsRepayments),
          const SizedBox(height: 8),
          ...payments.when(
            loading: () => const [LoadingView(padding: EdgeInsets.zero)],
            error: (_, _) => [ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(todayCollectionsProvider))],
            data: (rows) => rows.isEmpty
                ? [Text(t.collectionsEmpty, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted))]
                : [
                    LineCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(rows[i].customerName ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                        Text(
                                          [paymentMethodLabel(t, rows[i].method), if (rows[i].at != null) _clock.format(rows[i].at!)].join(' · '),
                                          style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Num(
                                    shekel(rows[i].amount),
                                    size: 15,
                                    weight: FontWeight.w700,
                                    color: rows[i].reversed ? HisbahColors.inkMuted : HisbahColors.ink,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

/// Everyone who owes the store, highest balance first; a tap opens the customer's account.
class DebtorsScreen extends ConsumerWidget {
  const DebtorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final debtors = ref.watch(debtorsProvider);
    final today = DateFormat('yyyy-MM-dd', 'en').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(t.homeOutstandingDebts)),
      body: debtors.when(
        loading: () => const LoadingView(),
        error: (_, _) => ErrorView(message: t.listLoadError, onRetry: () => ref.invalidate(debtorsProvider)),
        data: (rows) => rows.isEmpty
            ? EmptyView(icon: Icons.account_balance_wallet_outlined, title: t.debtorsEmpty)
            : RefreshIndicator(
                onRefresh: () => ref.refresh(debtorsProvider.future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    LineCard(
                      child: Column(
                        children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                            _DebtorRow(
                              debtor: rows[i],
                              overdue: rows[i].oldestDue != null && rows[i].oldestDue!.compareTo(today) < 0,
                              onTap: () async {
                                await pushScreen<void>(context, CustomerDetailScreen(customer: rows[i].customer));
                                ref.invalidate(debtorsProvider);
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DebtorRow extends StatelessWidget {
  const _DebtorRow({required this.debtor, required this.overdue, required this.onTap});

  final Debtor debtor;
  final bool overdue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final Customer customer = debtor.customer;
    return InkWell(
      key: Key('debtors.row.${customer.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            InitialAvatar(customer.initial, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(t.debtorsOpen(debtor.openCount), style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Num(shekel(customer.balance), size: 15, weight: FontWeight.w700, color: StatusTone.debt.fg),
                if (overdue)
                  Text(t.custOverdue, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: StatusTone.error.fg)),
              ],
            ),
            const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
