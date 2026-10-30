import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/hisbah_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'coach_tour.dart';

/// Starts the guide from «المزيد» or the Home card. It runs over the real screens (coach_tour).
void openUsageGuide(BuildContext context) => ProviderScope.containerOf(context).read(guideTourProvider.notifier).start();

/// On Home until the guide is finished or put off: what it offers, «ابدأ» and «لاحقاً».
class GuideCard extends ConsumerWidget {
  const GuideCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(guideSeenProvider).value ?? true) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    return Container(
      key: const Key('guide.card'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HisbahColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HisbahColors.primaryOutline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: HisbahColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.guideCardTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(t.guideCardBody, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              // The theme's filled buttons are full width: share the row.
              Expanded(
                child: FilledButton(
                  key: const Key('guide.start'),
                  onPressed: () => openUsageGuide(context),
                  child: Text(t.guideStart),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('guide.later'),
                onPressed: ref.read(guideTourProvider.notifier).finish,
                child: Text(t.guideLater),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
