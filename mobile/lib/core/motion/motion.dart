import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion tokens and small building blocks. Motion answers what the user did (a page opens, an
/// item lands in the cart, a sale is done) or says that something changed; nothing loops forever.
/// With the system's «remove animations» setting on, every helper here shows the end state at once.
abstract final class HisbahMotion {
  /// Small state changes: a pressed tile, a tab indicator, a highlight fading.
  static const fast = Duration(milliseconds: 160);

  /// Pages, sheets of content, cards appearing.
  static const base = Duration(milliseconds: 280);

  /// The one celebrated moment (a finished sale) and number counters.
  static const slow = Duration(milliseconds: 520);

  /// Things arriving: fast out, settling gently.
  static const enter = Curves.easeOutCubic;

  /// Things moving between two places.
  static const move = Curves.easeInOutCubic;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Light haptics on actions that change something (tab, add to cart, sale done). Quiet on devices
/// without a vibrator; never used for scrolling or plain reading.
abstract final class Haptics {
  static void select() => HapticFeedback.selectionClick();
  static void tap() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.mediumImpact();
  static void warn() => HapticFeedback.heavyImpact();
}

/// Forward pages slide in from the reading end (the left in Arabic) a short way and fade in; the
/// page underneath drifts back a little. Short travel keeps it calm on a low-end phone.
class HisbahPageTransitionsBuilder extends PageTransitionsBuilder {
  const HisbahPageTransitionsBuilder();

  @override
  Duration get transitionDuration => HisbahMotion.base;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (HisbahMotion.reduced(context)) return child;
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final inCurve = CurvedAnimation(parent: animation, curve: HisbahMotion.enter, reverseCurve: Curves.easeInCubic);
    final outCurve = CurvedAnimation(parent: secondaryAnimation, curve: HisbahMotion.move);

    return SlideTransition(
      position: Tween(begin: Offset.zero, end: Offset(-0.06 * dir, 0)).animate(outCurve),
      child: FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.85).animate(outCurve),
        child: SlideTransition(
          position: Tween(begin: Offset(0.12 * dir, 0), end: Offset.zero).animate(inCurve),
          child: FadeTransition(opacity: inCurve, child: child),
        ),
      ),
    );
  }
}

/// Shrinks a touch while the finger is down, so a big tile feels pressed. Listens to the pointer
/// only, so the child's own InkWell still gets the tap.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AnimatedScale(
      scale: _down ? widget.scale : 1,
      duration: HisbahMotion.of(context, const Duration(milliseconds: 110)),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Fades and lifts its child in once, when it first appears; [delay] staggers a short group.
class EntranceFade extends StatefulWidget {
  const EntranceFade({super.key, required this.child, this.delay = Duration.zero, this.offset = 14});

  final Widget child;
  final Duration delay;

  /// How far below its place the child starts, in logical pixels.
  final double offset;

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: HisbahMotion.base + widget.delay);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (HisbahMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _c.duration!.inMicroseconds;
    final start = total == 0 ? 0.0 : widget.delay.inMicroseconds / total;
    final t = CurvedAnimation(
      parent: _c,
      curve: Interval(start, 1, curve: HisbahMotion.enter),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (_, child) => Opacity(
        opacity: t.value,
        child: Transform.translate(offset: Offset(0, (1 - t.value) * widget.offset), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Opens its child from zero height while fading it in: a new row in a list, a message that
/// appears above a form. Plays once per mount.
class GrowIn extends StatefulWidget {
  const GrowIn({super.key, required this.child, this.animate = true});

  final Widget child;

  /// False shows the child in place, e.g. for rows already there when the screen opened.
  final bool animate;

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: HisbahMotion.base);
  late final _curve = CurvedAnimation(parent: _c, curve: HisbahMotion.enter);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || HisbahMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _curve,
    alignment: AlignmentDirectional.topCenter,
    child: FadeTransition(opacity: _curve, child: widget.child),
  );
}

/// Cross-fades between states (loading → content, one message → another). The incoming child
/// rises a few pixels; a missing child collapses smoothly.
class FadeSwitcher extends StatelessWidget {
  const FadeSwitcher({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter,
    this.size = false,
    this.fill = false,
  });

  /// Give each state its own key (or widget type) so the switch is noticed.
  final Widget child;
  final Alignment alignment;

  /// Also animate the height, for a message that comes and goes above other content.
  final bool size;

  /// Each state takes the whole (bounded) space, as a screen's body does.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final duration = HisbahMotion.of(context, HisbahMotion.base);
    final switcher = AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration ~/ 2,
      switchInCurve: HisbahMotion.enter,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, fit: fill ? StackFit.expand : StackFit.loose, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
    if (!size) return switcher;
    return AnimatedSize(duration: duration, curve: HisbahMotion.move, alignment: alignment, child: switcher);
  }
}

/// A money figure that counts to its new value instead of jumping: from zero the first time, from
/// the old figure after a change. The last frame is always [amount] exactly, formatted by [format].
class CountUp extends StatefulWidget {
  const CountUp({super.key, required this.amount, required this.format, required this.builder, this.fromZero = true});

  /// The figure as the API sends it ("1250.50").
  final String amount;

  /// How a figure is written ("1,250.50").
  final String Function(String amount) format;
  final Widget Function(BuildContext context, String text) builder;

  /// Count up from zero on first show; false starts at the figure itself.
  final bool fromZero;

  @override
  State<CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<CountUp> {
  late double _from = widget.fromZero ? 0 : _parse(widget.amount);

  static double _parse(String s) => double.tryParse(s) ?? 0;

  @override
  void didUpdateWidget(CountUp old) {
    super.didUpdateWidget(old);
    if (old.amount != widget.amount) _from = _parse(old.amount);
  }

  int get _decimals {
    final dot = widget.amount.indexOf('.');
    return dot < 0 ? 0 : widget.amount.length - dot - 1;
  }

  @override
  Widget build(BuildContext context) {
    final end = _parse(widget.amount);
    if (HisbahMotion.reduced(context) || _from == end) return widget.builder(context, widget.format(widget.amount));
    return TweenAnimationBuilder<double>(
      key: ValueKey(widget.amount),
      tween: Tween(begin: _from, end: end),
      duration: HisbahMotion.slow + const Duration(milliseconds: 280),
      curve: Curves.easeOutQuart,
      onEnd: () => _from = end,
      builder: (context, v, _) =>
          widget.builder(context, widget.format(v == end ? widget.amount : v.toStringAsFixed(_decimals))),
    );
  }
}

/// Gives a quick pop when [value] changes: the cart total after a scan, a quantity after «+».
class Bump extends StatefulWidget {
  const Bump({
    super.key,
    required this.value,
    required this.child,
    this.scale = 1.08,
    this.alignment = Alignment.center,
  });

  final Object? value;
  final Widget child;
  final double scale;

  /// Where the pop grows from; a start-aligned figure grows from its start.
  final AlignmentGeometry alignment;

  @override
  State<Bump> createState() => _BumpState();
}

class _BumpState extends State<Bump> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void didUpdateWidget(Bump old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !HisbahMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, child) {
      // Up fast, back down softly.
      final t = _c.value;
      final k = t < .35 ? Curves.easeOut.transform(t / .35) : 1 - Curves.easeInOut.transform((t - .35) / .65);
      return Transform.scale(scale: 1 + (widget.scale - 1) * k, alignment: widget.alignment, child: child);
    },
    child: widget.child,
  );
}

/// The done mark of a finished sale: the circle pops in and the tick draws itself.
class SuccessMark extends StatefulWidget {
  const SuccessMark({super.key, required this.color, this.size = 48, this.icon});

  final Color color;
  final double size;

  /// Null draws the animated tick; otherwise this icon (e.g. a void sign) pops in.
  final IconData? icon;

  @override
  State<SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<SuccessMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: HisbahMotion.slow + const Duration(milliseconds: 180));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (HisbahMotion.reduced(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(SuccessMark old) {
    super.didUpdateWidget(old);
    if (old.icon != widget.icon && !HisbahMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, .55, curve: Curves.easeOutBack),
    );
    final draw = CurvedAnimation(
      parent: _c,
      curve: const Interval(.4, 1, curve: Curves.easeOutCubic),
    );
    final ring = CurvedAnimation(
      parent: _c,
      curve: const Interval(.3, 1, curve: Curves.easeOut),
    );
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // A ring that spreads and fades once around the circle.
            if (_c.value < 1)
              Transform.scale(
                scale: 1 + ring.value * .5,
                child: Opacity(
                  opacity: (1 - ring.value) * .5,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 3),
                    ),
                  ),
                ),
              ),
            Transform.scale(
              scale: pop.value.clamp(0, 1.2),
              child: Container(
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: widget.icon != null
                    ? Opacity(
                        opacity: draw.value,
                        child: Icon(widget.icon, size: s * .54, color: Colors.white),
                      )
                    : CustomPaint(size: Size.square(s * .5), painter: _TickPainter(draw.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * .14, w * .52)
      ..lineTo(w * .4, w * .76)
      ..lineTo(w * .88, w * .26);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * .13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}
