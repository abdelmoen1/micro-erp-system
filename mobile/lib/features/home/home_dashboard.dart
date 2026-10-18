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
class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 64), child: LoadingView()),
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
            first: _StatTile(icon: Icons.payments_outlined, label: t.homeCash, amount: today.cashSales),
            second: _StatTile(
              icon: Icons.schedule_rounded,
              label: t.homeCredit,
              amount: today.creditSales,
              tone: StatusTone.info,
            ),
          ),
          const SizedBox(height: 12),
          _StatRow(
            first: _StatTile(icon: Icons.savings_outlined, label: t.homeCollectedToday, amount: today.collectedToday),
            second: _StatTile(
              key: const Key('home.outstanding'),
              icon: Icons.account_balance_wallet_outlined,
              label: t.homeOutstandingDebts,
              amount: today.outstandingDebt,
              note: t.homeCustomersWithDebt(today.customersWithDebt),
              tone: StatusTone.error,
            ),
          ),
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

/// Teal hero: greeting, date and today's sales total.
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
          colors: [HisbahColors.primary, HisbahColors.primaryPressed],
        ),
        boxShadow: const [BoxShadow(color: Color(0x33176D73), blurRadius: 18, offset: Offset(0, 8))],
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
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x1FFFFFFF), width: 22)),
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
  const _StatTile({super.key, required this.icon, required this.label, required this.amount, this.note, this.tone});

  final IconData icon;
  final String label;
  final String amount;
  final String? note;

  /// Null uses the brand teal.
  final StatusTone? tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone?.fg ?? HisbahColors.primary;
    final bg = tone?.bg ?? HisbahColors.primaryTint;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HisbahColors.surface,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        border: Border.all(color: HisbahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: _Amount(amount, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: HisbahColors.ink)),
          ),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600)),
          ],
        ],
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
    child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HisbahColors.ink)),
  );
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    void open(AppTab tab) => StatefulNavigationShell.of(context).goBranch(tab.index);

    return Row(
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
        const SizedBox(width: 10),
        Expanded(
          child: _Shortcut(
            key: const Key('home.shortcut.customers'),
            icon: Icons.group_outlined,
            label: t.tabCustomers,
            onTap: () => open(AppTab.customers),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Shortcut(
            key: const Key('home.shortcut.products'),
            icon: Icons.inventory_2_outlined,
            label: t.tabProducts,
            onTap: () => open(AppTab.products),
          ),
        ),
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

    return Padding(
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
    );
  }
}
