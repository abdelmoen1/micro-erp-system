import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/domain/phone_number.dart';
import 'package:smartshop/features/auth/presentation/register_screen.dart';

import '../support/fake_api.dart';

/// Sign-in by mobile number: login by phone (older accounts by e-mail), a forgotten password and
/// sign-up with the SMS code, and adding the number to an older account, against a faked API.
void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;

  const otpOn = FakeResponse(200, {
    'data': {'login': 'phone', 'otp': true},
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [keyValueStoreProvider.overrideWithValue(disk), httpAdapterProvider.overrideWithValue(api)],
        child: const SmartShopApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pump();
  }

  setUp(() {
    api = FakeApi()..on('GET /dashboard', dashboardOk());
    disk = MemoryKeyValueStore();
  });

  test('a number is kept in one local form, like the server', () {
    for (final input in ['0599123456', '059 912 3456', '+970 599 123 456', '00970599123456', '٠٥٩٩١٢٣٤٥٦']) {
      expect(normalizePhone(input), '0599123456', reason: input);
    }
    expect(normalizePhone('+972521234567'), '0521234567');
    for (final bad in ['599123456', '0699123456', '05991234', 'abc', '']) {
      expect(normalizePhone(bad), isNull, reason: bad);
    }
    expect(maskPhone('0599123456'), '059•••••56');
  });

  testWidgets('login by mobile number: Arabic digits and +970 are read as 05…', (tester) async {
    api.on('POST /login', loginOk());
    await pumpApp(tester);

    expect(find.text('رقم الجوال'), findsOneWidget);
    expect(find.byKey(const Key('login.forgot')), findsNothing, reason: 'no SMS codes, no reset by code');
    await type(tester, 'login.id', '+970 ٥٩٩ ١٢٣ ٤٥٦');
    await type(tester, 'login.password', 'secret');
    await tapKey(tester, 'login.submit');

    expect(api.requestsTo('POST /login').single.data, {'login': '0599123456', 'password': 'secret'});
  });

  testWidgets('an older account switches to its e-mail', (tester) async {
    api.on('POST /login', loginOk());
    await pumpApp(tester);

    await tapKey(tester, 'login.mode');
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    await type(tester, 'login.id', 'owner@shop.ps');
    await type(tester, 'login.password', 'secret');
    await tapKey(tester, 'login.submit');

    expect(api.requestsTo('POST /login').single.data, {'login': 'owner@shop.ps', 'password': 'secret'});
  });

  testWidgets('a forgotten password: the number, the SMS code and a new password', (tester) async {
    api
      ..on('GET /auth/options', otpOn)
      ..on('POST /auth/otp', const FakeResponse(200, {'data': {'expires_in': 600, 'resend_in': 60}}))
      ..on('POST /auth/password/reset', const FakeResponse(200, {'message': 'تم'}));
    await pumpApp(tester);

    await tapKey(tester, 'login.forgot');
    await tapKey(tester, 'reset.submit');
    expect(find.text('اكتب رقم جوالك.'), findsOneWidget);
    expect(api.requestsTo('POST /auth/otp'), isEmpty);

    await type(tester, 'reset.phone', '059 912 3456');
    await tapKey(tester, 'reset.submit');
    expect(api.requestsTo('POST /auth/otp').single.data, {'phone': '0599123456', 'purpose': 'reset'});
    expect(find.text('أرسلنا رمزاً من 6 أرقام برسالة إلى 059•••••56.'), findsOneWidget);
    expect(find.text('رمز جديد بعد 60 ث'), findsOneWidget);

    await type(tester, 'reset.code', '123456');
    await type(tester, 'reset.password', 'New-pass-2026');
    await type(tester, 'reset.confirm', 'New-pass-2026');
    await tapKey(tester, 'reset.submit');

    expect(api.requestsTo('POST /auth/password/reset').single.data, {
      'phone': '0599123456',
      'otp_code': '123456',
      'password': 'New-pass-2026',
      'password_confirmation': 'New-pass-2026',
    });
    expect(find.byKey(const Key('login.id')), findsOneWidget, reason: 'back on the login screen');
    expect(find.textContaining('تم تغيير كلمة المرور'), findsOneWidget);
  });

  testWidgets('with SMS codes on, sign-up confirms the number before the store is created', (tester) async {
    api
      ..on('GET /auth/options', otpOn)
      ..on('POST /auth/otp', const FakeResponse(200, {'data': {'expires_in': 600, 'resend_in': 60}}))
      ..on('POST /register', loginOk());
    await pumpApp(tester);

    await tapKey(tester, 'login.register');
    await type(tester, 'register.storeName', 'بقالة الأمل');
    await type(tester, 'register.ownerName', 'سامي');
    await tapKey(tester, 'register.next');
    await type(tester, 'register.phone', '0599 123 456');
    await tapKey(tester, 'register.city');
    await tester.tap(find.text('غزة').last);
    await tester.pumpAndSettle();
    await type(tester, 'register.street', 'شارع الوحدة');
    await tapKey(tester, 'register.next');
    // No e-mail: it is optional now.
    await type(tester, 'register.password', 'Password123');
    await type(tester, 'register.passwordConfirmation', 'Password123');
    await tapKey(tester, 'register.submit');

    expect(api.requestsTo('POST /register'), isEmpty);
    expect(api.requestsTo('POST /auth/otp').single.data, {'phone': '0599123456', 'purpose': 'register'});
    expect(find.textContaining('رمز التأكيد'), findsOneWidget);

    await tapKey(tester, 'register.submit');
    expect(find.text('الرمز 6 أرقام.'), findsOneWidget);
    await type(tester, 'register.otpCode', '482913');
    await tapKey(tester, 'register.submit');

    expect(api.requestsTo('POST /register').single.data, {
      'store_name': 'بقالة الأمل',
      'owner_name': 'سامي',
      'owner_phone': '0599123456',
      'phone': '0599123456',
      'address': 'شارع الوحدة، غزة',
      'area': 'غزة',
      'password': 'Password123',
      'password_confirmation': 'Password123',
      'otp_code': '482913',
    });
    expect(find.byType(RegisterScreen), findsNothing);
  });

  testWidgets('a wrong code keeps the code view; a taken number goes back to the number', (tester) async {
    api
      ..on('GET /auth/options', otpOn)
      ..on('POST /auth/otp', const FakeResponse(200, {'data': {'resend_in': 60}}))
      ..onSequence('POST /register', [
        envelope(422, 'VALIDATION_FAILED', errors: {'otp_code': ['الرمز غير صحيح.']}),
        envelope(422, 'VALIDATION_FAILED', errors: {'owner_phone': ['هذا الرقم مسجّل لحساب آخر.']}),
      ]);
    await pumpApp(tester);

    await tapKey(tester, 'login.register');
    await type(tester, 'register.storeName', 'بقالة الأمل');
    await type(tester, 'register.ownerName', 'سامي');
    await tapKey(tester, 'register.next');
    await type(tester, 'register.phone', '0599123456');
    await tapKey(tester, 'register.city');
    await tester.tap(find.text('غزة').last);
    await tester.pumpAndSettle();
    await type(tester, 'register.street', 'الرمال');
    await tapKey(tester, 'register.next');
    await type(tester, 'register.password', 'Password123');
    await type(tester, 'register.passwordConfirmation', 'Password123');
    await tapKey(tester, 'register.submit');
    await type(tester, 'register.otpCode', '111111');
    await tapKey(tester, 'register.submit');

    expect(find.text('الرمز غير صحيح.'), findsOneWidget);
    expect(find.byKey(const Key('register.otpCode')), findsOneWidget);

    await type(tester, 'register.otpCode', '222222');
    await tapKey(tester, 'register.submit');
    expect(find.text('هذا الرقم مسجّل لحساب آخر.'), findsOneWidget);
    expect(find.text('الخطوة 2 من 3: الموقع والتواصل'), findsOneWidget);
  });

  testWidgets('an older e-mail account adds its number from More', (tester) async {
    disk.values[AuthRepository.tokenKey] = 'tok';
    api
      ..on('GET /me', meOk())
      ..on('PATCH /me/phone', FakeResponse(200, {'message': 'تم', 'user': {...userJson(), 'phone': '0599123456'}}));
    await pumpApp(tester);

    await tapKey(tester, 'nav.more');
    expect(find.text('أضف رقمك لتدخل به بدل البريد'), findsOneWidget);
    await tapKey(tester, 'more.phone');
    await tapKey(tester, 'phone.save');
    expect(find.text('اكتب رقم جوالك.'), findsOneWidget);
    expect(api.requestsTo('PATCH /me/phone'), isEmpty);

    await type(tester, 'phone.number', '0599 123 456');
    await type(tester, 'phone.password', 'password');
    await tapKey(tester, 'phone.save');

    expect(api.requestsTo('PATCH /me/phone').single.data, {'phone': '0599123456', 'current_password': 'password'});
    expect(find.text('0599123456'), findsOneWidget, reason: 'the tile shows the new number');
  });
}
