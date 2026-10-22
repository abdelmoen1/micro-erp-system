import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/scanner/application/lookup_controller.dart'
    show cameraPermissionsProvider, barcodeCameraFactoryProvider, productCodeCameraFactoryProvider;
import 'package:smartshop/features/scanner/domain/barcode_camera.dart';

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;
import 'scanner_test.dart' show FakeCamera, FakePermissions;

/// S3 mobile: M-07 customers → M-08 detail → M-09 payment, M-11 products and the QR add flow,
/// against a faked API with the real response shapes.
void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;
  late List<FakeCamera> cameras;

  Future<void> pumpApp(WidgetTester tester, {String role = 'owner'}) async {
    api.on('GET /me', meOk(role: role));
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    BarcodeCamera camera() {
      final c = FakeCamera();
      cameras.add(c);
      return c;
    }

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(disk),
          httpAdapterProvider.overrideWithValue(api),
          cameraPermissionsProvider.overrideWithValue(FakePermissions(CameraPermission.granted)),
          barcodeCameraFactoryProvider.overrideWithValue(camera),
          productCodeCameraFactoryProvider.overrideWithValue(camera),
        ],
        child: const SmartShopApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() {
    api = FakeApi();
    disk = MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'});
    cameras = [];
    api.on('GET /dashboard', dashboardOk());
  });

  group('M-07 → M-08 → M-09', () {
    setUp(() {
      api.on(
        'GET /customers',
        const FakeResponse(200, {
          'data': [
            {'id': 4, 'name': 'أبو محمد', 'phone': '0599123456', 'credit_limit': '500.00', 'status': 'active', 'balance': '345.00', 'overdue': '130.50'},
          ],
        }),
      );
      api.on(
        'GET /customers/4/summary',
        const FakeResponse(200, {
          'data': {'remaining': '345.00', 'overdue': '130.50', 'open_debts_count': 2, 'credit_limit': '500.00'},
        }),
      );
      api.on(
        'GET /debts',
        const FakeResponse(200, {
          'data': [
            {'id': 1, 'invoice_id': 12, 'source': 'sale', 'remaining_amount': '130.50', 'due_date': '2026-10-12'},
            {'id': 2, 'invoice_id': 37, 'source': 'sale', 'remaining_amount': '214.50', 'due_date': null},
          ],
        }),
      );
      api.on('GET /payments', const FakeResponse(200, {'data': []}));
    });

    testWidgets('a custom payment survives a timeout: the retry reuses the same Idempotency-Key', (tester) async {
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('nav.customers')));
      expect(find.text('أبو محمد'), findsOneWidget);
      expect(find.text('متأخر'), findsOneWidget);

      await tap(tester, find.byKey(const Key('customers.row.4')));
      expect(find.text('فاتورة #12'), findsOneWidget);

      await tap(tester, find.byKey(const Key('customer.pay')));
      await tap(tester, find.text('مبلغ آخر'));
      await tester.enterText(find.byKey(const Key('payment.amount')), '400');
      await tester.pumpAndSettle();
      expect(find.textContaining('المبلغ أكبر من المتبقي'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('payment.amount')), '150');
      await tester.pumpAndSettle();
      api.offline('POST /customers/4/debts/pay-all');
      await tap(tester, find.byKey(const Key('payment.confirm')));
      expect(find.textContaining('لم يصل رد الخادم'), findsOneWidget);

      api.restore('POST /customers/4/debts/pay-all');
      api.on(
        'POST /customers/4/debts/pay-all',
        const FakeResponse(201, {
          'data': {'payment_group_id': 'g1', 'debts_count': 2, 'total_paid': '150.00', 'remaining_after': '195.00'},
        }),
      );
      await tap(tester, find.byKey(const Key('payment.confirm')));
      expect(find.byKey(const Key('payment.done')), findsOneWidget);

      final sent = api.requestsTo('POST /customers/4/debts/pay-all');
      expect(sent, hasLength(2));
      expect(sent.first.headers['Idempotency-Key'], isNotNull);
      expect(sent.last.headers['Idempotency-Key'], sent.first.headers['Idempotency-Key']);
      expect(sent.last.data, {'method': 'cash', 'amount': '150.00'});
    });
  });

  group('M-11 · add a product by its code', () {
    final dates = productJson(id: 21, name: 'تمر مجهول 1 كغ', barcode: '6281007041235', price: '45.00', stock: '12');

    setUp(() {
      api.on('GET /products', FakeResponse(200, {'data': [productJson(id: 3, name: 'شاي أسود', stock: '2')]}));
    });

    Future<void> scanCode(WidgetTester tester, String raw) async {
      await tap(tester, find.byKey(const Key('nav.products')));
      await tap(tester, find.byKey(const Key('products.add')));
      await tap(tester, find.byKey(const Key('addProduct.scan')));
      cameras.last.read(raw);
      await tester.pumpAndSettle();
    }

    testWidgets('a code whose barcode is already in the store stops at «already exists»', (tester) async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': dates}));
      await pumpApp(tester);
      await scanCode(tester, 'https://id.gs1.org/01/06281007041235/10/LOT42');

      expect(find.byKey(const Key('addProduct.existing')), findsOneWidget);
      expect(api.requestsTo('GET /products/lookup').single.queryParameters['barcode'], '6281007041235');
      expect(api.requestsTo('POST /products'), isEmpty);
    });

    testWidgets('a JSON code prefills only what it carries; a 403 is explained, then it saves', (tester) async {
      api.onSequence('POST /products', [
        envelope(403, 'FORBIDDEN'),
        FakeResponse(201, {'message': 'تم إنشاء المنتج بنجاح', 'product': dates}),
      ]);
      await pumpApp(tester);
      await scanCode(tester, '{"name":"تمر مجهول 1 كغ","price":"45"}');

      expect(find.textContaining('قرأنا من الرمز'), findsOneWidget);
      expect(find.text('من الرمز'), findsNWidgets(2));
      expect(api.requestsTo('GET /products/lookup'), isEmpty);

      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.textContaining('إضافة المنتجات للمالك أو المدير'), findsOneWidget);

      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.byKey(const Key('addProduct.saved')), findsOneWidget);
      expect(api.requestsTo('POST /products').last.data, {
        'name': 'تمر مجهول 1 كغ',
        'unit': 'piece',
        'selling_price': '45.00',
        'current_stock': '0',
      });
    });

    testWidgets('a code without product data opens manual entry and nothing is sent until it is valid', (tester) async {
      await pumpApp(tester);
      await scanCode(tester, 'https://example-brand.com/promo?id=88');

      expect(find.textContaining('لا يحتوي بيانات منتج'), findsOneWidget);
      expect(find.text('https://example-brand.com/promo?id=88'), findsOneWidget);

      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.text('اكتب اسم المنتج.'), findsOneWidget);
      expect(find.text('أدخل سعراً صحيحاً.'), findsOneWidget);
      expect(api.requestsTo('POST /products'), isEmpty);
    });

    testWidgets('an employee sees products without the add button', (tester) async {
      await pumpApp(tester, role: 'employee');
      await tap(tester, find.byKey(const Key('nav.products')));
      expect(find.text('شاي أسود'), findsOneWidget);
      expect(find.byKey(const Key('products.add')), findsNothing);
    });
  });
}
