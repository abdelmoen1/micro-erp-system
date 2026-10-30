import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/customers/data/customer_repository.dart';
import '../features/more/data/more_repository.dart';
import '../features/products/data/product_repository.dart';
import '../features/goods/data/goods_repository.dart';
import '../features/products/data/stock_repository.dart';
import '../features/sale/data/sale_repository.dart';
import 'api/api_client.dart';
import 'api/idempotency_key_store.dart';
import 'config/env.dart';
import 'offline/offline_fallback.dart';
import 'offline/offline_store.dart';
import 'storage/key_value_store.dart';

/// Overridden in tests with [MemoryKeyValueStore].
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => SecureKeyValueStore());

/// Overridden in tests with a fake adapter; null uses dio's real HTTP adapter.
final httpAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

final apiBaseUrlProvider = Provider<String>((ref) => Env.apiBaseUrl);

/// Whether the last API call reached the server (drives the offline banner).
class ServerReachable extends Notifier<bool> {
  @override
  bool build() => true;

  void report(bool reachable) {
    if (state != reachable) state = reachable;
  }
}

final serverReachableProvider = NotifierProvider<ServerReachable, bool>(ServerReachable.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(keyValueStoreProvider);
  final client = ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    adapter: ref.watch(httpAdapterProvider),
    readToken: () => store.read(AuthRepository.tokenKey),
    onSessionFailure: (failure) => ref.read(sessionProvider.notifier).onSessionFailure(failure),
  );
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        ref.read(serverReachableProvider.notifier).report(true);
        handler.next(response);
      },
      onError: (error, handler) {
        ref.read(serverReachableProvider.notifier).report(error.response != null);
        handler.next(error);
      },
    ),
  );
  return client;
});

/// Whether SMS codes are on (sign-up code, «forgot password», a new number).
final authOptionsProvider = FutureProvider.autoDispose<AuthOptions>((ref) => ref.watch(authRepositoryProvider).options());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(keyValueStoreProvider)),
);

/// sqflite's platform factory where the plugin exists (the phone); none elsewhere, so desktop runs
/// and widget tests stay online-only. Offline tests pass sqflite_common_ffi.
final offlineDatabaseFactoryProvider = Provider<DatabaseFactory?>(
  (ref) => !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) ? databaseFactorySqflitePlugin : null,
);

/// R2 local database (doc 16 §2). Opens on first use; unusable → the app stays online-only.
final offlineStoreProvider = Provider<OfflineStore>((ref) {
  final store = OfflineStore(ref.watch(offlineDatabaseFactoryProvider));
  ref.onDispose(store.close);
  return store;
});

final offlineReadsProvider = Provider<OfflineReads>(
  (ref) => OfflineReads(ref.watch(offlineStoreProvider), () => ref.read(serverReachableProvider)),
);

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(apiClientProvider), offline: ref.watch(offlineReadsProvider)),
);

final idempotencyKeyStoreProvider = Provider<IdempotencyKeyStore>(
  (ref) => IdempotencyKeyStore(ref.watch(keyValueStoreProvider)),
);

final saleRepositoryProvider = Provider<SaleRepository>(
  (ref) => SaleRepository(ref.watch(apiClientProvider), ref.watch(idempotencyKeyStoreProvider)),
);

final stockRepositoryProvider = Provider<StockRepository>(
  (ref) => StockRepository(ref.watch(apiClientProvider), ref.watch(idempotencyKeyStoreProvider)),
);

final goodsRepositoryProvider = Provider<GoodsRepository>(
  (ref) => GoodsRepository(ref.watch(apiClientProvider), ref.watch(idempotencyKeyStoreProvider)),
);

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(apiClientProvider), offline: ref.watch(offlineReadsProvider)),
);

final moreRepositoryProvider = Provider<MoreRepository>((ref) => MoreRepository(ref.watch(apiClientProvider)));

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
