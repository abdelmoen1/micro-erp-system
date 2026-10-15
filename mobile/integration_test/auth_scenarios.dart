// US-1306 mobile ↔ Laravel scenarios (TC-1306-01 … 06) against a REAL local /api/v1.
//
// Shared by integration_test/auth_flow_test.dart (on a phone, secure storage) and
// test/live/auth_live_test.dart (on the host). Use a disposable local database only:
// the scenarios create invited employees and deactivate one of them.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/api/api_client.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/application/session_controller.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/domain/app_user.dart';

const ownerEmail = String.fromEnvironment('LIVE_OWNER_EMAIL', defaultValue: 'owner@demo.test');
const ownerPassword = String.fromEnvironment('LIVE_OWNER_PASSWORD', defaultValue: 'password123');
const _password = 'Hisbah-Live-2026!';

void defineAuthScenarios({required String baseUrl, required KeyValueStore Function() newStore}) {
  final run = DateTime.now().millisecondsSinceEpoch;
  final activeEmail = 'live.emp.$run@demo.test';
  final inactiveEmail = 'live.off.$run@demo.test';

  ApiClient raw([String? token]) => ApiClient(baseUrl: baseUrl, readToken: () async => token);

  ProviderContainer container(KeyValueStore store) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [keyValueStoreProvider.overrideWithValue(store), apiBaseUrlProvider.overrideWithValue(baseUrl)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<SessionState> settled(ProviderContainer c) async {
    c.read(sessionProvider);
    for (var i = 0; i < 200 && c.read(sessionProvider) is SessionRestoring; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return c.read(sessionProvider);
  }

  Future<int> inviteEmployee(String ownerToken, String email) async {
    final invitation = await raw(ownerToken).post('/invitations', body: {'email': email, 'role': 'employee'});
    final token = (invitation['invitation'] as Map)['token'];
    final created = await raw().post(
      '/register/invitation',
      auth: false,
      body: {
        'token': token,
        'name': 'Live $email',
        'email': email,
        'password': _password,
        'password_confirmation': _password,
      },
    );
    return ((created['user'] as Map)['id'] as num).toInt();
  }

  setUpAll(() async {
    final owner = await raw().post('/login', auth: false, body: {'email': ownerEmail, 'password': ownerPassword});
    final ownerToken = owner['token'] as String;
    await inviteEmployee(ownerToken, activeEmail);
    final inactiveId = await inviteEmployee(ownerToken, inactiveEmail);
    await raw(ownerToken).post('/users/$inactiveId/deactivate');
  });

  test('TC-1306-01 login OK: employee signs in, token stored, role landing = POS', () async {
    final store = newStore();
    final c = container(store);
    await settled(c);

    await c.read(sessionProvider.notifier).login(activeEmail, _password);

    final state = c.read(sessionProvider) as SignedIn;
    expect(state.user.email, activeEmail);
    expect(state.user.role, UserRole.employee);
    expect(state.user.role.landsOnPos, isTrue);
    expect(await store.read(AuthRepository.tokenKey), isNotEmpty);
  });

  test('TC-1306-02 wrong password → INVALID_CREDENTIALS, nothing stored', () async {
    final store = newStore();
    final c = container(store);
    await settled(c);

    await expectLater(
      c.read(sessionProvider.notifier).login(activeEmail, 'not-the-password'),
      throwsA(isA<InvalidCredentials>()),
    );
    expect(c.read(sessionProvider), isA<SignedOut>());
    expect(await store.read(AuthRepository.tokenKey), isNull);
  });

  test('TC-1306-03 sixth failed attempt → 429 with Retry-After', () async {
    final c = container(newStore());
    await settled(c);
    final email = 'live.nobody.$run@demo.test';

    for (var i = 0; i < 5; i++) {
      await expectLater(c.read(sessionProvider.notifier).login(email, 'x'), throwsA(isA<InvalidCredentials>()));
    }
    final sixth = c.read(sessionProvider.notifier).login(email, 'x');
    await expectLater(
      sixth,
      throwsA(isA<TooManyRequests>().having((f) => f.retryAfter.inSeconds, 'retryAfter', inInclusiveRange(1, 60))),
    );
  });

  test('TC-1306-04 deactivated user → 403 USER_INACTIVE, app blocked', () async {
    final store = newStore();
    final c = container(store);
    await settled(c);

    await expectLater(c.read(sessionProvider.notifier).login(inactiveEmail, _password), throwsA(isA<UserInactive>()));
    expect(c.read(sessionProvider), isA<AccountBlocked>());
    expect(await store.read(AuthRepository.tokenKey), isNull);
  });

  test('TC-1306-05 logout revokes the token: the next call with it → 401', () async {
    final store = newStore();
    final c = container(store);
    await settled(c);
    await c.read(sessionProvider.notifier).login(activeEmail, _password);
    final token = await store.read(AuthRepository.tokenKey);

    await c.read(sessionProvider.notifier).logout();

    expect(await store.read(AuthRepository.tokenKey), isNull);
    await expectLater(raw(token).get('/me'), throwsA(isA<Unauthenticated>()));
  });

  test('TC-1306-06 session restore after app restart', () async {
    final store = newStore();
    final first = container(store);
    await settled(first);
    await first.read(sessionProvider.notifier).login(activeEmail, _password);
    final userId = (first.read(sessionProvider) as SignedIn).user.id;

    final afterRestart = container(store); // same persisted storage, fresh app state
    final state = await settled(afterRestart);
    expect(state, isA<SignedIn>());
    expect((state as SignedIn).user.id, userId);
  });
}
