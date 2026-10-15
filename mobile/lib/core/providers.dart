import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/data/auth_repository.dart';
import 'api/api_client.dart';
import 'api/idempotency_key_store.dart';
import 'config/env.dart';
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

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(keyValueStoreProvider)),
);

final idempotencyKeyStoreProvider = Provider<IdempotencyKeyStore>(
  (ref) => IdempotencyKeyStore(ref.watch(keyValueStoreProvider)),
);

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
