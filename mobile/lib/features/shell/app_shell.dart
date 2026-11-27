import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/offline/offline_store.dart';
import '../../core/providers.dart';
import '../../core/motion/motion.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../guide/coach_tour.dart';
import '../sync/application/sync_engine.dart';
import '../sync/presentation/sync_screen.dart';

/// The five R1 tabs. The bar shows them in enum order; RTL places the first at the right edge:
/// الرئيسية · الزبائن · بيع (+) · المنتجات · المزيد — بيع is column 3 of 5, the exact centre
/// (TL change to US-1505, 2026-10-15).
enum AppTab {
  home('/home', Icons.home_outlined, Icons.home_rounded),
  customers('/customers', Icons.group_outlined, Icons.group_rounded),
  pos('/pos', Icons.add, Icons.add),
  products('/products', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
  more('/more', Icons.short_text_rounded, Icons.short_text_rounded);

  const AppTab(this.path, this.icon, this.activeIcon);

  final String path;
  final IconData icon;

  /// Filled when the tab is current, so where you are reads at a glance (not by colour alone).
  final IconData activeIcon;

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
            // Slides down when the connection drops and folds away when it is back.
            FadeSwitcher(size: true, child: banner ? const OfflineBanner() : const SizedBox(width: double.infinity)),
            Expanded(
              // The body's own context: its MediaQuery bottom padding includes the bar height
              // (extendBody), so the end of every tab can scroll clear of the bar.
              child: Builder(
                builder: (body) => MediaQuery.removePadding(
                  context: body,
                  removeTop: banner,
                  child: _SwipeTabs(
                    onStep: (step) {
                      final next = shell.currentIndex + step;
                      if (next < 0 || next >= AppTab.values.length) return;
                      Haptics.select();
                      shell.goBranch(next);
                    },
                    child: _TabFade(index: shell.currentIndex, child: shell),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HisbahNavBar(
        current: AppTab.values[shell.currentIndex],
        // Re-tapping the active tab returns to its root (ia.md §1).
        onSelect: (tab) {
          if (tab.index != shell.currentIndex) Haptics.select();
          shell.goBranch(tab.index, initialLocation: tab.index == shell.currentIndex);
        },
      ),
    );
  }
}

/// A sideways swipe moves one tab along the bar, in reading order: in Arabic a swipe to the right
/// goes from الرئيسية to الزبائن to بيع, and a swipe to the left comes back. Lists that scroll
/// sideways inside a tab (the held carts) keep their own swipe: the inner scroller wins.
class _SwipeTabs extends StatefulWidget {
  const _SwipeTabs({required this.onStep, required this.child});

  /// +1: the next tab along the bar; −1: the one before.
  final ValueChanged<int> onStep;
  final Widget child;

  @override
  State<_SwipeTabs> createState() => _SwipeTabsState();
}

class _SwipeTabsState extends State<_SwipeTabs> {
  /// A deliberate swipe: fast enough, or far enough across the screen.
  static const _minVelocity = 350.0;
  static const _minDistance = 70.0;

  double _dx = 0;

  void _end(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final dx = _dx;
    _dx = 0;
    if (v.abs() < _minVelocity && dx.abs() < _minDistance) return;
    final right = (v.abs() >= _minVelocity ? v : dx) > 0;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    widget.onStep(right == rtl ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onHorizontalDragStart: (_) => _dx = 0,
    onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
    onHorizontalDragEnd: _end,
    child: widget.child,
  );
}

/// A new tab slides in from the side it sits on in the bar and fades up; the tabs keep their
/// state (the stack is untouched).
class _TabFade extends StatefulWidget {
  const _TabFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabFade> createState() => _TabFadeState();
}

class _TabFadeState extends State<_TabFade> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  late final _curve = CurvedAnimation(parent: _c, curve: HisbahMotion.enter);

  /// −1 or 1: which screen edge the new tab enters from.
  double _from = 0;

  @override
  void didUpdateWidget(_TabFade old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index || HisbahMotion.reduced(context)) return;
    final forward = widget.index > old.index;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // A later tab sits toward the reading end of the bar (the left in Arabic).
    _from = forward == rtl ? -1 : 1;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    builder: (_, child) => Opacity(
      opacity: .35 + .65 * _curve.value,
      child: Transform.translate(offset: Offset(48 * _from * (1 - _curve.value), 0), child: child),
    ),
    child: widget.child,
  );
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
                        ? CoachTarget(
                            id: CoachStep.sell,
                            child: _SellButton(
                              key: const Key('nav.pos'),
                              current: current == tab,
                              label: tab.label(t),
                              a11y: current == tab ? t.sellCurrentA11y : t.sellA11y,
                              onTap: () => onSelect(tab),
                            ),
                          )
                        : _guided(
                            tab,
                            _SideTab(
                              key: Key('nav.${tab.name}'),
                              icon: current == tab ? tab.activeIcon : tab.icon,
                              label: tab.label(t),
                              active: current == tab,
                              onTap: () => onSelect(tab),
                            ),
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

/// The goods tab is where the guide starts.
Widget _guided(AppTab tab, Widget child) =>
    tab == AppTab.products ? CoachTarget(id: CoachStep.products, child: child) : child;

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
              // The icon lifts a little and turns solid as its tab becomes current.
              AnimatedSlide(
                offset: Offset(0, active ? -0.06 : 0),
                duration: HisbahMotion.of(context, HisbahMotion.fast),
                curve: HisbahMotion.enter,
                child: AnimatedSwitcher(
                  duration: HisbahMotion.of(context, HisbahMotion.fast),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween(begin: .7, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: Icon(icon, key: ValueKey(icon), size: 24, color: color),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: HisbahMotion.of(context, HisbahMotion.fast),
                  style: DefaultTextStyle.of(context).style.merge(
                    TextStyle(fontSize: 12, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                  ),
                  child: Text(label, maxLines: 1),
                ),
              ),
              const SizedBox(height: 2),
              // The indicator grows out from the centre.
              AnimatedContainer(
                duration: HisbahMotion.of(context, HisbahMotion.base),
                curve: HisbahMotion.enter,
                width: active ? 20 : 4,
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
            PressScale(
              scale: .9,
              child: AnimatedContainer(
                key: const Key('nav.pos.circle'),
                duration: HisbahMotion.of(context, HisbahMotion.fast),
                curve: HisbahMotion.enter,
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
                // A quarter turn as بيع becomes the current tab.
                child: AnimatedRotation(
                  turns: current ? .25 : 0,
                  duration: HisbahMotion.of(context, HisbahMotion.base),
                  curve: HisbahMotion.enter,
                  child: Icon(Icons.add, size: 28, color: current ? HisbahColors.primary : HisbahColors.onPrimary),
                ),
              ),
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
