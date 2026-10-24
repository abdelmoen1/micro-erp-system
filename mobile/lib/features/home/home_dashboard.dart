import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session_controller.dart';
import '../shell/app_shell.dart';
import 'dashboard.dart';

/// Home tab (owner / manager landing): today's sales, debts, shortcuts and latest invoices.
///
/// Colour carries one meaning on this screen: a filled teal chip is money already in the till
/// (cash, collections); an outlined chip is money still owed (credit sales, open debt). Red is
/// not used here: the dashboard has no overdue data.
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const _HomeSkeleton(),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ErrorView(message: t.homeLoadError, onRetry: () => ref.invalidate(dashboardProvider)),
      ),
      data: (today) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayCard(today: today),
          const SizedBox(height: 12),
          // Start column (RTL: right) is money in hand, end column is money owed.
          _StatRow(
            first: _StatTile(icon: Icons.payments_outlined, label: t.homeCash, amount: today.cashSales),
            second: _StatTile(
              icon: Icons.schedule_rounded,
              label: t.homeCredit,
              amount: today.creditSales,
              owed: true,
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            first: _StatTile(icon: Icons.call_received_rounded, label: t.homeCollectedToday, amount: today.collectedToday),
            second: _StatTile(
              key: const Key('home.outstanding'),
              icon: Icons.account_balance_wallet_outlined,
              label: t.homeOutstandingDebts,
              amount: today.outstandingDebt,
              note: t.homeCustomersWithDebt(today.customersWithDebt),
              owed: true,
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(t.homeShortcuts),
          const SizedBox(height: 12),
          const _Shortcuts(),
          const SizedBox(height: 24),
          _SectionTitle(t.homeRecentInvoices),
          const SizedBox(height: 12),
          _RecentInvoices(invoices: today.recentInvoices),
        ],
      ),
    );
  }
}

/// Flat deep-teal hero: greeting, date and today's sales total. The total is closed with the
/// ledger double rule from the brand mark.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.today});

  final TodayDashboard today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final name = session is SignedIn ? session.user.name.trim() : '';
    final locale = Localizations.localeOf(context).toLanguageTag();
    const onTeal = HisbahColors.onPrimary;
    const onTealMuted = HisbahColors.onPrimaryMuted;

    return Container(
      key: const Key('home.today'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: HisbahColors.primary,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (name.isNotEmpty)
            Text(
              t.homeGreeting(name),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: onTeal, fontSize: 16, height: 1.4, fontWeight: FontWeight.w700),
            ),
          Text(
            DateFormat.MMMMEEEEd(locale).format(DateTime.now()),
            style: const TextStyle(color: onTealMuted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Text(t.homeTodaySales, style: const TextStyle(color: onTealMuted, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Amount(
                    today.totalSales,
                    key: const Key('home.totalSales'),
                    style: const TextStyle(color: onTeal, fontSize: 36, fontWeight: FontWeight.w700, height: 1.25),
                  ),
                  const SizedBox(height: 4),
                  const _DoubleRule(color: HisbahColors.onPrimaryLine),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(minHeight: 30),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: HisbahColors.onPrimaryLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 16, color: onTeal),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t.homeInvoicesCount(today.invoicesCount),
                    style: const TextStyle(color: onTeal, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading: the hero and summary tiles as static outlines (no shimmer on low-end phones), so
/// the layout does not jump when the figures arrive.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile() => Expanded(
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          color: HisbahColors.surface,
          borderRadius: BorderRadius.circular(HisbahRadius.card),
          border: Border.all(color: HisbahColors.border),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 196),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HisbahColors.primaryTint,
            borderRadius: BorderRadius.circular(HisbahRadius.card),
          ),
          child: const LoadingView(),
        ),
        const SizedBox(height: 12),
        Row(children: [tile(), const SizedBox(width: 12), tile()]),
        const SizedBox(height: 12),
        Row(children: [tile(), const SizedBox(width: 12), tile()]),
      ],
    );
  }
}

/// Two hairlines under a total: the bookkeeper's sign that the sum is closed.
class _DoubleRule extends StatelessWidget {
  const _DoubleRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(color: color, child: const SizedBox(height: 1.5)),
        const SizedBox(height: 3),
        ColoredBox(color: color, child: const SizedBox(height: 1.5)),
      ],
    ),
  );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    ),
  );
}

/// Icon chip shared by the summary tiles and invoice rows: filled = in hand, outlined = owed.
class _MoneyChip extends StatelessWidget {
  const _MoneyChip({required this.icon, required this.owed, this.size = 32});

  final IconData icon;
  final bool owed;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: owed ? null : HisbahColors.primaryTint,
      borderRadius: BorderRadius.circular(HisbahRadius.chip),
      border: owed ? Border.all(color: HisbahColors.primaryOutline, width: 1.5) : null,
    ),
    child: Icon(icon, size: size * 0.56, color: HisbahColors.primary),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.amount,
    this.note,
    this.owed = false,
  });

  final IconData icon;
  final String label;
  final String amount;
  final String? note;

  /// Money still to be collected (credit, debt): outlined chip instead of filled.
  final bool owed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: HisbahColors.surface,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        border: Border.all(color: HisbahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MoneyChip(icon: icon, owed: owed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.35, color: HisbahColors.inkMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: _Amount(amount, style: const TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: HisbahColors.ink)),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: const TextStyle(fontSize: 12, height: 1.4, color: HisbahColors.inkMuted, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

/// Amount with the shekel sign, laid out LTR inside the RTL screen ("1,250.00 ₪").
/// Tabular figures keep columns of amounts aligned.
class _Amount extends StatelessWidget {
  const _Amount(this.amount, {super.key, required this.style});

  final String amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    '${formatMoney(amount)} ${AppLocalizations.of(context).currencySymbol}',
    textDirection: TextDirection.ltr,
    maxLines: 1,
    style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HisbahColors.ink)),
  );
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void open(AppTab tab) => StatefulNavigationShell.of(context).goBranch(tab.index);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Shortcut(
              key: const Key('home.shortcut.pos'),
              icon: Icons.add_shopping_cart_rounded,
              label: t.homeNewSale,
              filled: true,
              onTap: () => open(AppTab.pos),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Shortcut(
              key: const Key('home.shortcut.customers'),
              icon: Icons.group_outlined,
              label: t.tabCustomers,
              onTap: () => open(AppTab.customers),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Shortcut(
              key: const Key('home.shortcut.products'),
              icon: Icons.inventory_2_outlined,
              label: t.tabProducts,
              onTap: () => open(AppTab.products),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({super.key, required this.icon, required this.label, required this.onTap, this.filled = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final iconColor = filled ? HisbahColors.onPrimary : HisbahColors.primary;
    final textColor = filled ? HisbahColors.onPrimary : HisbahColors.ink;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: filled ? HisbahColors.primary : HisbahColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HisbahRadius.button),
          side: filled ? BorderSide.none : const BorderSide(color: HisbahColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HisbahRadius.button),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24, color: iconColor),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentInvoices extends StatelessWidget {
  const _RecentInvoices({required this.invoices});

  final List<RecentInvoice> invoices;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: HisbahColors.surface,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        border: Border.all(color: HisbahColors.border),
      ),
      child: invoices.isEmpty
          ? Padding(
              key: const Key('home.noInvoices'),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const _MoneyChip(icon: Icons.receipt_long_outlined, owed: false, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    t.homeNoInvoices,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.homeNoInvoicesBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final (i, invoice) in invoices.take(5).indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: HisbahColors.border),
                  _InvoiceRow(invoice: invoice),
                ],
              ],
            ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final RecentInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final time = invoice.createdAt == null ? null : DateFormat.Hm('en').format(invoice.createdAt!);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _MoneyChip(
              icon: invoice.onCredit ? Icons.schedule_rounded : Icons.payments_outlined,
              owed: invoice.onCredit,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.customerName ?? t.homeWalkIn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [invoice.onCredit ? t.homeCredit : t.homeCash, ?time].join(' · '),
                    style: const TextStyle(fontSize: 12, height: 1.4, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Amount(invoice.amount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HisbahColors.ink)),
          ],
        ),
      ),
    );
  }
}
