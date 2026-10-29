import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/core/offline/offline_store.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/application/session_controller.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/customers/domain/customer.dart';
import 'package:smartshop/features/sale/presentation/receipt_screen.dart';
import 'package:smartshop/features/scanner/application/lookup_controller.dart' show cameraPermissionsProvider, barcodeCameraFactoryProvider;
import 'package:smartshop/features/scanner/application/scan_cue.dart';
import 'package:smartshop/features/scanner/domain/barcode_camera.dart';
import 'package:smartshop/features/shell/tab_screens.dart';
import 'package:smartshop/features/sync/application/sync_engine.dart';
import 'package:smartshop/l10n/app_localizations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;
import 'sale_flow_test.dart' show customerJson, milk, milkCode;
import 'scan_cue_test.dart' show CountingBeep;
import 'scanner_test.dart' show FakeCamera, FakePermissions;

/// R2 offline mode (doc 16): local store and overlay (US-1102, US-1103), queue limit (US-1105),
/// FIFO exactly-once sync (US-1104, AC-06, AC-07), the indicator (FR-67) and an airplane-mode sale
/// (NFR-04), against an in-memory SQLite and a faked API.
OfflineStore memoryStore() => OfflineStore(databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);

FakeResponse page(List<Map<String, dynamic>> rows, {int? next, String time = '2026-10-29T09:00:00+00:00'}) =>
    FakeResponse(200, {'data': rows, 'next_after_id': next, 'server_time': time});

/// A server that applies each new `client_transaction_id` once and answers `duplicate` after.
class FakeSyncServer {
  final Set<String> applied = {};
  final List<int> seqs = [];
  final List<Map<String, dynamic>> items = [];

  /// Status for a new item (default `applied`).
  String Function(Map<String, dynamic> item) statusFor = (_) => 'applied';

  /// Process the batch, then drop the answer (the connection died after the server acted).
  bool loseAnswer = false;

  FakeResponse call(RequestOptions request) {
    final batch = (request.data as Map<String, dynamic>)['items'] as List<dynamic>;
    final results = <Map<String, dynamic>>[];
    for (final raw in batch) {
      final item = raw as Map<String, dynamic>;
      final id = item['client_transaction_id'] as String;
      seqs.add(item['seq'] as int);
      items.add(item);
      final fresh = applied.add(id);
      final status = fresh ? statusFor(item) : 'duplicate';
      results.add({
        'client_transaction_id': id,
        'seq': item['seq'],
        'status': status,
        'server_id': status == 'conflict' ? null : 900 + applied.length,
        'flags': status == 'flagged' ? ['NEGATIVE_STOCK'] : <String>[],
        'error': status == 'conflict' ? {'code': 'PAYMENT_EXCEEDS_REMAINING', 'message': 'أكبر من المتبقي'} : null,
      });
    }
    if (loseAnswer) {
      loseAnswer = false;
      throw DioException.receiveTimeout(timeout: const Duration(seconds: 20), requestOptions: request);
    }
    return FakeResponse(200, {'results': results, 'halted': null});
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  group('local store (US-1102, US-1103, US-1105)', () {
    late OfflineStore store;

    setUp(() => store = memoryStore());
    tearDown(() => store.close());

    test('TC-1102-01: search by normalised name or exact barcode, active products only', () async {
      await store.upsertProducts([
        productJson(id: 1, name: 'أرز مصري', barcode: '111'),
        productJson(id: 2, name: 'حليب', barcode: '222'),
        productJson(id: 3, name: 'ارز بسمتي', barcode: '333', status: 'inactive'),
      ]);

      expect([for (final p in await store.searchProducts('ارز')) p.id], [1], reason: 'أ and ا match; inactive hidden');
      expect([for (final p in await store.searchProducts('222')) p.id], [2]);
      expect((await store.productByBarcode('333')), isNull);
      expect((await store.productByBarcode('111'))!.name, 'أرز مصري');
    });

    test('TC-1103-01: a queued sale lowers shown stock and raises the balance until a later refresh', () async {
      await store.upsertProducts([productJson(id: 7, stock: '10')]);
      await store.upsertCustomers([customerJson(id: 4, balance: '20.00')]);

      final item = await store.enqueue(
        clientTransactionId: 'aaaaaaaa-0000-4000-8000-000000000001',
        userId: 1,
        type: 'sale',
        payload: {'customer_id': 4, 'paid_amount': '0.00', 'items': []},
        summary: {'total': '13.00'},
        effects: [OutboxEffect.stock(7, Quantity.whole(-2)), OutboxEffect.balance(4, Money.parse('13.00'))],
      );

      expect((await store.productByBarcode('7290000000017'))!.currentStock, Quantity.whole(8));
      expect((await store.customer(4))!.balance, Money.parse('33.00'));
      expect((await store.counts()).pending, 1);

      // Synced, then a refresh that started before the answer: the effect still counts.
      await store.settle(item.clientTransactionId, state: OutboxState.done, serverId: '9');
      await store.releaseEffects(DateTime.now().subtract(const Duration(seconds: 5)));
      expect((await store.customer(4))!.balance, Money.parse('33.00'));

      // A refresh after the answer has the server's numbers: the overlay stops counting.
      await store.upsertCustomers([customerJson(id: 4, balance: '33.00')]);
      await store.releaseEffects(DateTime.now().add(const Duration(seconds: 1)));
      expect((await store.customer(4))!.balance, Money.parse('33.00'), reason: 'counted once, not twice');
      expect((await store.counts()).pending, 0);
    });

    test('TC-1103-03: queued items and occurred_at survive reopening the database', () async {
      final at = DateTime.utc(2026, 10, 28, 19, 30);
      final file = '${await databaseFactoryFfiNoIsolate.getDatabasesPath()}/offline_restart_test.db';
      await databaseFactoryFfiNoIsolate.deleteDatabase(file);
      final first = OfflineStore(databaseFactoryFfiNoIsolate, path: file);
      await first.enqueue(
        clientTransactionId: 'aaaaaaaa-0000-4000-8000-000000000002',
        userId: 1,
        type: 'payment',
        payload: {'customer_id': 4, 'method': 'jawwal_pay', 'amount': '5.00'},
        summary: {'amount': '5.00'},
        effects: const [],
        occurredAt: at,
      );
      await first.close();

      final reopened = OfflineStore(databaseFactoryFfiNoIsolate, path: file);
      final pending = await reopened.pending();
      expect(pending.single.occurredAt.toUtc(), at);
      expect(pending.single.payload['method'], 'jawwal_pay');
      await reopened.close();
      await databaseFactoryFfiNoIsolate.deleteDatabase(file);
    });

    test('TC-1105-02: the 1001st unsynced item is refused; nothing is dropped', () async {
      for (var i = 0; i < OfflineStore.limit; i++) {
        await store.enqueue(
          clientTransactionId: 'bbbbbbbb-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          userId: 1,
          type: 'payment',
          payload: const {},
          summary: const {},
          effects: const [],
        );
      }
      await expectLater(
        store.enqueue(clientTransactionId: 'cccccccc-0000-4000-8000-000000000000', userId: 1, type: 'payment', payload: const {}, summary: const {}, effects: const []),
        throwsA(isA<QueueFull>()),
      );
      expect((await store.counts()).pending, OfflineStore.limit);
    });

    test('TC-1105-01: the warning starts at 800 and the block at 1000', () {
      expect(const SyncStatus(pending: 799).nearLimit, isFalse);
      expect(const SyncStatus(pending: 800).nearLimit, isTrue);
      expect(const SyncStatus(pending: 999).full, isFalse);
      expect(const SyncStatus(pending: 1000).full, isTrue);
    });

    test('NFR-05: a local commit takes well under 200 ms', () async {
      await store.upsertProducts([productJson(id: 7)]);
      final watch = Stopwatch()..start();
      await store.enqueue(
        clientTransactionId: 'dddddddd-0000-4000-8000-000000000001',
        userId: 1,
        type: 'sale',
        payload: const {},
        summary: const {},
        effects: [OutboxEffect.stock(7, Quantity.whole(-1))],
      );
      expect(watch.elapsedMilliseconds, lessThan(200));
    });
  });

  group('sync engine (US-1104)', () {
    late FakeApi api;
    late OfflineStore store;
    late ProviderContainer container;
    late FakeSyncServer server;

    Future<void> settle() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setUp(() async {
      api = FakeApi()..on('GET /me', meOk());
      api.onSequence('GET /sync/bootstrap', [page([productJson(id: 7)]), page([customerJson(id: 4)])]);
      server = FakeSyncServer();
      api.handle('POST /sync/batch', server.call);
      store = memoryStore();
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'})),
          httpAdapterProvider.overrideWithValue(api),
          offlineStoreProvider.overrideWithValue(store),
          syncAutoProvider.overrideWithValue(false),
        ],
      );
      container.listen(sessionProvider, (_, _) {});
      container.listen(syncEngineProvider, (_, _) {});
      await settle();
      expect(container.read(sessionProvider), isA<SignedIn>());
    });

    tearDown(() async {
      container.dispose();
      await store.close();
    });

    Future<void> queue(int n, {String type = 'payment'}) async {
      for (var i = 0; i < n; i++) {
        await store.enqueue(
          clientTransactionId: 'eeeeeeee-0000-4000-8000-${i.toString().padLeft(12, '0')}',
          userId: 1,
          type: type,
          payload: {'customer_id': 4, 'method': 'palpay', 'amount': '1.00'},
          summary: const {'amount': '1.00'},
          effects: [OutboxEffect.balance(4, Money.parse('-1.00'))],
        );
      }
    }

    test('the first sign-in fills the cache from the bootstrap', () async {
      expect(await store.productByBarcode('7290000000017'), isNotNull);
      expect(await store.meta('since.products'), '2026-10-29T09:00:00+00:00');
      expect(api.requestsTo('GET /sync/bootstrap').first.queryParameters, {'entity': 'products'});
    });

    test('TC-1104-01 / AC-07: 10 queued items reach the server in FIFO order, each once', () async {
      await queue(10);
      await container.read(syncEngineProvider.notifier).kick();

      expect(server.seqs, List.generate(10, (i) => i + 1));
      expect(server.applied, hasLength(10));
      expect((await store.counts()).pending, 0);
      expect(container.read(syncEngineProvider).pending, 0);

      await container.read(syncEngineProvider.notifier).kick();
      expect(server.seqs, hasLength(10), reason: 'nothing is sent again once answered');
      expect(server.items.first['payload'], {'customer_id': 4, 'method': 'palpay', 'amount': '1.00'});
      expect(server.items.first['type'], 'payment');
    });

    test('TC-1104-02 / AC-06: the answer is lost mid-sync; on resume nothing is duplicated or lost', () async {
      await queue(3);
      server.loseAnswer = true;
      await container.read(syncEngineProvider.notifier).kick();
      expect((await store.counts()).pending, 3, reason: 'no answer: every item stays');
      expect(server.applied, hasLength(3), reason: 'the server did act');

      await container.read(syncEngineProvider.notifier).kick();
      expect((await store.counts()).pending, 0);
      expect(server.applied, hasLength(3), reason: 'the resend is recognised as duplicate');
      expect(server.seqs, [1, 2, 3, 1, 2, 3]);
    });

    test('no connection: items stay pending and do not count as failed attempts', () async {
      await queue(2);
      api.offline('POST /sync/batch');
      await container.read(syncEngineProvider.notifier).kick();

      final pending = await store.pending();
      expect(pending, hasLength(2));
      expect(pending.every((i) => i.attempts == 0), isTrue);
      expect(container.read(serverReachableProvider), isFalse);
    });

    test('a held payment becomes "needs review" and leaves the queue', () async {
      await queue(2);
      server.statusFor = (item) => item['seq'] == 2 ? 'conflict' : 'applied';
      await container.read(syncEngineProvider.notifier).kick();

      final status = container.read(syncEngineProvider);
      expect((status.pending, status.review), (0, 1));
      final held = await store.items(states: {OutboxState.review});
      expect(held.single.lastError, startsWith('PAYMENT_EXCEEDS_REMAINING'));
    });

    test('a batch the server stopped early is resent from the unanswered item', () async {
      await queue(3);
      api.handle('POST /sync/batch', (request) {
        final first = ((request.data as Map)['items'] as List).first as Map<String, dynamic>;
        return FakeResponse(200, {
          'results': [
            {'client_transaction_id': first['client_transaction_id'], 'status': 'applied', 'server_id': 1, 'flags': [], 'error': null},
          ],
          'halted': {'client_transaction_id': 'x'},
        });
      });
      await container.read(syncEngineProvider.notifier).kick();

      final pending = await store.pending();
      expect([for (final i in pending) i.seq], [2, 3]);
      expect([for (final i in pending) i.attempts], [1, 0], reason: 'only the item that failed counts a try');
    });

    test('a delta refresh sends `since` from the last server time', () async {
      await container.read(syncEngineProvider.notifier).kick();
      api.onSequence('GET /sync/bootstrap', [page([productJson(id: 7, price: '7.00')]), page([])]);
      await container.read(syncEngineProvider.notifier).kick(refresh: true);

      final last = api.requestsTo('GET /sync/bootstrap').reversed.take(2).toList();
      expect(last.every((r) => r.queryParameters['since'] == '2026-10-29T09:00:00+00:00'), isTrue);
      expect((await store.productByBarcode('7290000000017'))!.sellingPrice, '7.00');
    });
  });

  group('indicator (TC-1104-03, FR-67)', () {
    Future<void> pumpHeader(WidgetTester tester, SyncStatus status, {bool online = true}) async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            syncEngineProvider.overrideWith(() => _FixedSync(status)),
            serverReachableProvider.overrideWith(() => _FixedReachable(online)),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: TabHeader(title: 'بيع', storeName: 'متجر')),
          ),
        ),
      );
      await tester.pump();
    }

    String pill(WidgetTester tester) =>
        tester.widgetList<Text>(find.descendant(of: find.byKey(const Key('header.connection')), matching: find.byType(Text))).single.data!;

    testWidgets('synced, synchronizing, pending (n), offline and needs review', (tester) async {
      await pumpHeader(tester, const SyncStatus(available: true));
      expect(pill(tester), 'متزامن');

      await pumpHeader(tester, const SyncStatus(available: true, pending: 3, syncing: true));
      expect(pill(tester), 'جارٍ المزامنة…');

      await pumpHeader(tester, const SyncStatus(available: true, pending: 3));
      expect(pill(tester), 'بانتظار المزامنة (3)');

      await pumpHeader(tester, const SyncStatus(available: true, pending: 3), online: false);
      expect(pill(tester), 'غير متصل · 3');

      await pumpHeader(tester, const SyncStatus(available: true, review: 2));
      expect(find.text('يحتاج مراجعة (2)'), findsOneWidget);
    });

    testWidgets('without a local store the pill stays online / offline as before R2', (tester) async {
      await pumpHeader(tester, const SyncStatus());
      expect(pill(tester), 'متصل');
    });
  });

  group('airplane mode (NFR-04, TC-1103-01)', () {
    late FakeApi api;
    late OfflineStore store;
    late List<FakeCamera> cameras;
    late FakeSyncServer server;

    setUp(() {
      api = FakeApi()
        ..on('GET /me', meOk(role: 'employee'))
        ..on('GET /dashboard', dashboardOk())
        ..onSequence('GET /sync/bootstrap', [page([milk]), page([customerJson(id: 1, balance: '0.00')])]);
      server = FakeSyncServer();
      api.handle('POST /sync/batch', server.call);
      store = memoryStore();
      cameras = [];
    });

    Future<ProviderContainer> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final beep = CountingBeep();
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'})),
            httpAdapterProvider.overrideWithValue(api),
            offlineStoreProvider.overrideWithValue(store),
            syncAutoProvider.overrideWithValue(false),
            scanCueProvider.overrideWithValue(ScanCue(beep: beep, haptic: () async {}, minGap: Duration.zero)),
            cameraPermissionsProvider.overrideWithValue(FakePermissions(CameraPermission.granted)),
            barcodeCameraFactoryProvider.overrideWithValue(() {
              final c = FakeCamera();
              cameras.add(c);
              return c;
            }),
          ],
          child: const SmartShopApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(SmartShopApp)));
    }

    /// SQLite work runs on the fake clock: pump until [future] completes.
    Future<T> settled<T>(WidgetTester tester, Future<T> future) async {
      var done = false;
      late T value;
      Object? error;
      unawaited(
        future.then(
          (v) {
            value = v;
            done = true;
          },
          onError: (Object e) {
            error = e;
            done = true;
          },
        ),
      );
      for (var i = 0; i < 500 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      if (!done) fail('did not complete');
      if (error != null) throw error!;
      return value;
    }

    Future<void> tap(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('a cash sale is saved on the phone, then synced once with the same body and method', (tester) async {
      final container = await pumpApp(tester);
      expect(await settled(tester, store.productByBarcode(milkCode)), isNotNull, reason: 'the cache was filled at sign-in');

      for (final route in ['GET /products/lookup', 'POST /sales', 'POST /sync/batch', 'GET /sync/bootstrap']) {
        api.offline(route);
      }

      await tap(tester, 'cart.scan');
      cameras.last.read(milkCode);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cart.qty.7')), findsOneWidget, reason: 'found in the local catalog');
      await tap(tester, 'cart.inc.7');
      await tap(tester, 'cart.checkout');
      await tap(tester, 'checkout.confirm');

      expect(find.byType(ReceiptScreen), findsOneWidget);
      expect(find.byKey(const Key('receipt.localRef')), findsOneWidget);
      expect(find.text('محفوظ على الهاتف بانتظار الإرسال. يُرسل تلقائيًا عند عودة الإنترنت.'), findsOneWidget);
      expect(find.byKey(const Key('receipt.void')), findsNothing);
      expect(api.requestsTo('POST /sales'), isEmpty, reason: 'offline: committed locally, not sent');
      expect(container.read(syncEngineProvider).pending, 1);
      expect((await settled(tester, store.productByBarcode(milkCode)))!.currentStock, Quantity.whole(38), reason: '40 − 2 on the phone');

      await tap(tester, 'receipt.newSale');
      expect(find.text('لا يوجد اتصال — 1 عملية محفوظة على الهاتف بانتظار الإرسال'), findsWidgets);

      for (final route in ['POST /sync/batch', 'GET /sync/bootstrap']) {
        api.restore(route);
      }
      api.onSequence('GET /sync/bootstrap', [page([productJson(id: 7, name: milk['name'] as String, barcode: milkCode, stock: '38')]), page([])]);
      await settled(tester, container.read(syncEngineProvider.notifier).kick());
      await tester.pumpAndSettle();

      expect(server.items, hasLength(1));
      final sent = server.items.single;
      expect(sent['type'], 'sale');
      expect(sent['payload'], {
        'items': [
          {'product_id': 7, 'quantity': '2'},
        ],
        'paid_amount': '13.00',
        'payment_method': 'palpay',
      });
      expect(sent['charged'], [
        {'product_id': 7, 'sale_unit': null, 'unit_price': '6.50'},
      ]);
      expect(sent['occurred_at'], isNotNull);
      expect(container.read(syncEngineProvider).pending, 0);
      expect((await settled(tester, store.productByBarcode(milkCode)))!.currentStock, Quantity.whole(38), reason: 'the server count, not 36');
    });

    testWidgets('logout is refused while sales wait to be sent', (tester) async {
      final container = await pumpApp(tester);
      await settled(
        tester,
        store.enqueue(
          clientTransactionId: 'ffffffff-0000-4000-8000-000000000001',
          userId: 1,
          type: 'sale',
          payload: const {},
          summary: const {'total': '6.50'},
          effects: const [],
        ),
      );
      await settled(tester, container.read(syncEngineProvider.notifier).reloadCounts());
      api.offline('POST /sync/batch');

      await tap(tester, 'nav.more');
      await tap(tester, 'more.logout');
      expect(find.byKey(const Key('logout.pending')), findsOneWidget);
      expect(find.byKey(const Key('logout.confirm')), findsNothing);
      expect(container.read(sessionProvider), isA<SignedIn>());
    });
  });

  test('customers are cached with their balance and limit for the offline credit check', () async {
    final store = memoryStore();
    await store.upsertCustomers([customerJson(id: 4, balance: '90.00', limit: '100.00'), {...customerJson(id: 5), 'deleted': true}]);
    final customer = (await store.searchCustomers('محمد')).single;
    expect(customer.id, 4);
    expect(customer.wouldExceedLimit(Money.parse('15.00')), isTrue);
    expect(customer, isA<Customer>());
    await store.close();
  });
}

class _FixedSync extends SyncEngine {
  _FixedSync(this.fixed);

  final SyncStatus fixed;

  @override
  SyncStatus build() => fixed;
}

class _FixedReachable extends ServerReachable {
  _FixedReachable(this.online);

  final bool online;

  @override
  bool build() => online;
}
