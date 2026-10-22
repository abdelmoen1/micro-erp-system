import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/hisbah_tokens.dart';

/// The Hisbah mark: a geometric ح whose flat tail is closed by a second, thinner rule — the
/// double underline a bookkeeper draws under a final total. It is drawn in one colour, so the
/// same drawing is the brand (teal on ivory), reversed (ivory on teal) and monochrome version.
/// Vector, so it stays sharp from a 16 px favicon to the splash.
class HisbahMark extends StatelessWidget {
  const HisbahMark({super.key, required this.size, this.color = HisbahColors.primary});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: HisbahMarkPainter(color: color)),
  );
}

/// The mark reversed out of a deep-teal tile: the app icon, and the brand in the tab header.
class HisbahMarkTile extends StatelessWidget {
  const HisbahMarkTile({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: HisbahColors.primary,
      // Same proportion as the launcher icon's corner (22.5 %).
      borderRadius: BorderRadius.circular(size * 0.225),
    ),
    child: Padding(
      padding: EdgeInsets.all(size * HisbahMarkPainter.tileInset),
      child: HisbahMark(size: size * (1 - 2 * HisbahMarkPainter.tileInset), color: HisbahColors.surface),
    ),
  );
}

/// Mark + Arabic wordmark. [vertical] stacks them (splash, sign-in); otherwise the mark sits
/// at the start of the line (RTL: on the right).
class HisbahLogo extends StatelessWidget {
  const HisbahLogo({super.key, required this.markSize, this.vertical = true, this.color = HisbahColors.primary});

  final double markSize;
  final bool vertical;
  final Color color;

  static const wordmark = 'حسبة';

  @override
  Widget build(BuildContext context) {
    final word = Text(
      wordmark,
      textDirection: TextDirection.rtl,
      maxLines: 1,
      // The wordmark keeps its size: it is artwork, not body text.
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: markSize * (vertical ? 0.5 : 0.62),
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
    final mark = HisbahMark(size: markSize, color: color);

    return Semantics(
      label: wordmark,
      image: true,
      excludeSemantics: true,
      child: vertical
          // The mark's own bottom margin is the gap.
          ? Column(mainAxisSize: MainAxisSize.min, children: [mark, word])
          : Row(mainAxisSize: MainAxisSize.min, children: [mark, SizedBox(width: markSize * 0.06), word]),
    );
  }
}

class HisbahMarkPainter extends CustomPainter {
  const HisbahMarkPainter({required this.color});

  final Color color;

  /// Geometry on a 100 × 100 grid, ink centred (x 22–78, y 13.5–85.5).
  static const letterStroke = 13.0;
  static const ruleStroke = 5.0;

  /// Padding of the mark inside [HisbahMarkTile] and the launcher icon, as a share of the side.
  static const tileInset = 0.16;

  /// SVG path data for the same geometry (written to docs/design/assets/brand by the asset tool).
  static const svgLetter = 'M78 20H22M58 20C46 28 29 38 29 48C29 60 38 68 52 68H78';
  static const svgRule = 'M52 83H78';

  static Path letter() => Path()
    // Head of the ح, right to left.
    ..moveTo(78, 20)
    ..lineTo(22, 20)
    // Body: leaves the head down-left, bowl opens to the left side, tail runs flat to the right.
    ..moveTo(58, 20)
    ..cubicTo(46, 28, 29, 38, 29, 48)
    ..cubicTo(29, 60, 38, 68, 52, 68)
    ..lineTo(78, 68);

  static Path rule() => Path()
    ..moveTo(52, 83)
    ..lineTo(78, 83);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 100;
    canvas
      ..save()
      ..translate((size.width - 100 * scale) / 2, (size.height - 100 * scale) / 2)
      ..scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true;
    canvas
      ..drawPath(letter(), paint..strokeWidth = letterStroke)
      ..drawPath(rule(), paint..strokeWidth = ruleStroke)
      ..restore();
  }

  @override
  bool shouldRepaint(HisbahMarkPainter oldDelegate) => oldDelegate.color != color;
}
