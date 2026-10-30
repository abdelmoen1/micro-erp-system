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

    const legacyCreated = FakeResponse(201, {
      'data': {
        'id': 90,
        'source': 'opening_debt',
        'debt': {'id': 3, 'remaining_amount': '120.00', 'source': 'opening_debt'},
      },
    });

    testWidgets('old debt from the customer page: validated, confirmed, sent once, balances refreshed', (tester) async {
      api.on('POST /debts', legacyCreated);
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('nav.customers')));
      await tap(tester, find.byKey(const Key('customers.row.4')));
      await tap(tester, find.byKey(const Key('customer.legacyDebt')));
      expect(find.byKey(const Key('legacy.form')), findsOneWidget);
      expect(find.text('أبو محمد'), findsWidgets, reason: 'the customer is preselected');

      for (final bad in ['0', '12.345', '-5']) {
        await tester.enterText(find.byKey(const Key('legacy.amount')), bad);
        await tap(tester, find.byKey(const Key('legacy.save')));
        expect(find.text('اكتب مبلغ صحيح أكبر من صفر، وبحد أقصى رقمين بعد الفاصلة.'), findsOneWidget);
      }
      expect(api.requestsTo('POST /debts'), isEmpty);

      await tester.enterText(find.byKey(const Key('legacy.amount')), '120');
      await tester.scrollUntilVisible(find.byKey(const Key('legacy.note')), 120, scrollable: find.descendant(of: find.byKey(const Key('legacy.form')), matching: find.byType(Scrollable)).first);
      await tester.enterText(find.byKey(const Key('legacy.note')), 'من الدفتر القديم');
      await tap(tester, find.byKey(const Key('legacy.save')));
      expect(find.text('تأكيد الدين القديم'), findsOneWidget);
      await tap(tester, find.byKey(const Key('legacy.confirm')));

      final sent = api.requestsTo('POST /debts');
      expect(sent, hasLength(1));
      expect(sent.single.data, {'customer_id': 4, 'amount': '120.00', 'note': 'من الدفتر القديم'});
      expect(sent.single.headers['Idempotency-Key'], isNotEmpty);
      expect(find.byKey(const Key('legacy.done')), findsOneWidget);

      final summaries = api.requestsTo('GET /customers/4/summary').length;
      await tap(tester, find.text('تمام'));
      expect(api.requestsTo('GET /customers/4/summary').length, summaries + 1, reason: 'the balance is reloaded');
      expect(api.requestsTo('POST /sales'), isEmpty, reason: 'an old debt is never a sale');
    });

    testWidgets('old debt after a dropped connection: the retry reuses the same key', (tester) async {
      api.offline('POST /debts');
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('nav.customers')));
      await tap(tester, find.byKey(const Key('customers.row.4')));
      await tap(tester, find.byKey(const Key('customer.legacyDebt')));
      await tester.enterText(find.byKey(const Key('legacy.amount')), '75.5');
      await tap(tester, find.byKey(const Key('legacy.save')));
      await tap(tester, find.byKey(const Key('legacy.confirm')));
      expect(find.text('أعد المحاولة'), findsOneWidget);

      api.restore('POST /debts');
      api.on('POST /debts', legacyCreated);
      await tap(tester, find.byKey(const Key('legacy.save')));
      final sent = api.requestsTo('POST /debts');
      expect(sent, hasLength(2));
      expect(sent.last.headers['Idempotency-Key'], sent.first.headers['Idempotency-Key']);
      expect(find.byKey(const Key('legacy.done')), findsOneWidget);
    });

    testWidgets('an employee does not see «تسجيل دين قديم»', (tester) async {
      await pumpApp(tester, role: 'employee');
      await tap(tester, find.byKey(const Key('nav.customers')));
      expect(find.byKey(const Key('customers.legacyDebt')), findsNothing);
      await tap(tester, find.byKey(const Key('customers.row.4')));
      expect(find.byKey(const Key('customer.legacyDebt')), findsNothing);
    });

    Map<String, Object?> sale(int id, {String total = '45.00', String paid = '45.00', String status = 'active', List<Map<String, Object?>>? items}) => {
      'id': id,
      'status': status,
      'total_amount': total,
      'paid_amount': paid,
      'debt_amount': (double.parse(total) - double.parse(paid)).toStringAsFixed(2),
      'payment_method': 'cash',
      'items': items ?? [
        {'item_name': 'تمر مجهول 1 كغ', 'unit': 'piece', 'quantity': '1', 'unit_price': '45.00', 'line_total': '45.00'},
      ],
      'customer': {'id': 4, 'name': 'أبو محمد', 'phone': '0599123456'},
      'seller': {'id': 1, 'name': 'Demo owner'},
      'created_at': '2026-10-24T09:30:00.000000Z',
    };

    testWidgets('tapping a debt opens its invoice in full: every line with quantity and price, paid, debt, returns', (tester) async {
      api.on('GET /sales/12', FakeResponse(200, {
        'data': {
          ...sale(12, total: '214.50', paid: '84.00', items: [
            {'item_name': 'زيت زيتون 1 لتر', 'unit': 'piece', 'quantity': '3', 'unit_price': '45.00', 'line_total': '135.00'},
            {'item_name': 'جبنة بيضاء', 'unit': 'kg', 'quantity': '1.250', 'unit_price': '36.00', 'line_total': '45.00'},
            {'item_name': 'ماء 600 مل', 'unit': 'piece', 'sale_unit': 'pack', 'pack_size': 24, 'quantity': '1', 'base_quantity': '24', 'unit_price': '34.50', 'line_total': '34.50'},
          ]),
          'debt': {'due_date': '2026-10-12'},
          'returned_amount': '45.00',
        },
      }));
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('nav.customers')));
      await tap(tester, find.byKey(const Key('customers.row.4')));
      expect(api.requestsTo('GET /sales'), isEmpty, reason: 'the customer page lists debts, not every invoice');

      await tap(tester, find.byKey(const Key('customer.debt.1')));
      expect(api.requestsTo('GET /sales/12'), hasLength(1));
      expect(find.byKey(const Key('saleDetail.paper')), findsOneWidget);
      expect(find.text('زيت زيتون 1 لتر'), findsOneWidget);
      expect(find.textContaining('3 قطع × ₪ 45.00'), findsOneWidget);
      expect(find.textContaining('1.250 كغ × ₪ 36.00'), findsOneWidget);
      expect(find.textContaining('1 كرتونة × ₪ 34.50'), findsOneWidget);
      expect(find.text('= 24 قطعة'), findsOneWidget);
      expect(find.byKey(const Key('receipt.total')), findsOneWidget);
      expect(find.text('₪ 130.50'), findsWidgets, reason: 'what stayed as debt');
      await tester.scrollUntilVisible(
        find.byKey(const Key('saleDetail.returned')),
        200,
        scrollable: find.descendant(of: find.byKey(const Key('saleDetail.list')), matching: find.byType(Scrollable)),
      );
      expect(find.text('أُرجعت بضاعة من هذه الفاتورة بقيمة ₪ 45.00.'), findsOneWidget);

      // Back on the customer, the second debt opens its own invoice.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      api.on('GET /sales/37', FakeResponse(200, {'data': sale(37)}));
      await tap(tester, find.byKey(const Key('customer.debt.2')));
      expect(find.text('فاتورة #37'), findsWidgets);
      expect(find.text('تمر مجهول 1 كغ'), findsOneWidget);
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
      expect(sent.last.data, {'method': 'palpay', 'amount': '150.00'});
    });
  });

  group('M-11 · products', () {
    setUp(() {
      api.on('GET /products', FakeResponse(200, {'data': [productJson(id: 3, name: 'شاي أسود', stock: '2')]}));
    });

    testWidgets('the products table: name, cartons with the extra pieces, all pieces and the piece price', (tester) async {
      api.on('GET /products', FakeResponse(200, {
        'data': [
          {...productJson(id: 3, name: 'ماء 600 مل', price: '2.50', stock: '50'), 'pack_size': 24, 'pack_price': '54.00'},
          {...productJson(id: 4, name: 'عصير', price: '4.00', stock: '48'), 'pack_size': 24, 'pack_price': '90.00'},
          productJson(id: 5, name: 'لوز نيء', unit: 'kg', price: '60.00', stock: '5.200'),
        ],
      }));
      await pumpApp(tester);
      await tap(tester, find.byKey(const Key('nav.products')));

      expect(find.text('الكراتين'), findsOneWidget);
      expect(find.text('عدد القطع'), findsOneWidget);
      expect(find.text('سعر القطعة'), findsOneWidget);
      String cell(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
      expect(cell('products.cartons.3'), '2 كرتونة + 2 قطعة');
      expect(cell('products.pieces.3'), contains('50'));
      expect(cell('products.price.3'), contains('2.50'));
      expect(cell('products.cartons.4'), '2 كرتونة');
      expect(cell('products.cartons.5'), '—', reason: 'a weighed product has no cartons');
      expect(cell('products.pieces.5'), contains('5.200'));
    });

    testWidgets('an employee sees products without the add button', (tester) async {
      await pumpApp(tester, role: 'employee');
      await tap(tester, find.byKey(const Key('nav.products')));
      expect(find.text('شاي أسود'), findsOneWidget);
      expect(find.byKey(const Key('products.add')), findsNothing);
    });
  });
}
