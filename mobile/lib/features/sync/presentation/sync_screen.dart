import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../customers/presentation/record_payment_screen.dart' show methodLabel;
import '../../sale/presentation/sale_widgets.dart';
import '../application/sync_engine.dart';

/// Pending and held items, newest first; reloaded whenever the counts change.
final outboxListProvider = FutureProvider.autoDispose<List<OutboxItem>>((ref) async {
  ref.watch(syncEngineProvider.select((s) => (s.pending, s.review, s.syncing)));
  final store = ref.watch(offlineStoreProvider);
  if (!await store.available) return const [];
  return store.items(states: {OutboxState.pending, OutboxState.review});
});

/// Opens SCR-M-16 from the indicator or a banner.
void openSyncScreen(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const SyncScreen()));

/// SCR-M-16 · sync status (US-1104, D-18): what waits, what the server held for a manager, what
/// is stuck, and «Sync now». Held items are resolved on the web (SCR-W-18), not here.
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final status = ref.watch(syncEngineProvider);
    final online = ref.watch(serverReachableProvider);
    final items = ref.watch(outboxListProvider).value ?? const <OutboxItem>[];
    final pending = [for (final i in items) if (i.state == OutboxState.pending) i];
    final held = [for (final i in items) if (i.state == OutboxState.review) i];

    final (tone, icon, title) = !online
        ? (StatusTone.offline, Icons.cloud_off_rounded, t.syncOfflineTitle(status.pending))
        : status.syncing
        ? (StatusTone.info, Icons.sync_rounded, t.syncSyncing)
        : status.pending > 0
        ? (StatusTone.warning, Icons.schedule_rounded, t.syncPending(status.pending))
        : (StatusTone.success, Icons.cloud_done_outlined, t.syncAllSent);

    return Scaffold(
      appBar: AppBar(title: Text(t.syncTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ToneCard(key: const Key('sync.status'), tone: tone, icon: icon, title: title, alert: true, children: [
              if (status.full)
                BodyText(t.queueFullBody)
              else if (status.nearLimit)
                BodyText(t.queueWarnBody(status.pending, OfflineStore.limit)),
              if (status.stuck > 0) BodyText(t.syncStuck(status.stuck)),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('sync.now'),
              onPressed: status.syncing ? null : () => ref.read(syncEngineProvider.notifier).kick(refresh: true),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
              icon: const Icon(Icons.sync_rounded),
              label: Text(t.syncNow),
            ),
            if (held.isNotEmpty) ...[
              const SizedBox(height: 20),
              GroupLabel(t.syncHeldTitle(held.length)),
              const SizedBox(height: 4),
              BodyText(t.syncHeldHelp, size: 13, color: HisbahColors.inkMuted),
              const SizedBox(height: 8),
              LineCard(child: _ItemList(items: held)),
            ],
            const SizedBox(height: 20),
            GroupLabel(t.syncPendingTitle),
            const SizedBox(height: 8),
            if (pending.isEmpty)
              Text(t.syncNothingPending, style: const TextStyle(color: HisbahColors.inkMuted))
            else
              LineCard(child: _ItemList(items: pending)),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});

  final List<OutboxItem> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: HisbahColors.border),
        _ItemRow(item: items[i]),
      ],
    ],
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OutboxItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final customer = item.summary['customer_name'] as String?;
    final method = item.summary['method'] as String?;
    final debt = Money.parse('${item.summary['debt'] ?? '0.00'}');
    final kind = item.type == 'sale' ? (debt.isPositive ? t.syncItemCreditSale : t.syncItemSale) : t.syncItemPayment;
    final time = item.occurredAt.toLocal();
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final detail = [?customer, if (method != null) methodLabel(t, method)].join(' · ');

    return Padding(
      key: Key('sync.item.${item.seq}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.state == OutboxState.review ? Icons.report_gmailerrorred_rounded : Icons.schedule_rounded,
            size: 20,
            color: item.state == OutboxState.review ? StatusTone.warning.fg : HisbahColors.inkMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kind, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                if (item.state == OutboxState.review && item.lastError != null)
                  Text(_reason(t, item.lastError!), style: TextStyle(fontSize: 13, color: StatusTone.warning.fg)),
                if (item.stuck) Text(t.syncItemStuck(item.attempts), style: TextStyle(fontSize: 13, color: StatusTone.error.fg)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Num(shekel(item.amount), size: 15, weight: FontWeight.w700),
              Num('$hh:$mm', size: 12, weight: FontWeight.w400, color: HisbahColors.inkMuted),
            ],
          ),
        ],
      ),
    );
  }

  /// The server's reason, said plainly for the codes a cashier will meet.
  static String _reason(AppLocalizations t, String error) {
    final code = error.split(':').first.trim();
    return switch (code) {
      'PAYMENT_EXCEEDS_REMAINING' || 'NOTHING_TO_PAY' => t.syncHeldPayment,
      'OCCURRED_AT_OUT_OF_RANGE' => t.syncHeldClock,
      _ => error.contains(':') ? error.substring(error.indexOf(':') + 1).trim() : error,
    };
  }
}
