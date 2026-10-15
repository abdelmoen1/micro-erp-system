import 'package:flutter/material.dart';

import '../theme/hisbah_tokens.dart';

/// Dashed outline used for screens that are not designed yet (hi-fi board, tab placeholders).
class DashedCard extends StatelessWidget {
  const DashedCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DashedRRectPainter(),
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class _DashedRRectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(HisbahRadius.card)).deflate(0.75);
    final paint = Paint()
      ..color = HisbahColors.placeholderBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
