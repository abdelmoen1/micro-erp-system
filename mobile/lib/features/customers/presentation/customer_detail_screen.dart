import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/customer.dart';
import '../domain/ledger.dart';
import 'record_payment_screen.dart';

/// Everything M-08 shows, loaded together so the numbers agree.
class CustomerLedger {
  const CustomerLedger({required this.summary, required this.debts, required this.payments});

  final CustomerSummary summary;
  final List<OpenDebt> debts;
  final List<PaymentRow> payments;
}

final customerLedgerProvider = FutureProvider.autoDispose.family<CustomerLedger, int>((ref, id) async {
  final repository = ref.watch(customerRepositoryProvider);
  final results = await Future.wait([repository.summary(id), repository.openDebts(id), repository.payments(id)]);
  return CustomerLedger(
    summary: results[0] as CustomerSummary,
    debts: results[1] as List<OpenDebt>,
    payments: results[2] as List<PaymentRow>,
  );
});

/// SCR-M-08 · customer detail: remaining, overdue, open debts and the latest payments (US-0705).
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final ledger = ref.watch(customerLedgerProvider(customer.id));

    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: ledger.when(
        loading: () => const LoadingView(),
        error: (_, _) =>
            ErrorView(message: t.custDetailError, onRetry: () => ref.invalidate(customerLedgerProvider(customer.id))),
        data: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(customerLedgerProvider(customer.id).future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              if (!customer.isActive) ...[
                ToneCard(tone: StatusTone.voided, icon: Icons.block_rounded, title: t.custInactiveNote),
                const SizedBox(height: 12),
              ],
              _BalanceCard(customer: customer, summary: data.summary),
              const SizedBox(height: 18),
              GroupLabel(t.custOpenDebts),
              const SizedBox(height: 8),
              if (data.debts.isEmpty)
                Text(t.custNoOpenDebts, style: const TextStyle(color: HisbahColors.inkMuted))
              else
                LineCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.debts.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                        _DebtRow(debt: data.debts[i]),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              GroupLabel(t.custRecentPayments),
              const SizedBox(height: 8),
              if (data.payments.isEmpty)
                Text(t.custNoPayments, style: const TextStyle(color: HisbahColors.inkMuted))
              else
                LineCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.payments.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                        _PaymentRow(payment: data.payments[i]),
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

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.customer, required this.summary});

  final Customer customer;
  final CustomerSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final limit = summary.creditLimit;
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.custRemaining,
              style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted, fontWeight: FontWeight.w600),
            ),
            MoneyText(
              summary.remaining.toApi(),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: StatusTone.debt.fg),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (summary.overdue.isPositive)
                  _Chip(text: t.custOverdueAmount(formatShekel(summary.overdue.toApi())), tone: StatusTone.error),
                _Chip(
                  text: limit == null ? t.custNoLimit : t.custLimit(formatShekel(limit.toApi())),
                  tone: StatusTone.neutral,
                ),
                _Chip(text: customer.phoneDisplay, tone: StatusTone.neutral),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('customer.pay'),
              onPressed: summary.remaining.isPositive
                  ? () async {
                      final paid = await Navigator.of(context, rootNavigator: true).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => RecordPaymentScreen(customer: customer, remaining: summary.remaining),
                        ),
                      );
                      if (paid == true) ref.invalidate(customerLedgerProvider(customer.id));
                    }
                  : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
              child: Text(t.custRecordPayment),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.tone});

  final String text;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone.fg),
    ),
  );
}

final _date = DateFormat('dd/MM/yyyy', 'en');
final _dateTime = DateFormat('dd/MM · HH:mm', 'en');

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt});

  final OpenDebt debt;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final overdue = debt.isOverdue(DateTime.now());
    final due = debt.dueDate;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debt.isOpening ? t.custDebtOpening : t.custDebtSale(debt.invoiceId ?? 0),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  due == null ? t.custNoDue : t.custDue(isolateLtr(_date.format(due))),
                  style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(debt.remaining.toApi(), style: const TextStyle(fontWeight: FontWeight.w700)),
              _Chip(
                text: overdue ? t.custOverdue : t.custStatusOpen,
                tone: overdue ? StatusTone.error : StatusTone.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final PaymentRow payment;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final at = payment.paidAt;
    return Opacity(
      opacity: payment.reversed ? 0.7 : 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LtrValue(
                    at == null ? '—' : _dateTime.format(at),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    payment.reversed
                        ? t.custReversed
                        : [payment.by, methodLabel(t, payment.method)].whereType<String>().join(' · '),
                    style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
            MoneyText(
              payment.amount.toApi(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: StatusTone.success.fg,
                decoration: payment.reversed ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
