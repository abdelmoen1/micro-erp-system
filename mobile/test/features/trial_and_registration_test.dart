import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/api/api_client.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/router/app_router.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/application/session_controller.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/domain/app_user.dart';
import 'package:smartshop/features/auth/domain/registration_form.dart';
import 'package:smartshop/features/auth/presentation/register_screen.dart';
import 'package:smartshop/features/auth/presentation/subscription_expired_screen.dart';

import '../support/fake_api.dart';

/// Mobile store-owner registration (same rules and request as the web /join form) and the
/// 7-day trial: the renewal screen, the session it keeps, and recovery after activation.
void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;

  setUp(() {
    api = FakeApi();
    disk = MemoryKeyValueStore();
    api.on('GET /dashboard', dashboardOk());
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [keyValueStoreProvider.overrideWithValue(disk), httpAdapterProvider.overrideWithValue(api)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<SessionState> settled(ProviderContainer c) async {
    c.read(sessionProvider);
    for (var i = 0; i < 50 && c.read(sessionProvider) is SessionRestoring; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return c.read(sessionProvider);
  }

  group('error mapping', () {
    late ApiClient client;
    late List<ApiFailure> global;

    setUp(() {
      global = [];
      client = ApiClient(baseUrl: 'http://api.test/api/v1', readToken: () async => 'tok', onSessionFailure: global.add, adapter: api);
    });

    test('403 SUBSCRIPTION_EXPIRED carries the support number and is a global event', () async {
      api.on('GET /x', envelope(403, 'SUBSCRIPTION_EXPIRED', details: {'state': 'inactive', 'support_whatsapp': '970599000000'}));
      final failure = await client.get('/x').then<ApiFailure?>((_) => null, onError: (Object e) => e as ApiFailure);
      expect(failure, isA<SubscriptionExpired>());
      expect((failure as SubscriptionExpired).supportWhatsapp, '970599000000');
      expect(global.single, isA<SubscriptionExpired>());
    });

    test('403 STORE_SUSPENDED is its own failure and a global event', () async {
      api.on('GET /x', envelope(403, 'STORE_SUSPENDED'));
      await expectLater(client.get('/x'), throwsA(isA<StoreSuspended>()));
      expect(global.single, isA<StoreSuspended>());
    });

    test('an empty support number reads as none', () async {
      api.on('GET /x', envelope(403, 'SUBSCRIPTION_EXPIRED', details: {'support_whatsapp': null}));
      await expectLater(client.get('/x'), throwsA(isA<SubscriptionExpired>().having((f) => f.supportWhatsapp, 'number', isNull)));
    });
  });

  group('session', () {
    test('restore: a store without access goes to the renewal state, keeping the token', () async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', meOk(hasAccess: false));

      final state = await settled(container());
      expect(state, isA<SubscriptionLapsed>());
      expect(disk.values[AuthRepository.tokenKey], 'tok');
    });

    test('login: an expired store signs in to the renewal state', () async {
      api.on('POST /login', loginOk(hasAccess: false));
      final c = container();
      await settled(c);

      await c.read(sessionProvider.notifier).login('owner@demo.test', 'secret');
      expect(c.read(sessionProvider), isA<SubscriptionLapsed>());
      expect(disk.values[AuthRepository.tokenKey], '1|test-token');
    });

    test('a 403 SUBSCRIPTION_EXPIRED mid-session moves to the renewal state without signing out', () async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', meOk());
      api.on('GET /customers', envelope(403, 'SUBSCRIPTION_EXPIRED', details: {'support_whatsapp': '970599000000'}));
      final c = container();
      expect(await settled(c), isA<SignedIn>());

      await expectLater(c.read(customerRepositoryProvider).search(''), throwsA(isA<SubscriptionExpired>()));
      await Future<void>.delayed(Duration.zero);

      final state = c.read(sessionProvider);
      expect(state, isA<SubscriptionLapsed>());
      expect((state as SubscriptionLapsed).supportWhatsapp, '970599000000');
      expect(disk.values[AuthRepository.tokenKey], 'tok');
    });

    test('check again: still inactive stays; activated returns to the app', () async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.onSequence('GET /me', [meOk(hasAccess: false), meOk()]);
      api.onSequence('GET /subscription', [subscriptionOk(), subscriptionOk(state: 'active', hasAccess: true)]);
      final c = container();
      expect(await settled(c), isA<SubscriptionLapsed>());

      final first = await c.read(sessionProvider.notifier).recheckSubscription();
      expect(first.hasAccess, isFalse);
      expect(c.read(sessionProvider), isA<SubscriptionLapsed>());

      final second = await c.read(sessionProvider.notifier).recheckSubscription();
      expect(second.hasAccess, isTrue);
      expect(c.read(sessionProvider), isA<SignedIn>());
    });

    test('login to a suspended store is blocked with the suspension reason, not the renewal screen', () async {
      api.on('POST /login', envelope(403, 'STORE_SUSPENDED'));
      final c = container();
      await settled(c);

      await expectLater(c.read(sessionProvider.notifier).login('owner@demo.test', 'secret'), throwsA(isA<StoreSuspended>()));
      final state = c.read(sessionProvider);
      expect(state, isA<AccountBlocked>());
      expect((state as AccountBlocked).storeSuspended, isTrue);
    });

    test('register posts the web fields and signs in', () async {
      api.on('POST /register', loginOk());
      final c = container();
      await settled(c);

      final draft = RegistrationDraft()
        ..storeName = ' بقالة الأمل '
        ..ownerName = 'سامي'
        ..phone = '059-912 3456'
        ..city = 'غزة'
        ..street = 'شارع الوحدة'
        ..email = ' sami@shop.ps '
        ..password = 'Password123'
        ..passwordConfirmation = 'Password123';
      await c.read(sessionProvider.notifier).register(draft.toRequest());

      expect(c.read(sessionProvider), isA<SignedIn>());
      expect(api.requestsTo('POST /register').single.data, {
        'store_name': 'بقالة الأمل',
        'owner_name': 'سامي',
        'phone': '0599123456',
        'address': 'شارع الوحدة، غزة',
        'email': 'sami@shop.ps',
        'password': 'Password123',
        'password_confirmation': 'Password123',
      });
      expect(api.requestsTo('POST /register').single.headers['Authorization'], isNull);
    });
  });

  group('router', () {
    final lapsed = SubscriptionLapsed(AppUser.fromJson(userJson(hasAccess: false)));

    test('a lapsed session can only reach the renewal screen', () {
      expect(sessionRedirect(lapsed, Uri.parse(Routes.home)), Routes.subscriptionExpired);
      expect(sessionRedirect(lapsed, Uri.parse(Routes.pos)), Routes.subscriptionExpired);
      expect(sessionRedirect(lapsed, Uri.parse(Routes.subscriptionExpired)), isNull);
    });

    test('signed out may open registration; signed in leaves it and the renewal screen', () {
      expect(sessionRedirect(const SignedOut(), Uri.parse(Routes.register)), isNull);
      final signedIn = SignedIn(AppUser.fromJson(userJson()));
      expect(sessionRedirect(signedIn, Uri.parse(Routes.register)), Routes.home);
      expect(sessionRedirect(signedIn, Uri.parse(Routes.subscriptionExpired)), Routes.home);
    });
  });

  group('registration rules (same as the web /join form)', () {
    test('step 1 needs the store and owner names', () {
      final d = RegistrationDraft()..storeName = '  ';
      expect(d.validateStep(0), {
        RegistrationField.storeName: RegistrationError.storeNameRequired,
        RegistrationField.ownerName: RegistrationError.ownerNameRequired,
      });
    });

    test('step 2: phone of 9 or 10 digits (spaces and dashes allowed), city and street', () {
      final d = RegistrationDraft()..phone = '05991';
      expect(d.validateStep(1), {
        RegistrationField.phone: RegistrationError.phoneInvalid,
        RegistrationField.city: RegistrationError.cityRequired,
        RegistrationField.street: RegistrationError.streetRequired,
      });
      d
        ..phone = '059 912-345'
        ..city = 'رفح'
        ..street = 'الشابورة';
      expect(d.validateStep(1), isEmpty);
      d.phone = '05991234567';
      expect(d.validateStep(1)[RegistrationField.phone], RegistrationError.phoneInvalid);
    });

    test('step 3: valid email, 8+ character password, matching confirmation', () {
      final d = RegistrationDraft()
        ..email = 'not-an-email'
        ..password = 'short'
        ..passwordConfirmation = 'other';
      expect(d.validateStep(2), {
        RegistrationField.email: RegistrationError.emailInvalid,
        RegistrationField.password: RegistrationError.passwordTooShort,
        RegistrationField.passwordConfirmation: RegistrationError.passwordMismatch,
      });
    });

    test('the cities are the web list', () {
      expect(registrationCities, hasLength(16));
      expect(registrationCities.first, 'الخليل');
      expect(registrationCities.last, 'رفح');
    });
  });

  group('screens', () {
    late List<Uri> launched;
    var launchResult = true;

    Future<void> pumpApp(WidgetTester tester) async {
      launched = [];
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            keyValueStoreProvider.overrideWithValue(disk),
            httpAdapterProvider.overrideWithValue(api),
            externalLinkLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return launchResult;
            }),
          ],
          child: const SmartShopApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    testWidgets('login links to registration; the three steps validate like the web and create the store', (tester) async {
      api.on('POST /register', loginOk());
      await pumpApp(tester);

      await tapKey(tester, 'login.register');
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('الخطوة 1 من 3'), findsOneWidget);

      // Step 1: empty fields are refused with the web wording.
      await tapKey(tester, 'register.next');
      expect(find.text('يرجى إدخال اسم المتجر.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('register.storeName')), 'بقالة الأمل');
      await tester.enterText(find.byKey(const Key('register.ownerName')), 'سامي');
      await tapKey(tester, 'register.next');

      // Step 2.
      expect(find.text('الخطوة 2 من 3'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('register.phone')), '1234');
      await tapKey(tester, 'register.next');
      expect(find.text('رقم الهاتف 9 أو 10 أرقام، مثل 0599123456.'), findsOneWidget);
      expect(find.text('يرجى اختيار المدينة.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('register.phone')), '0599123456');
      await tapKey(tester, 'register.city');
      await tester.tap(find.text('غزة').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('register.street')), 'شارع الوحدة');
      await tapKey(tester, 'register.next');

      // Step 3.
      expect(find.text('الخطوة 3 من 3'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('register.email')), 'sami@shop.ps');
      await tester.enterText(find.byKey(const Key('register.password')), 'Password123');
      await tester.enterText(find.byKey(const Key('register.passwordConfirmation')), 'Password12');
      await tapKey(tester, 'register.submit');
      expect(find.text('التأكيد لا يطابق كلمة المرور.'), findsOneWidget);
      expect(api.requestsTo('POST /register'), isEmpty);

      await tester.enterText(find.byKey(const Key('register.passwordConfirmation')), 'Password123');
      await tapKey(tester, 'register.submit');

      expect(api.requestsTo('POST /register').single.data, {
        'store_name': 'بقالة الأمل',
        'owner_name': 'سامي',
        'phone': '0599123456',
        'address': 'شارع الوحدة، غزة',
        'email': 'sami@shop.ps',
        'password': 'Password123',
        'password_confirmation': 'Password123',
      });
      expect(find.byType(RegisterScreen), findsNothing);
    });

    testWidgets('a taken email returns to step 3 with the web message', (tester) async {
      api.on(
        'POST /register',
        envelope(422, 'VALIDATION_FAILED', errors: {
          'email': ['The email has already been taken.'],
        }),
      );
      await pumpApp(tester);
      await tapKey(tester, 'login.register');
      await tester.enterText(find.byKey(const Key('register.storeName')), 'بقالة الأمل');
      await tester.enterText(find.byKey(const Key('register.ownerName')), 'سامي');
      await tapKey(tester, 'register.next');
      await tester.enterText(find.byKey(const Key('register.phone')), '0599123456');
      await tapKey(tester, 'register.city');
      await tester.tap(find.text('غزة').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('register.street')), 'الرمال');
      await tapKey(tester, 'register.next');
      await tester.enterText(find.byKey(const Key('register.email')), 'taken@shop.ps');
      await tester.enterText(find.byKey(const Key('register.password')), 'Password123');
      await tester.enterText(find.byKey(const Key('register.passwordConfirmation')), 'Password123');
      await tapKey(tester, 'register.submit');

      expect(find.text('لم يُنشأ المتجر: البريد الإلكتروني مستخدم.'), findsOneWidget);
      expect(find.text('هذا البريد مسجّل مسبقاً. سجّل الدخول، أو استخدم بريداً آخر.'), findsOneWidget);
      expect(find.text('الخطوة 3 من 3'), findsOneWidget);
    });

    testWidgets('an expired store lands on the Arabic renewal screen; WhatsApp opens with the store named', (tester) async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', meOk(hasAccess: false));
      api.on('GET /subscription', subscriptionOk());
      await pumpApp(tester);

      expect(find.byType(SubscriptionExpiredScreen), findsOneWidget);
      expect(find.text('انتهت الفترة التجريبية'), findsOneWidget);
      expect(find.textContaining('بياناتك محفوظة'), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(SubscriptionExpiredScreen))), TextDirection.rtl);

      await tapKey(tester, 'subscription.whatsapp');
      final uri = launched.single;
      expect('${uri.scheme}://${uri.host}${uri.path}', 'https://wa.me/970599000000');
      expect(uri.queryParameters['text'], contains('Demo Shop'));

      // Business screens are unreachable while lapsed.
      expect(find.byKey(const Key('subscription.checkAgain')), findsOneWidget);
    });

    testWidgets('no support number: the screen says how to renew without a WhatsApp button', (tester) async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', meOk(hasAccess: false));
      api.on('GET /subscription', subscriptionOk(supportWhatsapp: null));
      await pumpApp(tester);

      expect(find.byKey(const Key('subscription.whatsapp')), findsNothing);
      expect(find.byKey(const Key('subscription.noNumber')), findsOneWidget);
    });

    testWidgets('check again after the admin activates the subscription returns to the app', (tester) async {
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.onSequence('GET /me', [meOk(hasAccess: false), meOk()]);
      api.onSequence('GET /subscription', [subscriptionOk(), subscriptionOk(), subscriptionOk(state: 'active', hasAccess: true)]);
      await pumpApp(tester);

      await tapKey(tester, 'subscription.checkAgain');
      expect(find.textContaining('لم يُفعَّل الاشتراك بعد'), findsOneWidget);
      expect(find.byType(SubscriptionExpiredScreen), findsOneWidget);

      await tapKey(tester, 'subscription.checkAgain');
      expect(find.byType(SubscriptionExpiredScreen), findsNothing);
    });

    testWidgets('a WhatsApp app that cannot open shows the number to copy', (tester) async {
      launchResult = false;
      addTearDown(() => launchResult = true);
      disk.values[AuthRepository.tokenKey] = 'tok';
      api.on('GET /me', meOk(hasAccess: false));
      api.on('GET /subscription', subscriptionOk());
      await pumpApp(tester);

      await tapKey(tester, 'subscription.whatsapp');
      expect(find.textContaining('970599000000'), findsOneWidget);
    });
  });
}
