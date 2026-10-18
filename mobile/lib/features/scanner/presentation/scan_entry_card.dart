import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'scanner_screen.dart';

/// A · the smallest addition to the بيع tab: one card under the unchanged placeholder.
/// TODO(U-2): exact placement inside the real بيع screen once M-02 (cart) is built in S5.
class ScanEntryCard extends ConsumerWidget {
  const ScanEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Container(
      key: const Key('scan.entry'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HisbahColors.surface,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        border: Border.all(color: HisbahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HisbahColors.primaryTint,
                    borderRadius: BorderRadius.circular(HisbahRadius.field),
                  ),
                  child: const Icon(Icons.crop_free, size: 24, color: HisbahColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.scanEntryTitle,
                      style: const TextStyle(fontSize: 17, height: 1.45, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.scanEntryBody,
                      style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('scan.open'),
            icon: const Icon(Icons.crop_free, size: 22),
            label: Text(t.scanBarcode),
            onPressed: () => openScanner(context, ref),
          ),
        ],
      ),
    );
  }
}
