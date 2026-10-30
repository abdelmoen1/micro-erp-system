import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/hisbah_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session_controller.dart';

/// The guide walks through the real app: the screen darkens, one control stays lit with a pulse
/// and an arrow, and the person presses it or skips. Everything done here is real.
enum CoachStep { welcome, products, add, scan, next, sell, done }

String guideSeenKey(int userId) => 'guide.done.$userId';

/// True once this account finished or dismissed the guide on this phone.
final guideSeenProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session is! SignedIn) return true;
  return await ref.watch(keyValueStoreProvider).read(guideSeenKey(session.user.id)) != null;
});

final guideTourProvider = NotifierProvider<GuideTour, CoachStep?>(GuideTour.new);

/// The current step, or null when the guide is not running.
class GuideTour extends Notifier<CoachStep?> {
  List<CoachStep> _steps = const [];

  @override
  CoachStep? build() => null;

  int get position => state == null ? 0 : _steps.indexOf(state!) + 1;

  int get length => _steps.length;

  void start() {
    final session = ref.read(sessionProvider);
    // An employee sells but does not receive goods.
    final canAdd = session is SignedIn && session.user.canOverride;
    _steps = [
      CoachStep.welcome,
      if (canAdd) ...[CoachStep.products, CoachStep.add, CoachStep.scan, CoachStep.next],
      CoachStep.sell,
      CoachStep.done,
    ];
    state = _steps.first;
  }

  /// The lit control was pressed; other steps ignore it.
  void pressed(CoachStep step) {
    if (state == step) next();
  }

  void next() {
    final index = _steps.indexOf(state ?? CoachStep.done);
    if (index < 0 || index + 1 >= _steps.length) {
      finish();
      return;
    }
    state = _steps[index + 1];
  }

  /// Skipping counts as seen: the card does not come back, «المزيد» still opens the guide.
  Future<void> finish() async {
    state = null;
    final session = ref.read(sessionProvider);
    if (session is! SignedIn) return;
    await ref.read(keyValueStoreProvider).write(guideSeenKey(session.user.id), DateTime.now().toIso8601String());
    ref.invalidate(guideSeenProvider);
  }
}

final _targets = <CoachStep, GlobalKey>{};

/// Marks the control a step points at.
class CoachTarget extends ConsumerStatefulWidget {
  const CoachTarget({super.key, required this.id, required this.child});

  final CoachStep id;
  final Widget child;

  @override
  ConsumerState<CoachTarget> createState() => _CoachTargetState();
}

class _CoachTargetState extends ConsumerState<CoachTarget> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _targets[widget.id] = _key;
  }

  @override
  void dispose() {
    if (_targets[widget.id] == _key) _targets.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: _key,
    behavior: HitTestBehavior.translucent,
    onPointerUp: (_) => ref.read(guideTourProvider.notifier).pressed(widget.id),
    child: widget.child,
  );
}

/// Where the step's control is on screen; null while it is not on the top route.
Rect? _targetRect(CoachStep step) {
  final context = _targets[step]?.currentContext;
  if (context == null || !context.mounted) return null;
  if (!(ModalRoute.of(context)?.isCurrent ?? true)) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Above every route, so the guide follows the person from screen to screen.
class CoachOverlay extends ConsumerStatefulWidget {
  const CoachOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends ConsumerState<CoachOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  Rect? _rect;

  @override
  void initState() {
    super.initState();
    _pulse.addListener(_follow);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// A control moves with a scroll, a keyboard or a page sliding in.
  void _follow() {
    final step = ref.read(guideTourProvider);
    final rect = step == null ? null : _targetRect(step);
    if (rect != _rect) setState(() => _rect = rect);
  }

  @override
  Widget build(BuildContext context) {
    final step = ref.watch(guideTourProvider);
    if (step == null) {
      if (_pulse.isAnimating) _pulse.stop();
      return widget.child;
    }
    final card = step == CoachStep.welcome || step == CoachStep.done;
    // The first and last cards point at nothing.
    if (card) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
    final rect = _rect;

    return Stack(
      textDirection: Directionality.of(context),
      children: [
        widget.child,
        if (card)
          Positioned.fill(child: _CenterCard(step: step))
        else if (rect != null)
          ..._spotlight(step, rect),
        if (!card) PositionedDirectional(top: MediaQuery.paddingOf(context).top + 8, end: 12, child: const _SkipButton()),
      ],
    );
  }

  List<Widget> _spotlight(CoachStep step, Rect target) {
    final size = MediaQuery.sizeOf(context);
    final hole = target.inflate(6);
    final below = hole.center.dy < size.height / 2;

    return [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => CustomPaint(painter: _ScrimPainter(hole, _pulse.value)),
          ),
        ),
      ),
      // Everything around the lit control takes the touch; the control itself gets it.
      _Blocker(Rect.fromLTRB(0, 0, size.width, hole.top)),
      _Blocker(Rect.fromLTRB(0, hole.bottom, size.width, size.height)),
      _Blocker(Rect.fromLTRB(0, hole.top, hole.left, hole.bottom)),
      _Blocker(Rect.fromLTRB(hole.right, hole.top, size.width, hole.bottom)),
      Positioned(
        left: hole.center.dx - 16,
        top: below ? hole.bottom + 8 : null,
        bottom: below ? null : size.height - hole.top + 8,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) {
            final wave = (_pulse.value < .5 ? _pulse.value : 1 - _pulse.value) * 16;
            return Transform.translate(offset: Offset(0, below ? wave : -wave), child: child);
          },
          child: Icon(below ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 32, color: HisbahColors.onPrimary),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        top: below ? hole.bottom + 56 : null,
        bottom: below ? null : size.height - hole.top + 56,
        child: _StepCard(step: step),
      ),
    ];
  }
}

class _Blocker extends StatelessWidget {
  const _Blocker(this.rect);

  final Rect rect;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: rect,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
  );
}

class _ScrimPainter extends CustomPainter {
  _ScrimPainter(this.hole, this.progress);

  final Rect hole;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final lit = RRect.fromRectAndRadius(hole, const Radius.circular(HisbahRadius.button));
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(lit);
    canvas.drawPath(scrim, Paint()..color = const Color(0xB814262E));
    canvas.drawRRect(
      lit.inflate(progress * 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 1 - progress),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.hole != hole || old.progress != progress;
}

(String, String) _words(CoachStep step, AppLocalizations t) => switch (step) {
  CoachStep.welcome => (t.guideWelcomeTitle, t.coachWelcomeBody),
  CoachStep.products => (t.coachProductsTitle, t.coachProductsBody),
  CoachStep.add => (t.coachAddTitle, t.coachAddBody),
  CoachStep.scan => (t.coachScanTitle, t.coachScanBody),
  CoachStep.next => (t.coachNextTitle, t.coachNextBody),
  CoachStep.sell => (t.coachSellTitle, t.coachSellBody),
  CoachStep.done => (t.guideDoneTitle, t.guideDoneBody),
};

class _StepCard extends ConsumerWidget {
  const _StepCard({required this.step});

  final CoachStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tour = ref.read(guideTourProvider.notifier);
    final (title, body) = _words(step, t);
    return Material(
      key: Key('guide.step.${step.name}'),
      color: HisbahColors.raised,
      borderRadius: BorderRadius.circular(HisbahRadius.card),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.guideStep(tour.position, tour.length),
              key: const Key('guide.progress'),
              style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
            ),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// The first and last steps: no control to press, a card in the middle of the dark screen.
class _CenterCard extends ConsumerWidget {
  const _CenterCard({required this.step});

  final CoachStep step;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tour = ref.read(guideTourProvider.notifier);
    final (title, body) = _words(step, t);
    final first = step == CoachStep.welcome;
    return ColoredBox(
      color: const Color(0xB814262E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            key: Key('guide.step.${step.name}'),
            color: HisbahColors.raised,
            borderRadius: BorderRadius.circular(HisbahRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6)),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: Key(first ? 'guide.next' : 'guide.finish'),
                    onPressed: first ? tour.next : tour.finish,
                    child: Text(first ? t.guideStart : t.guideFinish),
                  ),
                  if (first)
                    TextButton(key: const Key('guide.skip'), onPressed: tour.finish, child: Text(t.coachSkip)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends ConsumerWidget {
  const _SkipButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: const Color(0x4D14262E),
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      key: const Key('guide.skip'),
      borderRadius: BorderRadius.circular(999),
      onTap: ref.read(guideTourProvider.notifier).finish,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          AppLocalizations.of(context).coachSkip,
          style: const TextStyle(color: HisbahColors.onPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    ),
  );
}
