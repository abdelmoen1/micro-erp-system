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
      api.on('GET /products/catalog-lookup', FakeResponse(200, {
        'data': {'barcode': '6281007041235', 'product': dates, 'catalog_product': null},
      }));
      await pumpApp(tester);
      await scanCode(tester, 'https://id.gs1.org/01/06281007041235/10/LOT42');

      expect(find.byKey(const Key('addProduct.existing')), findsOneWidget);
      expect(api.requestsTo('GET /products/catalog-lookup').single.queryParameters['barcode'], '6281007041235');
      expect(api.requestsTo('POST /products'), isEmpty);
    });

    testWidgets('a barcode another store saved prefills the shared name and unit; price and stock are mine', (tester) async {
      api.on('GET /products/catalog-lookup', const FakeResponse(200, {
        'data': {
          'barcode': '6281007041235',
          'product': null,
          'catalog_product': {'id': 4, 'barcode': '6281007041235', 'name': 'تمر مجهول', 'unit': 'kg'},
        },
      }));
      api.on('POST /products', FakeResponse(201, {'message': 'تم إنشاء المنتج بنجاح', 'product': dates}));
      await pumpApp(tester);
      await scanCode(tester, '6281007041235');

      expect(find.byKey(const Key('addProduct.fromCatalog')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('form.name'))).controller!.text, 'تمر مجهول');

      for (final (key, value) in [('form.selling_price', '40'), ('form.current_stock', '2.5')]) {
        await tester.scrollUntilVisible(find.byKey(Key(key)), 80, scrollable: find.byType(Scrollable).last);
        await tester.enterText(find.byKey(Key(key)), value);
      }
      await tap(tester, find.byKey(const Key('form.save')));

      expect(find.byKey(const Key('addProduct.saved')), findsOneWidget);
      expect(api.requestsTo('POST /products').single.data, {
        'name': 'تمر مجهول',
        'barcode': '6281007041235',
        'unit': 'kg',
        'selling_price': '40',
        'current_stock': '2.5',
      });
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

    testWidgets('the camera stays on under the form; a save closes it, confirms at the top and the next code opens a fresh form', (tester) async {
      api.on('GET /products/catalog-lookup', const FakeResponse(200, {'data': {'barcode': '6281007041235', 'product': null, 'catalog_product': null}}));
      api.on('POST /products', FakeResponse(201, {'message': 'تم إنشاء المنتج بنجاح', 'product': dates}));
      await pumpApp(tester);
      await scanCode(tester, '6281007041235');

      expect(find.byKey(const Key('inventory.sheet')), findsOneWidget);
      expect(cameras.single.pauses, 0, reason: 'the preview keeps running under the form');
      // A second code while the form is open is ignored: typing never opens another product.
      cameras.single.read('6223000111111');
      await tester.pumpAndSettle();
      expect(api.requestsTo('GET /products/catalog-lookup'), hasLength(1));

      await tester.enterText(find.byKey(const Key('form.name')), 'تمر مجهول 1 كغ');
      await tester.enterText(find.byKey(const Key('form.selling_price')), '45');
      await tester.enterText(find.byKey(const Key('form.cost_price')), '38.5');
      await tester.enterText(find.byKey(const Key('form.current_stock')), '12');
      await tap(tester, find.byKey(const Key('form.save')));

      expect(api.requestsTo('POST /products').single.data, {
        'name': 'تمر مجهول 1 كغ',
        'barcode': '6281007041235',
        'unit': 'piece',
        'selling_price': '45',
        'cost_price': '38.5',
        'current_stock': '12',
      });
      expect(find.byKey(const Key('inventory.sheet')), findsNothing);
      expect(find.byKey(const Key('addProduct.saved')), findsOneWidget);
      expect(find.text('أُضيف «تمر مجهول 1 كغ»'), findsOneWidget);
      expect(api.requestsTo('GET /products/lookup'), isEmpty, reason: 'nothing here goes through the sale cart');

      // The next product: a fresh, empty form.
      api.on('GET /products/catalog-lookup', const FakeResponse(200, {'data': {'barcode': '6223000999992', 'product': null, 'catalog_product': null}}));
      cameras.single.read('6223000999992');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inventory.sheet')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('form.name'))).controller!.text, isEmpty);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('addProduct.saved')), findsNothing, reason: 'the confirmation goes away by itself');
    });

    testWidgets('a failed save keeps every value; after a timeout, «already in your store» means it was saved', (tester) async {
      api.on('GET /products/catalog-lookup', const FakeResponse(200, {'data': {'barcode': '6281007041235', 'product': null, 'catalog_product': null}}));
      await pumpApp(tester);
      await scanCode(tester, '6281007041235');
      await tester.enterText(find.byKey(const Key('form.name')), 'تمر مجهول 1 كغ');
      await tester.enterText(find.byKey(const Key('form.selling_price')), '45');
      await tester.enterText(find.byKey(const Key('form.current_stock')), '3');

      api.offline('POST /products');
      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.byKey(const Key('inventory.error')), findsOneWidget);
      expect(find.textContaining('لا اتصال بالخادم'), findsOneWidget);
      for (final (key, value) in [('form.name', 'تمر مجهول 1 كغ'), ('form.selling_price', '45'), ('form.current_stock', '3')]) {
        expect(tester.widget<TextField>(find.byKey(Key(key))).controller!.text, value, reason: '$key kept');
      }

      // Sent, but the answer never came: it may be saved. The retry is refused as a duplicate barcode,
      // and the lookup shows the product is in the store now, so it is reported as saved, once.
      api
        ..restore('POST /products')
        ..timeout('POST /products');
      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.textContaining('فقد يكون الحفظ تمّ'), findsOneWidget);

      api
        ..restore('POST /products')
        ..on('POST /products', envelope(422, 'VALIDATION_FAILED', errors: {'barcode': ['الباركود مستخدم لمنتج آخر في متجرك']}))
        ..on('GET /products/catalog-lookup', FakeResponse(200, {'data': {'barcode': '6281007041235', 'product': dates, 'catalog_product': null}}));
      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.byKey(const Key('addProduct.saved')), findsOneWidget);
      expect(find.byKey(const Key('inventory.sheet')), findsNothing);
      expect(api.requestsTo('POST /products'), hasLength(3));
    });

    testWidgets('a product already in the store gets «إضافة كمية», sent once with its own key', (tester) async {
      api.on('GET /products/catalog-lookup', FakeResponse(200, {'data': {'barcode': '6281007041235', 'product': dates, 'catalog_product': null}}));
      await pumpApp(tester);
      await scanCode(tester, '6281007041235');
      expect(find.byKey(const Key('addProduct.existing')), findsOneWidget);

      await tap(tester, find.byKey(const Key('inventory.addStock')));
      expect(tester.widget<TextField>(find.byKey(const Key('form.stock.reason'))).controller!.text, 'بضاعة واردة');
      await tap(tester, find.byKey(const Key('stock.save')));
      expect(find.text('أدخل عدداً صحيحاً أكبر من صفر.'), findsOneWidget);
      expect(api.requestsTo('POST /stock-adjustments'), isEmpty);

      await tester.enterText(find.byKey(const Key('form.stock.quantity')), '24');
      api.timeout('POST /stock-adjustments');
      await tap(tester, find.byKey(const Key('stock.save')));
      expect(find.byKey(const Key('inventory.sheet')), findsOneWidget);

      api
        ..restore('POST /stock-adjustments')
        ..on('POST /stock-adjustments', FakeResponse(201, {
          'message': 'تم تعديل المخزون بنجاح',
          'product': productJson(id: 21, name: 'تمر مجهول 1 كغ', barcode: '6281007041235', price: '45.00', stock: '36'),
        }));
      await tap(tester, find.byKey(const Key('stock.save')));

      final sent = api.requestsTo('POST /stock-adjustments');
      expect(sent, hasLength(2));
      expect(sent.last.headers['Idempotency-Key'], sent.first.headers['Idempotency-Key'], reason: 'the retry can never add 24 twice');
      expect(sent.last.data, {'product_id': 21, 'quantity': '24', 'reason': 'بضاعة واردة'});
      expect(find.text('أُضيفت الكمية إلى «تمر مجهول 1 كغ». المخزون الآن 36'), findsOneWidget);
      expect(api.requestsTo('POST /products'), isEmpty);
    });

    testWidgets('goods received by the carton: cartons are counted, their pieces shown, unit pack sent', (tester) async {
      final water = {
        ...productJson(id: 22, name: 'ماء 600 مل', barcode: '6281007041235', price: '2.50', stock: '6'),
        'pack_size': 24,
        'pack_price': '54.00',
      };
      api.on('GET /products/catalog-lookup', FakeResponse(200, {'data': {'barcode': '6281007041235', 'product': water, 'catalog_product': null}}));
      api.on('POST /stock-adjustments', FakeResponse(201, {
        'message': 'تم تعديل المخزون بنجاح',
        'product': {...water, 'current_stock': '78'},
      }));
      await pumpApp(tester);
      await scanCode(tester, '6281007041235');

      await tap(tester, find.byKey(const Key('inventory.addStock')));
      await tap(tester, find.byKey(const Key('stock.byPack')));
      await tester.enterText(find.byKey(const Key('form.stock.quantity')), '3');
      await tester.pump();
      expect(find.text('= 72 قطعة'), findsOneWidget);
      await tap(tester, find.byKey(const Key('stock.save')));

      expect(api.requestsTo('POST /stock-adjustments').single.data, {'product_id': 22, 'quantity': '3', 'reason': 'بضاعة واردة', 'unit': 'pack'});
      expect(find.text('أُضيفت الكمية إلى «ماء 600 مل». المخزون الآن 78'), findsOneWidget);
    });

    testWidgets('a new product with a carton: the per-piece price is shown and a carton cheaper than a piece is stopped', (tester) async {
      api.on('GET /products/catalog-lookup', const FakeResponse(200, {'data': {'barcode': '6281007041235', 'product': null, 'catalog_product': null}}));
      api.on('POST /products', FakeResponse(201, {'message': 'تم إنشاء المنتج بنجاح', 'product': dates}));
      await pumpApp(tester);
      await scanCode(tester, '6281007041235');

      await tester.enterText(find.byKey(const Key('form.name')), 'ماء 600 مل');
      await tester.enterText(find.byKey(const Key('form.selling_price')), '2.50');
      await tester.ensureVisible(find.byKey(const Key('form.pack')));
      await tap(tester, find.byKey(const Key('form.pack')));
      await tester.enterText(find.byKey(const Key('form.pack_size')), '24');
      await tester.enterText(find.byKey(const Key('form.pack_price')), '2.50');
      await tester.enterText(find.byKey(const Key('form.current_stock')), '48');
      await tap(tester, find.byKey(const Key('form.save')));
      expect(find.text('سعر الكرتونة يجب أن يكون أعلى من سعر القطعة. هل أدخلت سعر القطعة هنا؟'), findsOneWidget);
      expect(api.requestsTo('POST /products'), isEmpty);

      await tester.enterText(find.byKey(const Key('form.pack_price')), '54');
      await tester.pump();
      expect(find.text('القطعة داخل الكرتونة بـ ₪ 2.25 مقابل ₪ 2.50 بالمفرد.'), findsOneWidget);
      await tap(tester, find.byKey(const Key('form.save')));
      expect(api.requestsTo('POST /products').single.data, {
        'name': 'ماء 600 مل',
        'barcode': '6281007041235',
        'unit': 'piece',
        'selling_price': '2.50',
        'current_stock': '48',
        'pack_size': '24',
        'pack_price': '54',
      });
    });

    testWidgets('an employee sees products without the add button', (tester) async {
      await pumpApp(tester, role: 'employee');
      await tap(tester, find.byKey(const Key('nav.products')));
      expect(find.text('شاي أسود'), findsOneWidget);
      expect(find.byKey(const Key('products.add')), findsNothing);
    });
  });
}
