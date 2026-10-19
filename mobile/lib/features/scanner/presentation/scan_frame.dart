import 'package:flutter/material.dart';

import '../../../core/theme/camera_tokens.dart';
import '../../../core/theme/hisbah_tokens.dart';

/// Where the 296 × 168 frame sits inside a scanner area of [size]: horizontally centred,
/// vertically at 36.5% (S2 hi-fi at 360 × 760). Narrower screens keep a 16 dp margin.
Rect scanFrameRect(Size size) {
  final width = (size.width - 32).clamp(0.0, CameraTokens.frameSize.width);
  final height = width * CameraTokens.frameSize.height / CameraTokens.frameSize.width;
  return Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.365), width: width, height: height);
}

/// Flat scrim with a hole for the frame, plus the frame itself: four corner arms while
/// scanning, a closed outline once a code is read (shape, not only colour). No blur.
class ScanFramePainter extends CustomPainter {
  const ScanFramePainter({required this.frame, required this.locked});

  final Rect frame;
  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(frame, const Radius.circular(CameraTokens.frameRadius));
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    canvas.drawPath(scrim, Paint()..color = CameraTokens.scrim);

    final stroke = Paint()
      ..color = CameraTokens.frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = CameraTokens.frameStroke
      ..strokeCap = StrokeCap.round;
    if (locked) {
      canvas.drawRRect(rrect, stroke);
      return;
    }
    const arm = CameraTokens.frameArm;
    const r = CameraTokens.frameRadius;
    canvas
      ..drawPath(_corner(frame.topLeft, 1, 1, arm, r), stroke)
      ..drawPath(_corner(frame.topRight, -1, 1, arm, r), stroke)
      ..drawPath(_corner(frame.bottomLeft, 1, -1, arm, r), stroke)
      ..drawPath(_corner(frame.bottomRight, -1, -1, arm, r), stroke);
  }

  /// One L-shaped arm pair with a rounded corner at [p]; [dx]/[dy] point into the frame.
  static Path _corner(Offset p, double dx, double dy, double arm, double r) => Path()
    ..moveTo(p.dx, p.dy + dy * arm)
    ..lineTo(p.dx, p.dy + dy * r)
    ..quadraticBezierTo(p.dx, p.dy, p.dx + dx * r, p.dy)
    ..lineTo(p.dx + dx * arm, p.dy);

  @override
  bool shouldRepaint(ScanFramePainter old) => old.frame != frame || old.locked != locked;
}

/// 36 dp ✓ badge centred on the frame's top edge once a code is read.
class ScanReadBadge extends StatelessWidget {
  const ScanReadBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: CameraTokens.badgeSize,
    height: CameraTokens.badgeSize,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: HisbahColors.primary, width: 2.5),
    ),
    child: const Icon(Icons.check_rounded, size: 22, color: HisbahColors.primary),
  );
}
