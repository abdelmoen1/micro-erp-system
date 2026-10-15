import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/dashed_card.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session_controller.dart';
import '../auth/domain/app_user.dart';
import 'app_shell.dart';

/// Root screen of each tab: header (title, store, connection) and the tab content.
/// Feature content arrives in later sprints (designed in S4 / US-1508, POS built in S5);
/// S1 only proves the shell, navigation and session.
class TabRootScreen extends ConsumerWidget {
  const TabRootScreen({super.key, required this.tab});

  final AppTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final storeName = session is SignedIn ? session.user.storeName : '';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
          children: [
            _Header(title: tab.label(t), storeName: storeName),
            const SizedBox(height: 14),
            if (tab == AppTab.more) const _MoreTab() else _Placeholder(tab: tab),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.title, required this.storeName});

  final String title;
  final String storeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final online = ref.watch(serverReachableProvider);
    final fg = online ? HisbahColors.primary : StatusTone.offline.fg;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Icon(online ? Icons.check_rounded : Icons.wifi_off_rounded, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                online ? t.online : t.offline,
                style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600),
              ),
            ],
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
      constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.5),
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
                    // Emails are LTR runs inside the RTL card.
                    Text(
                      user.email,
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
        const SizedBox(height: 14),
        Text(t.moreNote, style: const TextStyle(fontSize: 13, height: 1.6, color: HisbahColors.inkMuted)),
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
    if (confirmed == true) await ref.read(sessionProvider.notifier).logout();
  }
}
