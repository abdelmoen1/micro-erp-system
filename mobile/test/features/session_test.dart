import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/router/app_router.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/application/session_controller.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/domain/app_user.dart';

import '../support/fake_api.dart';

/// TC-0205-01: session restore, 401 handling and logout.
void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;

  ProviderContainer container() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [keyValueStoreProvider.overrideWithValue(disk), httpAdapterProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Reads the session and waits until restore has finished.
  Future<SessionState> settled(ProviderContainer c) async {
    c.read(sessionProvider);
    for (var i = 0; i < 50 && c.read(sessionProvider) is SessionRestoring; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(sessionProvider);
  }

  setUp(() {
    api = FakeApi();
    disk = MemoryKeyValueStore();
  });

  group('restore on launch', () {
    test('no stored token → signed out, no request', () async {
      expect(await settled(container()), isA<SignedOut>());
      expect(api.requests, isEmpty);
    });

    test('stored token + GET /me 200 → signed in', () async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', meOk(role: 'employee'));

      final state = await settled(container());
      expect(state, isA<SignedIn>());
      expect((state as SignedIn).user.role, UserRole.employee);
      expect(api.requests.single.headers['Authorization'], 'Bearer tok');
    });

    test('expired or revoked token (401) → signed out as "session expired", storage cleared', () async {
      disk.values[AuthRepository.tokenKey] = 'old';
      api.on('GET /me', envelope(401, 'UNAUTHENTICATED'));

      final state = await settled(container());
      expect((state as SignedOut).reason, SignedOutReason.sessionExpired);
      expect(disk.values, isEmpty);
    });

    test('deactivated user (403 USER_INACTIVE) → blocked', () async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', envelope(403, 'USER_INACTIVE'));

      final state = await settled(container());
      expect(state, isA<AccountBlocked>());
      expect((state as AccountBlocked).storeMissing, isFalse);
      expect(disk.values.containsKey(AuthRepository.tokenKey), isFalse);
    });

    test('server unreachable → signed in offline with the cached user', () async {
      final c1 = container();
      api.on('POST /login', loginOk(id: 7, role: 'manager'));
      await settled(c1);
      await c1.read(sessionProvider.notifier).login('manager@demo.test', 'pw');

      api.offline('GET /me');
      final c2 = container(); // app restart
      final state = await settled(c2);
      expect((state as SignedIn).user.id, 7);
      expect(c2.read(serverReachableProvider), isFalse);
    });
  });

  test('login stores the token in secure storage and signs in', () async {
    final c = container();
    await settled(c);
    api.on('POST /login', loginOk(role: 'owner'));

    await c.read(sessionProvider.notifier).login('  owner@demo.test ', 'password123');

    expect(c.read(sessionProvider), isA<SignedIn>());
    expect(disk.values[AuthRepository.tokenKey], '1|test-token');
    expect(api.requests.single.data, {'email': 'owner@demo.test', 'password': 'password123'});
    expect(api.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('wrong password is rethrown for the screen and changes nothing', () async {
    final c = container();
    await settled(c);
    api.on('POST /login', envelope(401, 'INVALID_CREDENTIALS'));

    await expectLater(c.read(sessionProvider.notifier).login('a@b.co', 'x'), throwsA(isA<InvalidCredentials>()));
    expect(c.read(sessionProvider), isA<SignedOut>());
    expect(disk.values, isEmpty);
  });

  test('logout revokes the token on the server and clears storage', () async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api.on('GET /me', meOk());
    api.on('POST /logout', const FakeResponse(200, {'message': 'ok'}));
    final c = container();
    await settled(c);

    await c.read(sessionProvider.notifier).logout();

    expect(api.requestsTo('POST /logout').single.headers['Authorization'], 'Bearer tok');
    expect(c.read(sessionProvider), isA<SignedOut>());
    expect(disk.values, isEmpty);
  });

  test('logout without network still clears the local session', () async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api.on('GET /me', meOk());
    api.offline('POST /logout');
    final c = container();
    await settled(c);

    await c.read(sessionProvider.notifier).logout();
    expect(c.read(sessionProvider), isA<SignedOut>());
    expect(disk.values, isEmpty);
  });

  test('401 on any later call → session expired, remembering the user for return-to-place', () async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api.on('GET /me', meOk(id: 5));
    final c = container();
    await settled(c);

    api.on('GET /dashboard', envelope(401, 'UNAUTHENTICATED'));
    await expectLater(c.read(apiClientProvider).get('/dashboard'), throwsA(isA<Unauthenticated>()));
    await Future<void>.delayed(Duration.zero);

    final state = c.read(sessionProvider) as SignedOut;
    expect(state.reason, SignedOutReason.sessionExpired);
    expect(state.previousUserId, 5);
    expect(disk.values, isEmpty);
  });

  group('router redirect (role landing, guard, return-to-place)', () {
    AppUser user(String role, {int id = 1}) => AppUser.fromJson(userJson(id: id, role: role));

    test('role landing: employee → POS, owner / manager → Home', () {
      expect(sessionRedirect(SignedIn(user('employee')), Uri.parse('/login')), Routes.pos);
      expect(sessionRedirect(SignedIn(user('owner')), Uri.parse('/splash')), Routes.home);
      expect(sessionRedirect(SignedIn(user('manager')), Uri.parse('/login')), Routes.home);
    });

    test('guards: restoring → splash, signed out → login, blocked → login', () {
      expect(sessionRedirect(const SessionRestoring(), Uri.parse('/pos')), Routes.splash);
      expect(sessionRedirect(const SignedOut(), Uri.parse('/home')), Routes.login);
      expect(sessionRedirect(const AccountBlocked(storeMissing: false), Uri.parse('/pos')), Routes.login);
      expect(sessionRedirect(SignedIn(user('owner')), Uri.parse('/customers')), isNull);
    });

    test('expired mid-use: same user returns to the same place, another user gets role landing', () {
      final toLogin = sessionRedirect(
        const SignedOut(reason: SignedOutReason.sessionExpired, previousUserId: 5),
        Uri.parse('/customers'),
      )!;
      final loginUri = Uri.parse(toLogin);
      expect(loginUri.path, Routes.login);
      expect(loginUri.queryParameters, {'expired': '1', 'from': '/customers', 'uid': '5'});

      expect(sessionRedirect(SignedIn(user('employee', id: 5)), loginUri), '/customers');
      expect(sessionRedirect(SignedIn(user('employee', id: 9)), loginUri), Routes.pos);
    });
  });
}
