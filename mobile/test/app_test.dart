import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/presentation/login_screen.dart';

import 'support/fake_api.dart';

void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;

  /// Realistic phone surface (360 × 780 dp) and optional system text scale.
  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [keyValueStoreProvider.overrideWithValue(disk), httpAdapterProvider.overrideWithValue(api)],
        child: const SmartShopApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submitLogin(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('login.email')), email);
    await tester.enterText(find.byKey(const Key('login.password')), password);
    await tester.ensureVisible(find.byKey(const Key('login.submit')));
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeApi();
    disk = MemoryKeyValueStore();
    // Home (owner / manager landing) loads today's dashboard.
    api.on('GET /dashboard', dashboardOk());
  });

  testWidgets('TC-1303-01 app boots to the Arabic login screen when signed out', (tester) async {
    await pumpApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    // Title and button share the label (hi-fi M-01).
    expect(find.text('تسجيل الدخول'), findsNWidgets(2));
    expect(find.text('أدخل بيانات حسابك في المتجر'), findsOneWidget);
  });

  testWidgets('TC-1303-02 layout direction is RTL', (tester) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(LoginScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context).languageCode, 'ar');
  });

  group('login states (docs/design/ia.md §4.1)', () {
    testWidgets('client-side validation in Arabic, no request sent', (tester) async {
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo', '');
      expect(find.text('صيغة البريد الإلكتروني غير صحيحة'), findsOneWidget);
      expect(find.text('أدخل كلمة المرور'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('invalid credentials: banner, email kept, password cleared', (tester) async {
      api.on('POST /login', envelope(401, 'INVALID_CREDENTIALS'));
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'wrong');

      expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'), findsOneWidget);
      expect(find.text('owner@demo.test'), findsOneWidget);
      final password = tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('login.password')), matching: find.byType(EditableText)),
      );
      expect(password.controller.text, isEmpty);
    });

    testWidgets('server field errors (English, DEF-19) are shown in Arabic', (tester) async {
      api.on(
        'POST /login',
        envelope(
          422,
          'VALIDATION_FAILED',
          errors: {
            'password': ['The password field is required.'],
          },
        ),
      );
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'x');
      expect(find.text('أدخل كلمة المرور'), findsOneWidget);
      expect(find.textContaining('The password'), findsNothing);
    });

    testWidgets('throttled: countdown from Retry-After, button disabled until 0', (tester) async {
      api.on('POST /login', envelope(429, 'TOO_MANY_REQUESTS', headers: {'retry-after': '3'}));
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'wrong');

      expect(find.text('محاولات كثيرة. يمكنك المحاولة بعد 0:03'), findsOneWidget);
      expect(find.text('انتظر 0:03'), findsOneWidget);
      FilledButton button() => tester.widget<FilledButton>(find.byKey(const Key('login.submit')));
      expect(button().onPressed, isNull);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('محاولات كثيرة. يمكنك المحاولة بعد 0:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('محاولات كثيرة'), findsNothing);
      expect(button().onPressed, isNotNull);
    });

    testWidgets('network error: banner and retry action', (tester) async {
      api.offline('POST /login');
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'pw');
      expect(find.text('تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('server error shows the short support reference', (tester) async {
      api.on('POST /login', envelope(500, 'SERVER_ERROR'));
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'pw');
      expect(find.text('حدث خطأ في الخادم. أعد المحاولة بعد قليل.'), findsOneWidget);
      expect(find.text('رمز المرجع: 7EFV4Y'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('deactivated account: banner on the login screen, email kept, no token', (tester) async {
      api.on('POST /login', envelope(403, 'USER_INACTIVE'));
      await pumpApp(tester);
      await submitLogin(tester, 'employee@demo.test', 'pw');

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('هذا الحساب موقوف. تواصل مع مالك المتجر لإعادة تفعيله.'), findsOneWidget);
      expect(find.text('employee@demo.test'), findsOneWidget);
      expect(disk.values, isEmpty);
    });
  });

  testWidgets('employee lands on POS; logout returns to login and clears storage', (tester) async {
    api.on('POST /login', loginOk(role: 'employee'));
    api.on('POST /logout', const FakeResponse(200, {'message': 'ok'}));
    await pumpApp(tester);
    await submitLogin(tester, 'employee@demo.test', 'pw');

    expect(find.text('امسح منتجاً للبدء'), findsOneWidget); // M-02 empty cart
    expect(disk.values[AuthRepository.tokenKey], '1|test-token');

    await tester.tap(find.byKey(const Key('nav.more')));
    await tester.pumpAndSettle();
    // Below the «More» sections: scroll to it first.
    await tester.ensureVisible(find.byKey(const Key('more.logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more.logout')));
    await tester.pumpAndSettle();
    // The confirm sheet puts "stay" first; staying keeps the session.
    await tester.tap(find.byKey(const Key('logout.stay')));
    await tester.pumpAndSettle();
    expect(api.requestsTo('POST /logout'), isEmpty);

    // Below the «More» sections: scroll to it first.
    await tester.ensureVisible(find.byKey(const Key('more.logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more.logout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout.confirm')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(disk.values, isEmpty);
    expect(api.requestsTo('POST /logout'), hasLength(1));
  });

  testWidgets('owner session is restored on launch and lands on Home', (tester) async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api.on('GET /me', meOk(role: 'owner'));
    await pumpApp(tester);
    expect(find.text('أهلاً، Demo owner'), findsOneWidget);
    expect(find.text('1,250.50 ₪'), findsOneWidget);
    expect(find.text('لا فواتير بعد'), findsOneWidget);
    expect(find.byKey(const Key('home.noInvoices')), findsOneWidget);
    expect(api.requestsTo('GET /dashboard').single.queryParameters, {'period': 'today'});
  });

  testWidgets("Home lists today's latest invoices and its shortcut opens POS", (tester) async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api.on('GET /me', meOk(role: 'owner'));
    api.on(
      'GET /dashboard',
      dashboardOk(
        recentInvoices: [
          {'id': 7, 'customer': {'id': 3, 'name': 'أبو أحمد'}, 'total_amount': '400.00', 'type': 'credit', 'created_at': '2026-10-17T09:30:00Z'},
          {'id': 6, 'customer': null, 'total_amount': '25.00', 'type': 'cash', 'created_at': null},
        ],
      ),
    );
    await pumpApp(tester);
    expect(find.text('فاتورتان'), findsOneWidget);
    expect(find.text('أبو أحمد'), findsOneWidget);
    expect(find.text('زبون نقدي'), findsOneWidget);
    expect(find.text('4 زبائن مدينون'), findsOneWidget);

    // Scroll the shortcuts out from under the bottom bar before tapping.
    await tester.drag(find.byKey(const Key('home.today')), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home.shortcut.pos')));
    await tester.pumpAndSettle();
    expect(find.text('امسح منتجاً للبدء'), findsOneWidget); // M-02 empty cart
  });

  testWidgets('Home shows a retry when the dashboard fails to load', (tester) async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api.on('GET /me', meOk(role: 'owner'));
    api.onSequence('GET /dashboard', [envelope(500, 'SERVER_ERROR'), dashboardOk()]);
    await pumpApp(tester);
    expect(find.text('تعذّر تحميل لوحة اليوم.'), findsOneWidget);

    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('1,250.50 ₪'), findsOneWidget);
  });

  testWidgets('expired token on launch shows the "session expired" message', (tester) async {
    disk.values[AuthRepository.tokenKey] = 'old';
    api.on('GET /me', envelope(401, 'UNAUTHENTICATED'));
    await pumpApp(tester);
    expect(find.text('انتهت الجلسة. سجّل الدخول للمتابعة.'), findsOneWidget);
  });

  testWidgets('offline banner appears when the server is unreachable', (tester) async {
    api.on('POST /login', loginOk(role: 'owner'));
    await pumpApp(tester);
    await submitLogin(tester, 'owner@demo.test', 'pw');
    expect(find.text('لا يوجد اتصال — البيع يحتاج إلى الإنترنت'), findsNothing);

    api.offline('GET /dashboard');
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    // Not awaited directly: dio's timers only advance while the fake clock is pumped.
    Object? error;
    unawaited(
      container.read(apiClientProvider).get('/dashboard').catchError((Object e) {
        error = e;
        return <String, dynamic>{};
      }),
    );
    await tester.pumpAndSettle();
    expect(error, isA<NetworkFailure>());
    expect(find.text('لا يوجد اتصال — البيع يحتاج إلى الإنترنت'), findsOneWidget);
  });

  group('shell (hi-fi board, US-1505 TL change)', () {
    testWidgets('بيع is the exact centre of the bar; RTL order of the other tabs', (tester) async {
      api.on('POST /login', loginOk(role: 'owner'));
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'pw');

      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final circle = tester.getRect(find.byKey(const Key('nav.pos.circle')));
      expect(circle.center.dx, moreOrLessEquals(width / 2, epsilon: 0.5));
      expect(circle.width, 58); // solid teal on another tab

      double x(String key) => tester.getCenter(find.byKey(Key(key))).dx;
      // RTL: الرئيسية at the right edge, المزيد at the left.
      expect(x('nav.home') > x('nav.customers'), isTrue);
      expect(x('nav.customers') > circle.center.dx, isTrue);
      expect(circle.center.dx > x('nav.products'), isTrue);
      expect(x('nav.products') > x('nav.more'), isTrue);

      await tester.tap(find.byKey(const Key('nav.pos')));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const Key('nav.pos.circle'))).width, 54); // outline when current
      expect(find.text('امسح منتجاً للبدء'), findsOneWidget); // M-02 empty cart
    });

    testWidgets('the raised part of بيع above the bar is tappable', (tester) async {
      api.on('POST /login', loginOk(role: 'owner'));
      await pumpApp(tester);
      await submitLogin(tester, 'owner@demo.test', 'pw');

      final circle = tester.getRect(find.byKey(const Key('nav.pos.circle')));
      await tester.tapAt(circle.topCenter + const Offset(0, 6));
      await tester.pumpAndSettle();
      expect(find.text('امسح منتجاً للبدء'), findsOneWidget); // M-02 empty cart
    });

    for (final role in ['owner', 'employee']) {
      testWidgets('login and shell hold at 130% text without overflow ($role)', (tester) async {
        api.on('POST /login', envelope(401, 'INVALID_CREDENTIALS'));
        await pumpApp(tester, textScale: 1.3);
        await submitLogin(tester, 'owner@demo.test', 'wrong');
        expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'), findsOneWidget);

        api.on('POST /login', loginOk(role: role));
        await submitLogin(tester, 'owner@demo.test', 'pw');
        for (final tab in ['nav.home', 'nav.customers', 'nav.pos', 'nav.products', 'nav.more']) {
          await tester.tap(find.byKey(Key(tab)));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
