import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/core/widgets/ltr_value.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/auth/presentation/login_screen.dart';
import 'package:smartshop/features/scanner/application/lookup_controller.dart';
import 'package:smartshop/features/scanner/domain/barcode_camera.dart';
import 'package:smartshop/features/scanner/presentation/scanner_screen.dart';

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;

class FakePermissions implements CameraPermissions {
  FakePermissions(this.current, {CameraPermission? afterRequest}) : afterRequest = afterRequest ?? current;

  CameraPermission current;

  /// What the system dialog answers.
  CameraPermission afterRequest;
  int statusChecks = 0;
  int requests = 0;
  int settingsOpened = 0;

  @override
  Future<CameraPermission> status() async {
    statusChecks++;
    return current;
  }

  @override
  Future<CameraPermission> request() async {
    requests++;
    return current = afterRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

class FakeCamera implements BarcodeCamera {
  final _codes = StreamController<String>.broadcast();
  final _torch = ValueNotifier(TorchMode.off);
  int pauses = 0;
  int resumes = 0;
  bool disposed = false;

  void read(String code) => _codes.add(code);

  @override
  Stream<String> get detections => _codes.stream;

  @override
  ValueNotifier<TorchMode> get torch => _torch;

  @override
  Widget buildPreview(BuildContext context, Rect scanWindow) =>
      const ColoredBox(key: Key('fake.preview'), color: Color(0xFF444444));

  @override
  Future<void> pause() async => pauses++;

  @override
  Future<void> resume() async => resumes++;

  @override
  Future<void> toggleTorch() async => _torch.value = _torch.value == TorchMode.on ? TorchMode.off : TorchMode.on;

  @override
  Future<void> dispose() async => disposed = true;
}

const rice = '6221007012345';
const correlationId = '01M4TX2BQ5JA9MSMRA877EFV4Y';

FakeResponse found({String name = 'أرز بسمتي 2 كغ', String price = '13.00', String stock = '24'}) => FakeResponse(200, {
  'data': {...productJson(name: name, barcode: rice, stock: stock), 'selling_price': price, 'cost_price': '9.00'},
  'meta': {'currency': 'ILS'},
});

void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;
  late FakePermissions permissions;
  late List<FakeCamera> cameras;

  /// Signed-in employee (lands on بيع) on a 360 × 760 dp phone.
  Future<void> pumpApp(WidgetTester tester, {double textScale = 1}) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    // Android status bar (24 dp) and 3-button navigation (48 dp), as in the hi-fi frames.
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 144);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(disk),
          httpAdapterProvider.overrideWithValue(api),
          cameraPermissionsProvider.overrideWithValue(permissions),
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
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    // Centred, so a scrolled-to control is never left behind the bottom bar (large text).
    await Scrollable.ensureVisible(tester.element(find.byKey(Key(key))), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> openScanner(WidgetTester tester) => tapKey(tester, 'scan.open');

  Future<void> read(WidgetTester tester, String code) async {
    cameras.last.read(code);
    await tester.pumpAndSettle();
  }

  /// Android back (goes through the router and the scanner's PopScope).
  Future<void> systemBack(WidgetTester tester) async {
    // ignore: invalid_use_of_protected_member
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeApi();
    disk = MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'});
    permissions = FakePermissions(CameraPermission.granted);
    cameras = [];
    api.on('GET /me', meOk(role: 'employee'));
    api.on('GET /dashboard', dashboardOk());
  });

  group('A · B entry and permission', () {
    testWidgets('the بيع tab gains one card; the camera permission is not touched until the tap', (tester) async {
      permissions = FakePermissions(CameraPermission.denied, afterRequest: CameraPermission.granted);
      await pumpApp(tester);

      expect(find.byKey(const Key('scan.entry')), findsOneWidget);
      expect(find.text('عرض بيانات منتج'), findsOneWidget);
      expect(find.text('الاسم والسعر والمخزون. للعرض فقط، لا يُضاف إلى بيع.'), findsOneWidget);
      // Visible above the bottom bar without scrolling (hi-fi A at 360 × 760).
      expect(find.byKey(const Key('scan.open')).hitTestable(), findsOneWidget);
      expect(permissions.statusChecks + permissions.requests, 0);

      await openScanner(tester);
      expect(permissions.requests, 1);
      expect(find.byType(ScannerScreen), findsOneWidget);
      expect(find.text('وجّه الباركود داخل الإطار'), findsOneWidget);
      expect(find.text('جارٍ البحث عن باركود…'), findsOneWidget);
      // Full screen: the bottom navigation is covered.
      expect(find.byKey(const Key('nav.pos')).hitTestable(), findsNothing);
    });

    testWidgets('an already granted permission opens the camera without a dialog', (tester) async {
      await pumpApp(tester);
      await openScanner(tester);
      expect(permissions.statusChecks, 1);
      expect(permissions.requests, 0);
      expect(find.byKey(const Key('fake.preview')), findsOneWidget);
    });
  });

  group('C scanner', () {
    testWidgets('close, torch (labelled, toggles), manual entry; hint after 8 s without a read', (tester) async {
      await pumpApp(tester);
      await openScanner(tester);

      expect(find.bySemanticsLabel('إغلاق الماسح والرجوع إلى البيع'), findsOneWidget);
      expect(find.bySemanticsLabel('تشغيل الإضاءة'), findsOneWidget);
      await tapKey(tester, 'scan.torch');
      expect(find.bySemanticsLabel('إطفاء الإضاءة'), findsOneWidget);

      expect(find.byKey(const Key('scan.hint')), findsNothing);
      await tester.pump(const Duration(seconds: 8));
      expect(find.textContaining('صعب القراءة؟', findRichText: true), findsOneWidget);

      await tapKey(tester, 'scan.close');
      expect(find.byType(ScannerScreen), findsNothing);
      expect(cameras.last.disposed, isTrue);
    });

    testWidgets('torch control is hidden when the device has no flash', (tester) async {
      await pumpApp(tester);
      await openScanner(tester);
      cameras.last.torch.value = TorchMode.unavailable;
      await tester.pump();
      expect(find.byKey(const Key('scan.torch')), findsNothing);
    });
  });

  group('C′ → D product found', () {
    testWidgets('a read pauses scanning and shows name, price and stock only', (tester) async {
      api.on('GET /products/lookup', found());
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, rice);

      expect(cameras.last.pauses, 1);
      expect(api.requestsTo('GET /products/lookup').single.queryParameters['barcode'], rice);
      expect(find.text('تمت القراءة'), findsOneWidget);
      expect(find.text('تم العثور على المنتج'), findsOneWidget);
      expect(find.text('أرز بسمتي 2 كغ'), findsOneWidget);
      expect(find.text('₪ 13.00'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.textContaining('6 221007 012345', findRichText: true), findsWidgets);
      // View only: no cost price, cart or sale action.
      expect(find.textContaining('9.00'), findsNothing);
      expect(find.byType(FilledButton), findsWidgets);
      expect(find.text('مسح منتج آخر'), findsOneWidget);
      expect(find.text('الرجوع إلى البيع'), findsOneWidget);

      // Scanning stays paused while the sheet is open.
      await read(tester, '1111111111111');
      expect(api.requestsTo('GET /products/lookup'), hasLength(1));

      await tapKey(tester, 'scan.another');
      expect(find.byKey(const Key('scan.sheet.found')), findsNothing);
      expect(cameras.last.resumes, 1);
      expect(find.text('وجّه الباركود داخل الإطار'), findsOneWidget);
    });

    testWidgets('«الرجوع إلى البيع» closes the scanner; Android back closes the sheet first', (tester) async {
      api.on('GET /products/lookup', found());
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, rice);

      await systemBack(tester);
      expect(find.byKey(const Key('scan.sheet.found')), findsNothing);
      expect(find.byType(ScannerScreen), findsOneWidget);

      await read(tester, rice);
      await tapKey(tester, 'scan.backToSale');
      expect(find.byType(ScannerScreen), findsNothing);
      expect(find.byKey(const Key('scan.entry')), findsOneWidget);
    });

    test('money and barcodes are formatted from the API string, never a double', () {
      expect(formatShekel('13'), '₪ 13.00');
      expect(formatShekel('13.5'), '₪ 13.50');
      expect(formatShekel('1245.50'), '₪ 1,245.50');
      expect(formatShekel('0.10'), '₪ 0.10');
      expect(formatBarcode(rice), '6 221007 012345');
      expect(formatBarcode('12345670'), '1234 5670');
      expect(formatBarcode('ABC-12'), 'ABC-12');
    });
  });

  group('E not found', () {
    testWidgets('404 (also an inactive product) shows the code and both recoveries', (tester) async {
      api.on('GET /products/lookup', envelope(404, 'NOT_FOUND'));
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, '6290000000017');

      expect(find.text('لا يوجد منتج بهذا الباركود'), findsOneWidget);
      expect(find.textContaining('6 290000 000017', findRichText: true), findsWidgets);
      expect(find.text('تأكد من الرقم أو امسحه مرة أخرى.'), findsOneWidget);
      // No HTTP code or status shown.
      expect(find.textContaining('404'), findsNothing);

      await tapKey(tester, 'scan.notFound.manual');
      expect(find.byKey(const Key('scan.sheet.manual')), findsOneWidget);
      expect(find.text('رقم الباركود'), findsOneWidget);
    });

    testWidgets('«مسح مرة أخرى» resumes scanning', (tester) async {
      api.on('GET /products/lookup', envelope(404, 'NOT_FOUND'));
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, '6290000000017');
      await tapKey(tester, 'scan.again');
      expect(find.byKey(const Key('scan.sheet.notFound')), findsNothing);
      expect(cameras.last.resumes, 1);
    });
  });

  group('F permission refused', () {
    testWidgets('denied once: allow again from F, which opens the camera', (tester) async {
      permissions = FakePermissions(CameraPermission.denied);
      await pumpApp(tester);
      await openScanner(tester);

      expect(find.byKey(const Key('permission.denied')), findsOneWidget);
      expect(find.text('لا يمكن المسح بدون الكاميرا'), findsOneWidget);
      expect(find.text('السماح بالكاميرا'), findsOneWidget);
      expect(find.text('إدخال الباركود يدويًا'), findsOneWidget);
      expect(find.text('الرجوع إلى البيع'), findsOneWidget);
      expect(cameras, isEmpty);

      permissions.afterRequest = CameraPermission.granted;
      await tapKey(tester, 'permission.allow');
      expect(permissions.requests, 2);
      expect(find.byKey(const Key('fake.preview')), findsOneWidget);
    });

    testWidgets('blocked: opens the app settings, and scans once allowed there', (tester) async {
      permissions = FakePermissions(CameraPermission.permanentlyDenied);
      await pumpApp(tester);
      await openScanner(tester);

      expect(permissions.requests, 0);
      expect(find.byKey(const Key('permission.blocked')), findsOneWidget);
      expect(find.text('فتح الإعدادات'), findsOneWidget);
      expect(find.textContaining('الكاميرا', findRichText: true), findsWidgets);

      await tapKey(tester, 'permission.allow');
      expect(permissions.settingsOpened, 1);

      permissions.current = CameraPermission.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake.preview')), findsOneWidget);
    });

    testWidgets('manual entry and back to بيع are always there', (tester) async {
      permissions = FakePermissions(CameraPermission.permanentlyDenied);
      api.on('GET /products/lookup', found());
      await pumpApp(tester);
      await openScanner(tester);

      await tapKey(tester, 'permission.manual');
      await tester.enterText(find.byKey(const Key('manual.field')), rice);
      await tapKey(tester, 'manual.submit');
      expect(find.text('أرز بسمتي 2 كغ'), findsOneWidget);

      await tapKey(tester, 'scan.another');
      expect(find.byKey(const Key('permission.blocked')), findsOneWidget);
      await tapKey(tester, 'permission.backToSale');
      expect(find.byType(ScannerScreen), findsNothing);
    });
  });

  group('G manual entry', () {
    testWidgets('empty input is refused with focus kept; a typed code shows the same result', (tester) async {
      api.on('GET /products/lookup', found());
      await pumpApp(tester);
      await openScanner(tester);
      await tapKey(tester, 'scan.manual');

      expect(cameras.last.pauses, 1);
      expect(find.text('المسح متوقف'), findsWidgets);
      expect(find.text('اكتب الأرقام كما تظهر تحت خطوط الباركود.'), findsOneWidget);

      await tapKey(tester, 'manual.submit');
      expect(find.text('أدخل رقم الباركود'), findsOneWidget);
      expect(api.requestsTo('GET /products/lookup'), isEmpty);
      final field = tester.widget<EditableText>(
        find.descendant(of: find.byKey(const Key('manual.field')), matching: find.byType(EditableText)),
      );
      expect(field.focusNode.hasFocus, isTrue);

      await tester.enterText(find.byKey(const Key('manual.field')), ' $rice ');
      await tester.pumpAndSettle();
      expect(find.text('أدخل رقم الباركود'), findsNothing);
      await tapKey(tester, 'manual.submit');
      expect(api.requestsTo('GET /products/lookup').single.queryParameters['barcode'], rice);
      expect(find.byKey(const Key('scan.sheet.manual')), findsNothing);
      expect(find.text('₪ 13.00'), findsOneWidget);
    });

    testWidgets('cancel returns to the scanner, which resumes', (tester) async {
      await pumpApp(tester);
      await openScanner(tester);
      await tapKey(tester, 'scan.manual');
      expect(find.bySemanticsLabel('إلغاء الإدخال اليدوي'), findsOneWidget);
      await tapKey(tester, 'manual.cancel');
      expect(find.byKey(const Key('scan.sheet.manual')), findsNothing);
      expect(cameras.last.resumes, 1);
      expect(find.byType(ScannerScreen), findsOneWidget);
    });
  });

  group('H network, server, session', () {
    testWidgets('network: offline banner, error in the sheet, retry re-sends the same barcode', (tester) async {
      api.offline('GET /products/lookup');
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, rice);

      expect(find.text('تعذّر عرض المنتج'), findsOneWidget);
      expect(find.text('تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.'), findsOneWidget);
      expect(find.text('لا يوجد اتصال — البيع يحتاج إلى الإنترنت'), findsOneWidget);
      expect(find.textContaining('محفوظ لإعادة المحاولة.', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      await tapKey(tester, 'scan.retry');
      final sent = api.requestsTo('GET /products/lookup');
      expect(sent, hasLength(2));
      expect(sent.map((r) => r.queryParameters['barcode']), everyElement(rice));
      expect(find.text('تعذّر عرض المنتج'), findsOneWidget);
    });

    testWidgets('5xx: the server message with the support reference; retry can succeed', (tester) async {
      api.onSequence('GET /products/lookup', [envelope(500, 'SERVER_ERROR'), found()]);
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, rice);

      expect(find.text('حدث خطأ في الخادم. أعد المحاولة بعد قليل.'), findsOneWidget);
      final reference = correlationId.substring(correlationId.length - 6);
      expect(find.text('رمز المرجع: $reference'), findsOneWidget);

      await tapKey(tester, 'scan.retry');
      expect(find.text('أرز بسمتي 2 كغ'), findsOneWidget);
    });

    testWidgets('401: the global session handler shows «انتهت الجلسة»; re-login returns to بيع, not the scanner', (
      tester,
    ) async {
      api.on('GET /products/lookup', envelope(401, 'UNAUTHENTICATED'));
      await pumpApp(tester);
      await openScanner(tester);
      await read(tester, rice);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ScannerScreen), findsNothing);
      expect(find.text('انتهت الجلسة. سجّل الدخول للمتابعة.'), findsOneWidget);

      api.on('POST /login', loginOk(role: 'employee'));
      await tester.enterText(find.byKey(const Key('login.email')), 'employee@demo.test');
      await tester.enterText(find.byKey(const Key('login.password')), 'secret');
      await tapKey(tester, 'login.submit');
      expect(find.byKey(const Key('scan.entry')), findsOneWidget);
      expect(find.byType(ScannerScreen), findsNothing);
    });
  });

  group('360 × 760 at 130% text', () {
    void expectOnScreen(WidgetTester tester, Finder finder) {
      final rect = tester.getRect(finder);
      expect(rect.left >= 0 && rect.right <= 360 && rect.top >= 0 && rect.bottom <= 760, isTrue, reason: '$rect');
    }

    void expectSingleLine(WidgetTester tester, Finder text) {
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
      // Same height as the text laid out on one unbounded line: it never wrapped.
      final oneLine = TextPainter(
        text: paragraph.text,
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout();
      expect(paragraph.size.height, moreOrLessEquals(oneLine.height, epsilon: 0.5));
      oneLine.dispose();
    }

    testWidgets('scanner, long-name result, manual entry and blocked permission fit without clipping', (tester) async {
      api.on('GET /products/lookup', found(name: 'حليب طويل الأجل 1 لتر — كرتونة 12 عبوة', price: '72.50', stock: '3'));
      await pumpApp(tester, textScale: 1.3);

      await openScanner(tester);
      await tester.pump(const Duration(seconds: 8));
      expect(tester.takeException(), isNull);
      expectOnScreen(tester, find.byKey(const Key('scan.manual')));
      expectOnScreen(tester, find.byKey(const Key('scan.hint')));

      await read(tester, rice);
      expect(tester.takeException(), isNull);
      expectSingleLine(tester, find.text('₪ 72.50'));
      expectOnScreen(tester, find.text('₪ 72.50'));
      expectOnScreen(tester, find.byKey(const Key('scan.another')));
      expectOnScreen(tester, find.byKey(const Key('scan.backToSale')));

      await tapKey(tester, 'scan.another');
      await tapKey(tester, 'scan.manual');
      await tapKey(tester, 'manual.submit');
      expect(tester.takeException(), isNull);
      expect(find.text('أدخل رقم الباركود'), findsOneWidget);
      expectOnScreen(tester, find.byKey(const Key('manual.submit')));
    });

    testWidgets('blocked permission and not-found fit at 130%', (tester) async {
      permissions = FakePermissions(CameraPermission.permanentlyDenied);
      api.on('GET /products/lookup', envelope(404, 'NOT_FOUND'));
      await pumpApp(tester, textScale: 1.3);
      await openScanner(tester);
      expect(tester.takeException(), isNull);
      await Scrollable.ensureVisible(tester.element(find.byKey(const Key('permission.backToSale'))));
      await tester.pumpAndSettle();
      expectOnScreen(tester, find.byKey(const Key('permission.backToSale')));

      await tapKey(tester, 'permission.manual');
      await tester.enterText(find.byKey(const Key('manual.field')), '6290000000017');
      await tapKey(tester, 'manual.submit');
      expect(tester.takeException(), isNull);
      expectOnScreen(tester, find.byKey(const Key('scan.again')));
      expectOnScreen(tester, find.byKey(const Key('scan.notFound.manual')));
    });

    testWidgets('every scanner control is at least 48 dp', (tester) async {
      await pumpApp(tester);
      await openScanner(tester);
      for (final key in ['scan.close', 'scan.torch', 'scan.manual']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width >= 48 && size.height >= 48, isTrue, reason: '$key $size');
      }
      await tapKey(tester, 'scan.manual');
      final cancel = tester.getSize(find.byKey(const Key('manual.cancel')));
      expect(cancel.width >= 48 && cancel.height >= 48, isTrue, reason: '$cancel');
    });
  });
}
