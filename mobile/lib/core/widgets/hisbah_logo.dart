import 'package:flutter/material.dart';

/// The primary Hisbah mark, unaltered. Its artwork has the ground ivory (#F2EEE4) baked in,
/// so it is only placed directly on `HisbahColors.ground`, never on a card.
class HisbahLogo extends StatelessWidget {
  const HisbahLogo({super.key, required this.width});

  static const asset = 'assets/images/hisbah-logo-primary.png';

  /// Source artwork is 2400 × 1789.
  static const aspectRatio = 2400 / 1789;

  final double width;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Semantics(
      label: 'حسبة',
      image: true,
      child: Image.asset(
        asset,
        width: width,
        height: width / aspectRatio,
        fit: BoxFit.contain,
        // Decode at display size: the 2400 px source would cost ~17 MB on low-end phones.
        cacheWidth: (width * dpr).round(),
        excludeFromSemantics: true,
      ),
    );
  }
}
