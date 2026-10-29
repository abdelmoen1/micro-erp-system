import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_store.dart';
import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../sync/application/sync_engine.dart';
import '../sync/presentation/sync_screen.dart';

/// The five R1 tabs. The bar shows them in enum order; RTL places the first at the right edge:
/// الرئيسية · الزبائن · بيع (+) · المنتجات · المزيد — بيع is column 3 of 5, the exact centre
/// (TL change to US-1505, 2026-10-15).
enum AppTab {
  home('/home', Icons.home_outlined),
  customers('/customers', Icons.group_outlined),
  pos('/pos', Icons.add),
  products('/products', Icons.inventory_2_outlined),
  more('/more', Icons.short_text_rounded);

  const AppTab(this.path, this.icon);

  final String path;
  final IconData icon;

  String label(AppLocalizations t) => switch (this) {
    AppTab.home => t.tabHome,
    AppTab.pos => t.tabPos,
    AppTab.customers => t.tabCustomers,
    AppTab.products => t.tabProducts,
    AppTab.more => t.tabMore,
  };
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banner = OfflineBanner.shows(ref);
    return Scaffold(
      // The body runs under the raised centre button; Scaffold pads it by the bar height.
      extendBody: true,
      body: _SyncOnResume(
        child: Column(
          children: [
            if (banner) const OfflineBanner(),
            Expanded(
              // The body's own context: its MediaQuery bottom padding includes the bar height
              // (extendBody), so the end of every tab can scroll clear of the bar.
              child: Builder(
                builder: (body) => MediaQuery.removePadding(context: body, removeTop: banner, child: shell),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HisbahNavBar(
        current: AppTab.values[shell.currentIndex],
        // Re-tapping the active tab returns to its root (ia.md §1).
        onSelect: (tab) => shell.goBranch(tab.index, initialLocation: tab.index == shell.currentIndex),
      ),
    );
  }
}

/// Back in the foreground after an outage or a night: send what waits and refresh the cache.
class _SyncOnResume extends ConsumerStatefulWidget {
  const _SyncOnResume({required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncOnResume> createState() => _SyncOnResumeState();
}

class _SyncOnResumeState extends ConsumerState<_SyncOnResume> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onResume: () => ref.read(syncEngineProvider.notifier).kick(refresh: true));
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Bottom navigation from the hi-fi board. Side tabs: teal + 700 + indicator when active.
/// Centre بيع: a raised + button, 58 dp solid teal on other tabs; 54 dp outline when it is the
/// current tab, so the screen's own primary action stays the only filled control.
class HisbahNavBar extends StatelessWidget {
  const HisbahNavBar({super.key, required this.current, required this.onSelect});

  /// How far the centre button rises above the bar surface (hi-fi: margin-top −26).
  static const raise = 26.0;

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // The bar surface starts [raise] below the top: the centre circle rises above it while
    // staying inside this widget's bounds, so its upper half is still tappable.
    return Stack(
      children: [
        const Positioned.fill(
          top: raise,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: HisbahColors.surface,
              boxShadow: [BoxShadow(color: HisbahColors.border, offset: Offset(0, -1))],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final tab in AppTab.values)
                  Expanded(
                    child: tab == AppTab.pos
                        ? _SellButton(
                            key: const Key('nav.pos'),
                            current: current == tab,
                            label: tab.label(t),
                            a11y: current == tab ? t.sellCurrentA11y : t.sellA11y,
                            onTap: () => onSelect(tab),
                          )
                        : _SideTab(
                            key: Key('nav.${tab.name}'),
                            icon: tab.icon,
                            label: tab.label(t),
                            active: current == tab,
                            onTap: () => onSelect(tab),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SideTab extends StatelessWidget {
  const _SideTab({super.key, required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? HisbahColors.primary : HisbahColors.inkSubtle;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? HisbahColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellButton extends StatelessWidget {
  const _SellButton({super.key, required this.current, required this.label, required this.a11y, required this.onTap});

  final bool current;
  final String label;
  final String a11y;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = current ? 54.0 : 58.0;
    return Semantics(
      button: true,
      selected: current,
      label: a11y,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stays inside its own column, so it never covers the neighbouring targets.
            AnimatedContainer(
              key: const Key('nav.pos.circle'),
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              margin: EdgeInsets.only(top: (58 - size) / 2, bottom: (58 - size) / 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current ? HisbahColors.ground : HisbahColors.primary,
                border: current ? Border.all(color: HisbahColors.primary, width: 2) : null,
                // Ring of the bar colour that "cuts" the button out of the bar, edged with the
                // bar's own hairline so the raised part reads without a drop shadow.
                boxShadow: const [
                  BoxShadow(color: HisbahColors.border, spreadRadius: 6),
                  BoxShadow(color: HisbahColors.surface, spreadRadius: 5),
                ],
              ),
              child: Icon(Icons.add, size: 28, color: current ? HisbahColors.primary : HisbahColors.onPrimary),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: current ? HisbahColors.primary : HisbahColors.inkSubtle,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            // Same height as the side tabs' indicator row, so the labels line up.
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}

/// Shown under the status bar while the server is unreachable. R1 has no offline sales (ia.md §1).
/// Offline (or a queue near its limit, FR-68): what still works and what waits. With the R2 local
/// store, sales and payments are saved on the phone; without it, selling needs the internet.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  /// Whether any banner shows, so the screen under it gives up its top inset.
  static bool shows(WidgetRef ref) => !ref.watch(serverReachableProvider) || ref.watch(syncEngineProvider.select((s) => s.nearLimit));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final online = ref.watch(serverReachableProvider);
    final sync = ref.watch(syncEngineProvider);
    final tone = sync.full ? StatusTone.error : StatusTone.offline;
    final text = sync.full
        ? t.queueFullTitle
        : sync.nearLimit
        ? t.queueWarnBody(sync.pending, OfflineStore.limit)
        : !sync.available
        ? t.offlineBanner
        : sync.pending > 0
        ? t.offlineSavedBannerCount(sync.pending)
        : t.offlineSavedBanner;

    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        key: const Key('banner.offline'),
        color: tone.bg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(online ? Icons.cloud_upload_outlined : Icons.wifi_off_rounded, size: 20, color: tone.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(text, style: TextStyle(color: tone.fg, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                if (sync.available && sync.pending > 0)
                  TextButton(
                    key: const Key('banner.sync'),
                    onPressed: () => openSyncScreen(context),
                    style: TextButton.styleFrom(foregroundColor: tone.fg, minimumSize: const Size(44, 44)),
                    child: Text(t.syncNow),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
