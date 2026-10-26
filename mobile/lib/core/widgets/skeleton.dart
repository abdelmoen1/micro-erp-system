import 'package:flutter/material.dart';

import '../theme/hisbah_tokens.dart';

/// Placeholder shapes at the real layout's size while data loads (hi-fi M-05), never a spinner.
/// Static on purpose: no endless animation for reduced motion or for widget tests to wait on.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, required this.height, this.width, this.color = HisbahColors.skeleton, this.radius = 6});

  final double height;
  final double? width;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
  );
}

/// One placeholder row at the real row height (64).
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, required this.widthFactor, required this.divider, this.avatar = false});

  final double widthFactor;
  final bool divider;
  final bool avatar;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: HisbahColors.border)) : null),
    child: Row(
      children: [
        if (avatar) ...[
          const CircleAvatar(radius: 20, backgroundColor: HisbahColors.skeleton),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(widthFactor: widthFactor, child: const SkeletonBar(height: 12)),
              const SizedBox(height: 8),
              const SkeletonBar(width: 90, height: 10, color: HisbahColors.ground),
            ],
          ),
        ),
        const SkeletonBar(width: 64, height: 12),
      ],
    ),
  );
}

/// Rows in a card, as the lists draw them.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.rows = 5, this.avatar = false});

  final int rows;
  final bool avatar;

  static const _widths = [.62, .48, .7, .55, .66, .5];

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: HisbahColors.raised,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HisbahColors.border),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows; i++)
          SkeletonRow(widthFactor: _widths[i % _widths.length], divider: i > 0, avatar: avatar),
      ],
    ),
  );
}

/// A page about one thing (a product, a customer, an invoice, a form): a summary block, two
/// actions, then its rows.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HisbahColors.raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HisbahColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FractionallySizedBox(widthFactor: .55, child: SkeletonBar(height: 16)),
            SizedBox(height: 14),
            SkeletonBar(width: 120, height: 28),
            SizedBox(height: 14),
            FractionallySizedBox(widthFactor: .8, child: SkeletonBar(height: 10, color: HisbahColors.ground)),
            SizedBox(height: 8),
            FractionallySizedBox(widthFactor: .6, child: SkeletonBar(height: 10, color: HisbahColors.ground)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const SkeletonBar(height: 48, radius: 12),
      const SizedBox(height: 8),
      const SkeletonBar(height: 48, radius: 12, color: HisbahColors.ground),
      const SizedBox(height: 18),
      const SkeletonCard(rows: 3),
    ],
  );
}
