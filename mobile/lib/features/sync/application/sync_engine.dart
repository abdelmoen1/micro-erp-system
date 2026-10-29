import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../data/sync_repository.dart';

/// What the indicator shows (FR-67, UI-AC-13): synced, synchronizing, or pending (n), plus the
/// items the server held for review and the queue-limit warning (FR-68).
class SyncStatus {
  const SyncStatus({
    this.available = false,
    this.pending = 0,
    this.review = 0,
    this.stuck = 0,
    this.syncing = false,
    this.lastSyncedAt,
  });

  /// The local database opened; false keeps the app online-only, as before R2.
  final bool available;
  final int pending;
  final int review;
  final int stuck;
  final bool syncing;
  final DateTime? lastSyncedAt;

  /// D-18: a persistent warning with «Sync now».
  bool get nearLimit => pending >= OfflineStore.warnAt;

  /// BR-12: new offline sales and payments are refused.
  bool get full => pending >= OfflineStore.limit;

  SyncStatus copyWith({bool? available, OutboxCounts? counts, bool? syncing, DateTime? lastSyncedAt}) => SyncStatus(
    available: available ?? this.available,
    pending: counts?.pending ?? pending,
    review: counts?.review ?? review,
    stuck: counts?.stuck ?? stuck,
    syncing: syncing ?? this.syncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

/// False in tests that drive the engine by hand (no periodic refresh).
final syncAutoProvider = Provider<bool>((ref) => true);

/// US-1104 FIFO sync engine. Sends the oldest pending items in batches of 50 whenever the server
/// is reachable, settles each by the server's answer, then refreshes the catalog and customer
/// cache by delta. A failure keeps every item and retries with backoff; nothing is ever dropped.
class SyncEngine extends Notifier<SyncStatus> {
  static const batchSize = 50;
  static const refreshEvery = Duration(minutes: 5);
  static const backoff = [Duration(seconds: 5), Duration(seconds: 15), Duration(seconds: 60), Duration(minutes: 5)];

  Timer? _retry;
  Timer? _periodic;
  /// Runs one after another, so a caller's `await kick()` sees its own run finish.
  Future<void> _chain = Future.value();
  int _failures = 0;
  DateTime? _refreshedAt;

  OfflineStore get _store => ref.read(offlineStoreProvider);

  @override
  SyncStatus build() {
    ref.onDispose(() {
      _retry?.cancel();
      _periodic?.cancel();
    });
    ref.listen(serverReachableProvider, (previous, online) {
      if (online && previous == false) {
        unawaited(kick());
      } else if (!online) {
        _scheduleRetry();
      }
    });
    ref.listen(sessionProvider, (previous, next) {
      // Before _init the store is not known yet; _init then starts the first run itself.
      if (next is SignedIn && previous is! SignedIn && state.available) unawaited(kick(refresh: true));
    });
    Future.microtask(_init);
    return const SyncStatus();
  }

  Future<void> _init() async {
    if (!await _store.available || !ref.mounted) return;
    state = state.copyWith(available: true, counts: await _store.counts());
    if (ref.read(syncAutoProvider)) {
      _periodic = Timer.periodic(refreshEvery, (_) => unawaited(kick(refresh: true)));
    }
    if (ref.read(sessionProvider) is SignedIn) await kick(refresh: true);
  }

  /// True when a new sale or payment must go through the queue: offline, or items still waiting
  /// (a direct write would overtake them and break FIFO, BR-05).
  Future<bool> shouldQueue() async {
    if (!await _store.available) return false;
    if (!ref.read(serverReachableProvider)) return true;
    return (await _store.counts()).pending > 0;
  }

  Future<bool> get canQueue => _store.available;

  /// A queued item was just committed: show it, and send it at once when online.
  Future<void> enqueued() async {
    await reloadCounts();
    unawaited(kick());
  }

  Future<void> reloadCounts() async {
    if (!await _store.available || !ref.mounted) return;
    final counts = await _store.counts();
    if (ref.mounted) state = state.copyWith(available: true, counts: counts);
  }

  /// «Sync now», a reconnect, a resume or a new item. [refresh] also pulls the catalog delta.
  /// Never throws: a failure keeps the items and schedules a retry.
  Future<void> kick({bool refresh = false}) {
    final run = _chain.then((_) => _run(refresh));
    _chain = run;
    return run;
  }

  Future<void> _run(bool refresh) async {
    if (!ref.mounted) return;
    final session = ref.read(sessionProvider);
    if (session is! SignedIn || !await _store.available || !ref.mounted) return;
    final user = session.user;

    _retry?.cancel();
    state = state.copyWith(syncing: true);
    try {
      if (user.storeId != null) await _store.useStore(user.storeId!);
      final sent = await _drain(user.id);
      final stale = _refreshedAt == null || DateTime.now().difference(_refreshedAt!) >= refreshEvery;
      if (refresh || sent || stale) await _refresh();
      _failures = 0;
      if (ref.mounted) state = state.copyWith(lastSyncedAt: DateTime.now());
    } on Unauthenticated {
      // The session handler asks to sign in again; the queue waits for the same account.
    } on SubscriptionExpired {
      // Kept until the subscription is renewed.
    } catch (_) {
      _failures++;
      _scheduleRetry();
    } finally {
      if (ref.mounted) {
        state = state.copyWith(syncing: false);
        await reloadCounts();
      }
    }
  }

  /// Sends the oldest pending items, 50 at a time, until none are left. True when the server
  /// answered for at least one item.
  Future<bool> _drain(int userId) async {
    final repository = ref.read(syncRepositoryProvider);
    final deviceId = await _store.deviceId();
    var sent = false;

    while (true) {
      final items = await _store.pending(userId: userId, limit: batchSize);
      if (items.isEmpty) return sent;

      final List<SyncResult> results;
      try {
        results = await repository.batch(deviceId, items);
      } on NetworkFailure {
        rethrow; // no answer: the items never count as failed attempts
      } on ApiFailure catch (failure) {
        await _store.failed([items.first.clientTransactionId], _describe(failure.runtimeType.toString(), failure.message));
        rethrow;
      }

      final answered = {for (final r in results) r.clientTransactionId.toLowerCase(): r};
      for (final item in items) {
        final result = answered[item.clientTransactionId.toLowerCase()];
        if (result == null) continue;
        await _store.settle(
          item.clientTransactionId,
          state: result.held ? OutboxState.review : OutboxState.done,
          serverId: result.serverId,
          flags: result.flags,
          error: result.held ? _describe(result.errorCode, result.errorMessage) : null,
        );
        sent = true;
      }

      // The server stopped at an item (a technical failure there): resend from it later.
      final unanswered = [for (final item in items) if (!answered.containsKey(item.clientTransactionId.toLowerCase())) item];
      if (unanswered.isNotEmpty) {
        await _store.failed([unanswered.first.clientTransactionId], 'SERVER_ERROR');
        throw StateError('sync halted at seq ${unanswered.first.seq}');
      }
      await reloadCounts();
    }
  }

  /// Delta of products and customers since the last refresh (US-1102), then the local effects of
  /// items the server has already counted stop counting.
  Future<void> _refresh() async {
    final repository = ref.read(syncRepositoryProvider);
    final started = DateTime.now();
    for (final entity in const ['products', 'customers']) {
      final since = await _store.meta('since.$entity');
      String? serverTime;
      var afterId = 0;
      while (true) {
        final page = await repository.bootstrap(entity, since: since, afterId: afterId);
        serverTime ??= page.serverTime;
        if (entity == 'products') {
          await _store.upsertProducts(page.rows);
        } else {
          await _store.upsertCustomers(page.rows);
        }
        if (page.nextAfterId == null) break;
        afterId = page.nextAfterId!;
      }
      await _store.setMeta('since.$entity', serverTime);
    }
    await _store.releaseEffects(started);
    _refreshedAt = DateTime.now();
  }

  void _scheduleRetry() {
    if (!ref.mounted || !state.available) return;
    _retry?.cancel();
    final delay = backoff[_failures.clamp(0, backoff.length - 1)];
    _retry = Timer(delay, () => unawaited(kick(refresh: !ref.read(serverReachableProvider))));
  }

  static String _describe(String? code, String? message) =>
      [?code, if (message != null && message.isNotEmpty) message].join(': ');
}

final syncRepositoryProvider = Provider<SyncRepository>((ref) => SyncRepository(ref.watch(apiClientProvider)));

final syncEngineProvider = NotifierProvider<SyncEngine, SyncStatus>(SyncEngine.new);
