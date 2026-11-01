import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/ltr_value.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session_controller.dart';
import '../goods/presentation/purchases_screen.dart';
import '../goods/presentation/supplier_screens.dart' show SuppliersScreen;
import '../more/presentation/more_widgets.dart' show pushScreen;
import '../products/presentation/stock_lists_screen.dart';
import '../returns/presentation/period_list.dart';
import '../returns/presentation/returns_screen.dart';
import '../sale/presentation/sale_detail_screen.dart';
import '../sale/presentation/sales_history_screen.dart';
import '../shell/app_shell.dart';
import 'dashboard.dart';
import 'drilldown_screens.dart';

/// Home tab (owner / manager landing): today's sales, debts, shortcuts and latest invoices.
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Padding(padding: EdgeInsets.only(top: 8), child: LoadingView.detail(padding: EdgeInsets.zero)),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: ErrorView(message: t.homeLoadError, onRetry: () => ref.invalidate(dashboardProvider)),
      ),
      data: (today) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayCard(today: today),
          const SizedBox(height: 14),
          _StatRow(
            first: _StatTile(
              key: const Key('home.cash'),
              icon: Icons.payments_outlined,
              label: t.homeCash,
              amount: today.cashSales,
              onTap: () => _openSales(context, SalesType.cash),
            ),
            second: _StatTile(
              key: const Key('home.credit'),
              icon: Icons.schedule_rounded,
              label: t.homeCredit,
              amount: today.creditSales,
              tone: StatusTone.info,
              onTap: () => _openSales(context, SalesType.onCredit),
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            first: _StatTile(
              key: const Key('home.collected'),
              icon: Icons.savings_outlined,
              label: t.homeCollectedToday,
              amount: today.collectedTotal,
              note: t.homeCollectionsSplit(formatShekel(today.collectedAtSale), formatShekel(today.debtRepayments)),
              onTap: () => pushScreen<void>(context, CollectionsScreen(today: today)),
            ),
            second: _StatTile(
              key: const Key('home.outstanding'),
              icon: Icons.account_balance_wallet_outlined,
              label: t.homeOutstandingDebts,
              amount: today.outstandingDebt,
              note: t.homeCustomersWithDebt(today.customersWithDebt),
              tone: StatusTone.error,
              onTap: () => pushScreen<void>(context, const DebtorsScreen()),
            ),
          ),
          if (today.purchasesTotal != null) ...[
            const SizedBox(height: 12),
            _StatRow(
              first: _StatTile(
                key: const Key('home.purchases'),
                icon: Icons.local_shipping_outlined,
                label: t.homePurchasesToday,
                amount: today.purchasesTotal!,
                note: t.homeOwedSuppliers(formatShekel(today.owedToSuppliers)),
                tone: StatusTone.warning,
                onTap: () => pushScreen<void>(context, const PurchasesScreen(period: ListPeriod.today)),
              ),
              second: _StatTile(
                key: const Key('home.returns'),
                icon: Icons.assignment_return_outlined,
                label: t.homeReturnsToday,
                amount: today.returnsTotal,
                note: t.homeReturnsCount(today.returnsCount),
                tone: StatusTone.warning,
                onTap: () => pushScreen<void>(context, const ReturnsScreen(period: ListPeriod.today)),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _SectionTitle(t.homeAttention),
          const SizedBox(height: 10),
          _Attention(today: today),
          const SizedBox(height: 22),
          _SectionTitle(t.homeShortcuts),
          const SizedBox(height: 10),
          const _Shortcuts(),
          const SizedBox(height: 22),
          _SectionTitle(t.homeRecentInvoices),
          const SizedBox(height: 10),
          _RecentInvoices(invoices: today.recentInvoices),
        ],
      ),
    );
  }
}

/// Today's sales as the figure counts them: active invoices of [type], or all of them.
void _openSales(BuildContext context, SalesType type) =>
    pushScreen<void>(context, SalesHistoryScreen(type: type, activeOnly: true));

/// Teal hero: greeting, date and today's sales total. The whole card opens today's invoices.
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
    const onTealMuted = Color(0xCCFFFFFF);

    return Container(
      key: const Key('home.today'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HisbahRadius.card + 4),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          // Secondary into brand teal: the same identity, lighter than the old pressed-teal end.
          colors: [HisbahColors.secondary, HisbahColors.primary],
        ),
        boxShadow: const [BoxShadow(color: Color(0x29176D73), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Stack(
        children: [
          // Decorative rings in the top corner.
          PositionedDirectional(
            top: -40,
            end: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x1FFFFFFF), width: 22),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -24,
            end: 70,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14FFFFFF)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty)
                  Text(
                    t.homeGreeting(name),
                    style: const TextStyle(color: onTeal, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                Text(
                  DateFormat.MMMMEEEEd(locale).format(DateTime.now()),
                  style: const TextStyle(color: onTealMuted, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Text(t.homeTodaySales, style: const TextStyle(color: onTealMuted, fontSize: 14)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: _Amount(
                    today.totalSales,
                    key: const Key('home.totalSales'),
                    style: const TextStyle(color: onTeal, fontSize: 34, fontWeight: FontWeight.w800, height: 1.2),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(999)),
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
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('home.today.open'),
                onTap: () => _openSales(context, SalesType.all),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// M-10 «يحتاج انتباهك»: overdue and due-today debts, low and negative stock (US-0801 AC3).
class _Attention extends StatelessWidget {
  const _Attention({required this.today});

  final TodayDashboard today;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    if (!today.needsAttention) {
      return Text(
        t.homeAllClear,
        key: const Key('home.allClear'),
        style: const TextStyle(color: HisbahColors.inkMuted),
      );
    }
    final rows = [
      if (today.overdueCount > 0)
        (
          Icons.schedule_rounded,
          t.homeOverdueAlert(today.overdueCount),
          formatShekel(today.overdueAmount),
          StatusTone.error,
          const DebtorsScreen() as Widget,
        ),
      if (today.dueTodayCount > 0)
        (Icons.event_outlined, t.homeDueTodayAlert(today.dueTodayCount), null, StatusTone.info, const DebtorsScreen() as Widget),
      if (today.lowStockCount > 0)
        (Icons.inventory_2_outlined, t.homeLowStockAlert(today.lowStockCount), null, StatusTone.warning, const LowStockScreen() as Widget),
      if (today.negativeStockCount > 0)
        (Icons.warning_amber_rounded, t.homeNegativeAlert(today.negativeStockCount), null, StatusTone.error, const NegativeStockScreen() as Widget),
    ];
    return DecoratedBox(
      key: const Key('home.attention'),
      decoration: BoxDecoration(
        color: HisbahColors.surface,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        border: Border.all(color: HisbahColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            InkWell(
              key: Key('home.attention.$i'),
              onTap: () => pushScreen<void>(context, rows[i].$5),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: i == 0 ? null : const Border(top: BorderSide(color: HisbahColors.border)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: rows[i].$4.bg, borderRadius: BorderRadius.circular(10)),
                      child: Icon(rows[i].$1, size: 20, color: rows[i].$4.fg),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(rows[i].$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                    if (rows[i].$3 != null)
                      LtrValue(
                        rows[i].$3!,
                        style: TextStyle(fontWeight: FontWeight.w700, color: rows[i].$4.fg),
                      ),
                    const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
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

class _StatTile extends StatelessWidget {
  const _StatTile({super.key, required this.icon, required this.label, required this.amount, required this.onTap, this.note, this.tone});

  final IconData icon;
  final String label;
  final String amount;
  final String? note;
  final VoidCallback onTap;

  /// Null uses the brand teal.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone?.fg ?? HisbahColors.primary;
    final bg = tone?.bg ?? HisbahColors.primaryTint;

    return Material(
      color: HisbahColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        side: const BorderSide(color: HisbahColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, size: 20, color: fg),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_left_rounded, size: 20, color: HisbahColors.inkSubtle),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: _Amount(
                  amount,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: HisbahColors.ink),
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 2),
                Text(
                  note!,
                  style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Amount with the shekel sign, laid out LTR inside the RTL screen ("1,250.00 ₪").
class _Amount extends StatelessWidget {
  const _Amount(this.amount, {super.key, required this.style});

  final String amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(
    '${formatMoney(amount)} ${AppLocalizations.of(context).currencySymbol}',
    textDirection: TextDirection.ltr,
    maxLines: 1,
    style: style,
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HisbahColors.ink),
    ),
  );
}

/// The accounting registers one press from Home. Selling stays on the bar's centre button; costs
/// (suppliers, purchases) stay with the owner and managers.
class _Shortcuts extends ConsumerWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final manager = session is SignedIn && session.user.canOverride;
    void open(AppTab tab) => StatefulNavigationShell.of(context).goBranch(tab.index);

    final tiles = [
      if (manager)
        _Shortcut(
          key: const Key('home.shortcut.suppliers'),
          icon: Icons.local_shipping_outlined,
          label: t.suppliersTitle,
          filled: true,
          onTap: () => pushScreen<void>(context, const SuppliersScreen()),
        ),
      _Shortcut(
        key: const Key('home.shortcut.customers'),
        icon: Icons.group_outlined,
        label: t.tabCustomers,
        onTap: () => open(AppTab.customers),
      ),
      _Shortcut(
        key: const Key('home.shortcut.products'),
        icon: Icons.inventory_2_outlined,
        label: t.tabProducts,
        onTap: () => open(AppTab.products),
      ),
      _Shortcut(
        key: const Key('home.shortcut.sales'),
        icon: Icons.receipt_long_outlined,
        label: t.salesTitle,
        onTap: () => pushScreen<void>(context, const SalesHistoryScreen()),
      ),
      if (manager)
        _Shortcut(
          key: const Key('home.shortcut.purchases'),
          icon: Icons.shopping_bag_outlined,
          label: t.purchasesTitle,
          onTap: () => pushScreen<void>(context, const PurchasesScreen()),
        ),
      if (manager)
        _Shortcut(
          key: const Key('home.shortcut.returns'),
          icon: Icons.assignment_return_outlined,
          label: t.returnsTitle,
          onTap: () => pushScreen<void>(context, const ReturnsScreen()),
        ),
    ];

    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += 3) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var i = row; i < row + 3; i++) ...[
                if (i > row) const SizedBox(width: 10),
                Expanded(child: i < tiles.length ? tiles[i] : const SizedBox.shrink()),
              ],
            ],
          ),
        ],
      ],
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
    final fg = filled ? HisbahColors.onPrimary : HisbahColors.primary;

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
        elevation: filled ? 0 : 1,
        shadowColor: HisbahColors.shadow,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(HisbahRadius.button),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 26, color: fg),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 36, color: HisbahColors.inkSubtle),
                  const SizedBox(height: 10),
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
    final tone = invoice.onCredit ? StatusTone.info : null;
    final fg = tone?.fg ?? HisbahColors.primary;
    final bg = tone?.bg ?? HisbahColors.primaryTint;
    final time = invoice.createdAt == null ? null : DateFormat.Hm('en').format(invoice.createdAt!);

    return InkWell(
      key: Key('home.invoice.${invoice.id}'),
      onTap: () => pushScreen<void>(context, SaleDetailScreen(saleId: invoice.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: bg,
              child: Icon(invoice.onCredit ? Icons.schedule_rounded : Icons.payments_outlined, size: 20, color: fg),
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
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [invoice.onCredit ? t.homeCredit : t.homeCash, ?time].join(' · '),
                    style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Amount(invoice.amount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
