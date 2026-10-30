import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/dashed_card.dart';
import '../../core/widgets/hisbah_logo.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session_controller.dart';
import '../auth/domain/app_user.dart';
import '../customers/presentation/customers_screen.dart';
import '../home/dashboard.dart';
import '../home/home_dashboard.dart';
import '../auth/presentation/subscription_expired_screen.dart' show externalLinkLauncherProvider;
import '../more/presentation/change_password_screen.dart';
import '../more/presentation/change_phone_screen.dart';
import '../more/presentation/more_widgets.dart';
import '../more/presentation/staff_screen.dart';
import '../more/presentation/store_settings_screen.dart';
import '../more/presentation/support_screen.dart';
import '../sync/application/sync_engine.dart';
import '../sync/presentation/sync_screen.dart';
import '../goods/presentation/supplier_screens.dart';
import '../guide/usage_guide.dart';
import '../products/presentation/stock_lists_screen.dart';
import '../sale/presentation/sale_widgets.dart' show GroupLabel, LineCard;
import '../sale/presentation/sales_history_screen.dart';
import '../products/presentation/products_screen.dart';
import '../sale/presentation/cart_screen.dart';
import 'app_shell.dart';

/// Root screen of each tab: header (title, store, connection) and the tab content.
/// Home shows today's dashboard; the other tabs' content arrives in later sprints
/// (POS built in S5).
class TabRootScreen extends ConsumerWidget {
  const TabRootScreen({super.key, required this.tab});

  final AppTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // بيع is the M-02 cart: its own layout (fixed actions and total bar around the line list).
    if (tab == AppTab.pos) return const CartScreen();
    // S3: M-07 customers and M-11 products have their own search headers and lists.
    if (tab == AppTab.customers) return const CustomersScreen();
    if (tab == AppTab.products) return const ProductsScreen();

    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final storeName = session is SignedIn ? session.user.storeName : '';

    final list = ListView(
      // Always scrollable so pull-to-refresh works on a short Home.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
      children: [
        TabHeader(title: tab.label(t), storeName: storeName),
        const SizedBox(height: 14),
        if (tab == AppTab.home) const GuideCard(),
        switch (tab) {
          AppTab.home => const HomeDashboard(),
          AppTab.more => const _MoreTab(),
          _ => _Placeholder(tab: tab),
        },
      ],
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: tab == AppTab.home
            ? RefreshIndicator(onRefresh: () => ref.refresh(dashboardProvider.future), child: list)
            : list,
      ),
    );
  }
}

class TabHeader extends ConsumerWidget {
  const TabHeader({super.key, required this.title, required this.storeName});

  final String title;
  final String storeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final online = ref.watch(serverReachableProvider);
    final sync = ref.watch(syncEngineProvider);
    final fg = online ? HisbahColors.primary : StatusTone.offline.fg;
    // FR-67 / UI-AC-13: synced, synchronizing or pending (n), always visible.
    final (label, icon) = !online
        ? (sync.pending > 0 ? t.syncOfflinePending(sync.pending) : t.offline, Icons.wifi_off_rounded)
        : sync.syncing && sync.pending > 0
        ? (t.syncSyncing, Icons.sync_rounded)
        : sync.pending > 0
        ? (t.syncPending(sync.pending), Icons.schedule_rounded)
        : (sync.available ? t.syncSynced : t.online, Icons.check_rounded);

    return Row(
      children: [
        const ExcludeSemantics(child: HisbahMarkTile(size: 40)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Semantic header so screen readers announce the tab title.
              Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              if (storeName.isNotEmpty)
                Text(storeName, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Shrinks before the title does on a narrow phone; the label ellipsizes.
        Flexible(
          child: Semantics(
            button: sync.available,
            child: InkWell(
              onTap: sync.available ? () => openSyncScreen(context) : null,
              borderRadius: BorderRadius.circular(999),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    key: const Key('header.connection'),
                    constraints: const BoxConstraints(minHeight: 30),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: online ? HisbahColors.primaryTint : StatusTone.offline.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: fg),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sync.review > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t.syncNeedsReview(sync.review),
                        key: const Key('header.review'),
                        style: TextStyle(fontSize: 12, color: StatusTone.warning.fg, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashed frame for screens that are not designed or built yet (hi-fi board).
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tab});

  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (id, title, body) = switch (tab) {
      AppTab.home => ('SCR-M-10', t.placeholderHome, t.placeholderBody),
      AppTab.customers => ('SCR-M-07', t.placeholderCustomers, t.placeholderBody),
      AppTab.products => ('SCR-M-11', t.placeholderProducts, t.placeholderBody),
      AppTab.pos || AppTab.more => ('SCR-M-02', t.placeholderPos, t.placeholderPosBody),
    };
    return ConstrainedBox(
      // On بيع the scan card (T-1301-7) sits below, so the frame is shorter there and the card
      // stays above the bottom bar at 360 × 760 (S2 hi-fi A).
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * (tab == AppTab.pos ? 0.36 : 0.5)),
      child: DashedCard(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                id,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: HisbahColors.inkMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    if (session is! SignedIn) return const SizedBox.shrink();
    final user = session.user;
    final role = switch (user.role) {
      UserRole.owner => t.roleOwner,
      UserRole.manager => t.roleManager,
      UserRole.employee => t.roleEmployee,
    };
    final initial = user.name.trim().isEmpty ? '؟' : user.name.trim().characters.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HisbahColors.surface,
            borderRadius: BorderRadius.circular(HisbahRadius.card),
            border: Border.all(color: HisbahColors.border),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: HisbahColors.primaryTint,
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: HisbahColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    // The number is an LTR run inside the RTL card.
                    Text(
                      user.phone ?? '',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                      decoration: BoxDecoration(
                        color: HisbahColors.ground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: HisbahColors.border),
                      ),
                      child: Text(
                        user.storeName.isEmpty ? role : '$role · ${user.storeName}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // What the web back office offers, by role: the owner runs the store and its staff,
        // owners and managers watch the stock, everyone sees the sales and their own account.
        if (user.role == UserRole.owner)
          _MoreSection(
            title: t.moreSectionStore,
            tiles: [
              MoreTile(
                key: const Key('more.staff'),
                icon: Icons.groups_outlined,
                title: t.moreStaff,
                subtitle: t.moreStaffSub,
                onTap: () => pushScreen<void>(context, const StaffScreen()),
              ),
              MoreTile(
                key: const Key('more.store'),
                icon: Icons.storefront_outlined,
                title: t.moreStoreInfo,
                subtitle: t.moreStoreInfoSub,
                onTap: () => pushScreen<void>(context, const StoreSettingsScreen()),
              ),
            ],
          ),
        _MoreSection(
          title: t.moreSectionStock,
          tiles: [
            MoreTile(
              key: const Key('more.lowStock'),
              icon: Icons.trending_down_rounded,
              title: t.moreLowStock,
              subtitle: t.moreLowStockSub,
              onTap: () => pushScreen<void>(context, const LowStockScreen()),
            ),
            if (user.canOverride)
              MoreTile(
                key: const Key('more.suppliers'),
                icon: Icons.local_shipping_outlined,
                title: t.suppliersTitle,
                subtitle: t.suppliersSub,
                onTap: () => pushScreen<void>(context, const SuppliersScreen()),
              ),
            if (user.canOverride)
              MoreTile(
                key: const Key('more.negative'),
                icon: Icons.report_gmailerrorred_outlined,
                title: t.moreNegative,
                subtitle: t.moreNegativeSub,
                onTap: () => pushScreen<void>(context, const NegativeStockScreen()),
              ),
          ],
        ),
        _MoreSection(
          title: t.moreSectionSales,
          tiles: [
            MoreTile(
              key: const Key('more.sales'),
              icon: Icons.receipt_long_outlined,
              title: t.moreSalesHistory,
              subtitle: t.moreSalesHistorySub,
              onTap: () => pushScreen<void>(context, const SalesHistoryScreen()),
            ),
          ],
        ),
        _MoreSection(
          title: t.moreSectionSettings,
          tiles: [
            const _SubscriptionTile(),
            MoreTile(
              key: const Key('more.phone'),
              icon: Icons.phone_iphone_rounded,
              title: t.morePhone,
              // An older e-mail account is asked to add its number.
              subtitle: (user.phone ?? '').isEmpty ? t.morePhoneAdd : user.phone!,
              onTap: () => pushScreen<void>(context, const ChangePhoneScreen()),
            ),
            MoreTile(
              key: const Key('more.password'),
              icon: Icons.lock_reset_rounded,
              title: t.morePassword,
              subtitle: t.morePasswordSub,
              onTap: () => pushScreen<void>(context, const ChangePasswordScreen()),
            ),
            MoreTile(
              key: const Key('more.guide'),
              icon: Icons.school_outlined,
              title: t.guideTitle,
              subtitle: t.moreGuideSub,
              onTap: () => openUsageGuide(context),
            ),
            MoreTile(
              key: const Key('more.support'),
              icon: Icons.support_agent_rounded,
              title: t.moreSupport,
              subtitle: t.moreSupportSub,
              onTap: () => pushScreen<void>(context, const SupportScreen()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const Key('more.logout'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HisbahColors.danger,
            backgroundColor: HisbahColors.surface,
            side: const BorderSide(color: HisbahColors.dangerBorder, width: 1.5),
          ),
          icon: const Icon(Icons.logout_rounded, size: 20),
          label: Text(t.logout),
          onPressed: () => _confirmLogout(context, ref),
        ),
      ],
    );
  }

  /// Logout confirm sheet (hi-fi board): staying is the primary, safe choice.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final t = AppLocalizations.of(context);
    // R2: unsynced sales and payments belong to this account; another one must never send them.
    final pending = ref.read(syncEngineProvider).pending;
    if (pending > 0) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.logoutPendingTitle(pending),
                key: const Key('logout.pending'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(t.logoutPendingBody, style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted)),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  openSyncScreen(context);
                },
                child: Text(t.syncNow),
              ),
            ],
          ),
        ),
      );
      return;
    }
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      // Above the shell, so the bottom bar never covers the sheet.
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.logoutConfirmTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Text(t.logoutConfirmBody, style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted)),
              const SizedBox(height: 14),
              FilledButton(
                key: const Key('logout.stay'),
                onPressed: () => Navigator.pop(sheet, false),
                child: Text(t.stay),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                key: const Key('logout.confirm'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HisbahColors.danger,
                  side: const BorderSide(color: HisbahColors.dangerBorder, width: 1.5),
                ),
                onPressed: () => Navigator.pop(sheet, true),
                child: Text(t.logout),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    // The next account on this phone starts from an empty cache.
    final store = ref.read(offlineStoreProvider);
    if (await store.available) await store.clearCatalog();
    await ref.read(sessionProvider.notifier).logout();
  }
}

/// A titled group of «More» entries in one card.
class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.tiles});

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(title),
        const SizedBox(height: 8),
        LineCard(
          child: Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                tiles[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

final _subscriptionProvider = FutureProvider.autoDispose<SubscriptionSummary>(
  (ref) => ref.watch(authRepositoryProvider).subscription(),
);

final _day = DateFormat('dd/MM/yyyy', 'en');

/// Where the store's subscription stands (trial or paid, until when), and a WhatsApp line to the
/// Hisbah team when the platform has a support number.
class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final summary = ref.watch(_subscriptionProvider).value;
    final session = ref.watch(sessionProvider);
    final storeName = session is SignedIn ? session.user.storeName : '';
    final status = switch (summary) {
      null => null,
      SubscriptionSummary(state: 'trial', :final trialEndsAt?) => t.moreSubTrialUntil(
        _day.format(trialEndsAt.toLocal()),
      ),
      SubscriptionSummary(state: 'active', :final subscriptionExpiresAt?) => t.moreSubActiveUntil(
        _day.format(subscriptionExpiresAt.toLocal()),
      ),
      _ => t.moreSubActive,
    };
    final number = summary?.supportWhatsapp;
    return MoreTile(
      key: const Key('more.subscription'),
      icon: Icons.workspace_premium_outlined,
      title: t.moreSubscription,
      subtitle: [?status, if (number != null) t.moreSubContact].join('\n'),
      onTap: number == null
          ? null
          : () => ref.read(externalLinkLauncherProvider)(
              Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(t.moreSubWhatsappText(storeName))}'),
            ),
    );
  }
}
