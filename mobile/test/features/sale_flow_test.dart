import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/sale/presentation/checkout_screen.dart';
import 'package:smartshop/features/sale/presentation/receipt_screen.dart';
import 'package:smartshop/features/scanner/application/lookup_controller.dart' show cameraPermissionsProvider, barcodeCameraFactoryProvider;
import 'package:smartshop/features/scanner/domain/barcode_camera.dart';

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;
import 'scanner_test.dart' show FakeCamera, FakePermissions;

/// S2 sale flow on the hi-fi designs: M-02 cart + weight sheet, M-04 checkout, M-05 picker,
/// M-06 receipt + void, against a faked API.
const milkCode = '6223000456789';
const almondCode = '2900000004123';

FakeResponse lookup(Map<String, dynamic> product) => FakeResponse(200, {'data': product});

final milk = productJson(id: 7, name: 'حليب طويل الأجل 1 لتر', barcode: milkCode, price: '6.50', stock: '40');
final almonds = productJson(id: 9, name: 'لوز نيء', barcode: almondCode, unit: 'kg', price: '60.00', stock: '5.200');

Map<String, dynamic> customerJson({int id = 1, String name = 'أبو محمد', String balance = '0.00', String? limit}) => {
  'id': id,
  'name': name,
  'phone': '0599123456',
  'address': null,
  'notes': null,
  'credit_limit': limit,
  'debts_count': 0,
  'balance': balance,
};

/// A 201 from POST /sales, shaped like InvoiceResource.
FakeResponse saleCreated({
  String total = '19.50',
  String paid = '19.50',
  String debt = '0.00',
  Map<String, dynamic>? customer,
  String status = 'active',
  List<String> flags = const [],
}) => FakeResponse(201, {
  'message': 'تم حفظ عملية البيع بنجاح.',
  'data': {
    'id': 9001,
    'status': status,
    'total_amount': total,
    'paid_amount': paid,
    'debt_amount': debt,
    'payment_method': paid == '0.00' ? null : 'cash',
    'items': [
      {'item_name': 'حليب طويل الأجل 1 لتر', 'unit': 'piece', 'quantity': '3', 'unit_price': '6.50', 'line_total': '19.50'},
    ],
    'customer': customer,
    'seller': {'id': 1, 'name': 'Demo owner'},
    'created_at': '2026-10-20T08:14:03.000000Z',
    'voided_at': status == 'voided' ? '2026-10-20T08:20:00.000000Z' : null,
    'voided_by_name': status == 'voided' ? 'Demo owner' : null,
    'void_reason': status == 'voided' ? 'خطأ في الإدخال' : null,
  },
  'flags': flags,
  'warnings': [
    if (flags.contains('NEGATIVE_STOCK'))
      {'code': 'NEGATIVE_STOCK', 'product_id': 7, 'name': 'حليب طويل الأجل 1 لتر', 'balance_after': '-1'},
  ],
});

void main() {
  late FakeApi api;
  late MemoryKeyValueStore disk;
  late FakePermissions permissions;
  late List<FakeCamera> cameras;

  Future<void> pumpApp(WidgetTester tester, {String role = 'employee'}) async {
    api.on('GET /me', meOk(role: role));
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 72, bottom: 144);
    addTearDown(tester.view.reset);
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
    if (role != 'employee') {
      await tester.tap(find.byKey(const Key('nav.pos')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  bool scannerOpen() => find.byKey(const Key('saleScan.panel')).evaluate().isNotEmpty;

  /// «مسح» opens the sale scanner once; it stays open and every read goes into the cart panel.
  Future<void> scan(WidgetTester tester, String code) async {
    if (!scannerOpen()) await tap(tester, 'cart.scan');
    cameras.last.read(code);
    await tester.pumpAndSettle();
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).data!;

  Map<String, dynamic> lastSaleBody() => api.requestsTo('POST /sales').last.data as Map<String, dynamic>;

  setUp(() {
    api = FakeApi();
    disk = MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'});
    permissions = FakePermissions(CameraPermission.granted);
    cameras = [];
    api.on('GET /dashboard', dashboardOk());
  });

  group('M-02 cart', () {
    testWidgets('a scan adds a line; the same barcode inside 1.5 s is ignored', (tester) async {
      api.on('GET /products/lookup', lookup(milk));
      await pumpApp(tester);
      expect(find.text('امسح منتجاً للبدء'), findsOneWidget);

      await scan(tester, milkCode);
      expect(find.byKey(const Key('cart.feedback.added')), findsOneWidget);
      expect(find.text('₪ 6.50'), findsWidgets);

      // The camera repeats the same code many times a second: counted once, silently.
      await scan(tester, milkCode);
      await scan(tester, milkCode);
      expect(find.byKey(const Key('cart.feedback.duplicate')), findsNothing);
      expect(api.requestsTo('GET /products/lookup'), hasLength(1));
      expect(textOf(tester, 'cart.qty.7'), '1');
      expect(scannerOpen(), isTrue, reason: 'the camera stays open between products');

      await tap(tester, 'cart.inc.7');
      await tap(tester, 'cart.inc.7');
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('cart.qty.7')), matching: find.byType(Text))).data, '3');
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('cart.total')), matching: find.byType(Text))).data, '₪ 19.50');
    });

    testWidgets('a kg product opens the weight sheet; 0.750 kg × 60.00 = 45.00', (tester) async {
      api.on('GET /products/lookup', lookup(almonds));
      await pumpApp(tester);

      await scan(tester, almondCode);
      expect(find.text('أدخل الوزن'), findsOneWidget);
      for (final key in ['0', '.', '7', '5', '0', '9']) {
        await tester.tap(find.byKey(Key('key.$key')));
        await tester.pump();
      }
      // The fourth decimal is refused at the keypad.
      expect(find.text('0.750'), findsOneWidget);
      await tap(tester, 'weight.confirm');

      expect(find.byKey(const Key('cart.feedback.weighedAdded')), findsOneWidget);
      expect(tester.widget<Text>(find.descendant(of: find.byKey(const Key('cart.total')), matching: find.byType(Text))).data, '₪ 45.00');
    });

    testWidgets('an unknown barcode offers search by name; nothing is added', (tester) async {
      api.on('GET /products/lookup', envelope(404, 'NOT_FOUND'));
      await pumpApp(tester);

      await scan(tester, '6290000000017');
      expect(find.byKey(const Key('cart.feedback.unknown')), findsOneWidget);
      expect(find.text('6290000000017'), findsOneWidget);
      expect(find.text('امسح منتجاً للبدء'), findsOneWidget);
    });
  });

  group('M-04 checkout', () {
    Future<void> toCheckout(WidgetTester tester, {String role = 'employee'}) async {
      api.on('GET /products/lookup', lookup(milk));
      await pumpApp(tester, role: role);
      await scan(tester, milkCode);
      await tap(tester, 'cart.inc.7');
      await tap(tester, 'cart.inc.7');
      await tap(tester, 'cart.checkout');
      expect(find.byType(CheckoutScreen), findsOneWidget);
    }

    testWidgets('cash sale: no prices sent, receipt, then a new empty cart', (tester) async {
      await toCheckout(tester);
      api.on('POST /sales', saleCreated());

      expect(find.text('مدفوع بالكامل — لا دين'), findsOneWidget);
      await tap(tester, 'checkout.confirm');

      expect(lastSaleBody(), {
        'items': [
          {'product_id': 7, 'quantity': '3'},
        ],
        'paid_amount': '19.50',
        'payment_method': 'cash',
      });
      expect(api.requestsTo('POST /sales').single.headers['Idempotency-Key'], isNotNull);
      expect(find.byType(ReceiptScreen), findsOneWidget);
      expect(find.text('تم البيع'), findsOneWidget);
      expect(find.byKey(const Key('receipt.void')), findsNothing, reason: 'employees cannot void');

      await tap(tester, 'receipt.newSale');
      expect(find.text('امسح منتجاً للبدء'), findsOneWidget);
    });

    testWidgets('partial without a customer is stopped locally (UI-AC-03)', (tester) async {
      await toCheckout(tester);
      await tap(tester, 'checkout.mode.partial');
      await tester.enterText(find.byKey(const Key('checkout.paid')), '20');
      await tester.pumpAndSettle();
      await tap(tester, 'checkout.confirm');

      expect(find.byKey(const Key('checkout.customerError')), findsOneWidget);
      expect(find.text('أدخل مبلغاً أكبر من صفر، بخانتين عشريتين كحد أقصى.'), findsNothing);
      expect(find.text('المدفوع يساوي الإجمالي أو يزيد عليه. اختر «كاش كامل» بدلاً من «جزئي».'), findsOneWidget);
      expect(api.requestsTo('POST /sales'), isEmpty);
    });

    testWidgets('employee over the credit limit: restriction, confirm is off (D-26)', (tester) async {
      await toCheckout(tester);
      api.on('GET /customers', FakeResponse(200, {'data': [customerJson(balance: '90.00', limit: '100.00')]}));
      await tap(tester, 'checkout.mode.credit');
      await tap(tester, 'checkout.pickCustomer');
      await tap(tester, 'picker.customer.1');

      expect(find.byKey(const Key('checkout.limitBlocked')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('checkout.confirm'))).onPressed, isNull);
    });

    testWidgets('owner over the limit: explicit override sends confirm_over_limit and is noted', (tester) async {
      await toCheckout(tester, role: 'owner');
      api.on('GET /customers', FakeResponse(200, {'data': [customerJson(balance: '90.00', limit: '100.00')]}));
      await tap(tester, 'checkout.mode.credit');
      await tap(tester, 'checkout.pickCustomer');
      await tap(tester, 'picker.customer.1');
      expect(find.byKey(const Key('checkout.limitWarning')), findsOneWidget);

      await tap(tester, 'checkout.confirm');
      expect(find.text('تأكيد تجاوز سقف الدين'), findsOneWidget);
      expect(api.requestsTo('POST /sales'), isEmpty, reason: 'the warning button never sends the sale');

      api.on('POST /sales', saleCreated(paid: '0.00', debt: '19.50', customer: customerJson()));
      await tap(tester, 'override.confirm');

      expect(lastSaleBody()['confirm_over_limit'], isTrue);
      expect(lastSaleBody()['customer_id'], 1);
      expect(find.byType(ReceiptScreen), findsOneWidget);
      await tester.scrollUntilVisible(find.textContaining('تم تجاوز سقف دين'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('تم تجاوز سقف دين'), findsOneWidget);
    });

    testWidgets('offline: nothing sent twice; the retry reuses the same Idempotency-Key', (tester) async {
      await toCheckout(tester);
      api.offline('POST /sales');
      await tap(tester, 'checkout.confirm');
      await tester.scrollUntilVisible(find.byKey(const Key('checkout.submit.offline')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('checkout.submit.offline')), findsOneWidget);
      final firstKey = api.requestsTo('POST /sales').single.headers['Idempotency-Key'];

      api
        ..restore('POST /sales')
        ..on('POST /sales', saleCreated());
      await tap(tester, 'checkout.confirm');

      final keys = api.requestsTo('POST /sales').map((r) => r.headers['Idempotency-Key']).toList();
      expect(keys, [firstKey, firstKey]);
      expect(find.byType(ReceiptScreen), findsOneWidget);
    });
  });

  group('sale scanner (camera stays on, cart over it)', () {
    final bread = productJson(id: 8, name: 'خبز عربي', barcode: '6223000111111', price: '3.00', stock: '20');

    testWidgets('successive products go into the panel; quantities change and lines go without losing the cart', (tester) async {
      api.onSequence('GET /products/lookup', [lookup(milk), lookup(bread)]);
      await pumpApp(tester);

      await scan(tester, milkCode);
      await scan(tester, '6223000111111');
      expect(find.byKey(const Key('cart.line.7')), findsOneWidget);
      expect(find.byKey(const Key('cart.line.8')), findsOneWidget);
      expect(cameras.single.pauses, 0, reason: 'the camera never stopped between the two products');

      await tap(tester, 'cart.inc.8');
      expect(textOf(tester, 'cart.qty.8'), '2');
      await tap(tester, 'cart.dec.7'); // quantity 1: the stepper removes the line
      expect(find.byKey(const Key('cart.line.7')), findsNothing);
      expect(find.byKey(const Key('cart.line.8')), findsOneWidget);
      expect(textOf(tester, 'cart.total'), '₪ 6.00');

      // Closing the camera keeps the cart for the sale tab.
      await tap(tester, 'saleScan.close');
      expect(scannerOpen(), isFalse);
      expect(textOf(tester, 'cart.total'), '₪ 6.00');
    });

    testWidgets('«إتمام البيع» only opens payment; the camera holds until «بيع جديد», then reads again', (tester) async {
      api.on('GET /products/lookup', lookup(milk));
      await pumpApp(tester);
      await scan(tester, milkCode);

      await tap(tester, 'cart.checkout');
      expect(find.byType(CheckoutScreen), findsOneWidget);
      expect(api.requestsTo('POST /sales'), isEmpty, reason: 'opening payment never creates the sale');
      expect(cameras.single.pauses, 1);

      // Frames under the payment screen and the receipt are not read.
      cameras.single.read('6223000111111');
      await tester.pumpAndSettle();
      api.on('POST /sales', saleCreated(total: '6.50', paid: '6.50'));
      await tap(tester, 'checkout.confirm');
      expect(find.byType(ReceiptScreen), findsOneWidget);
      cameras.single.read('6223000111111');
      await tester.pumpAndSettle();
      expect(api.requestsTo('GET /products/lookup'), hasLength(1));
      expect(cameras.single.resumes, 0);

      await tap(tester, 'receipt.newSale');
      expect(scannerOpen(), isTrue, reason: 'back on the camera, ready for the next customer');
      expect(find.text('امسح منتجاً للبدء'), findsOneWidget);
      expect(cameras.single.resumes, 1);
      await scan(tester, milkCode);
      expect(find.byKey(const Key('cart.line.7')), findsOneWidget);
    });

    testWidgets('double taps open one payment screen and send one sale', (tester) async {
      api.on('GET /products/lookup', lookup(milk));
      await pumpApp(tester);
      await scan(tester, milkCode);

      await tester.tap(find.byKey(const Key('cart.checkout')));
      await tester.tap(find.byKey(const Key('cart.checkout')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutScreen, skipOffstage: false), findsOneWidget);

      api.on('POST /sales', saleCreated(total: '6.50', paid: '6.50'));
      await tester.ensureVisible(find.byKey(const Key('checkout.confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout.confirm')));
      await tester.tap(find.byKey(const Key('checkout.confirm')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(api.requestsTo('POST /sales'), hasLength(1));
      expect(find.byType(ReceiptScreen), findsOneWidget);
    });

    testWidgets('a carton line next to the pieces: its own price, its pieces, sent as sale_unit pack', (tester) async {
      final water = {
        ...productJson(id: 12, name: 'ماء 600 مل', barcode: '6223000777777', price: '2.50', stock: '100'),
        'pack_size': 24,
        'pack_price': '54.00',
      };
      api.on('GET /products/lookup', lookup(water));
      await pumpApp(tester);
      await scan(tester, '6223000777777');

      await tap(tester, 'cart.addPack.12');
      await tap(tester, 'cart.inc.12.pack');
      expect(find.byKey(const Key('cart.line.12.pack')), findsOneWidget);
      expect(textOf(tester, 'cart.qty.12.pack'), '2');
      expect(find.text('= 48 قطعة'), findsOneWidget);
      expect(find.textContaining('/ كرتونة (24 قطعة)'), findsOneWidget);
      // 1 × 2.50 + 2 × 54.00
      expect(textOf(tester, 'cart.total'), '₪ 110.50');

      await tap(tester, 'cart.checkout');
      api.on('POST /sales', const FakeResponse(201, {
        'message': 'تم حفظ عملية البيع بنجاح.',
        'data': {
          'id': 9002, 'status': 'active', 'total_amount': '110.50', 'paid_amount': '110.50', 'debt_amount': '0.00', 'payment_method': 'cash',
          'items': [
            {'item_name': 'ماء 600 مل', 'unit': 'piece', 'sale_unit': 'piece', 'pack_size': null, 'quantity': '1', 'unit_price': '2.50', 'line_total': '2.50'},
            {'item_name': 'ماء 600 مل', 'unit': 'piece', 'sale_unit': 'pack', 'pack_size': 24, 'quantity': '2', 'base_quantity': '48', 'unit_price': '54.00', 'line_total': '108.00'},
          ],
          'customer': null, 'seller': {'id': 1, 'name': 'Demo owner'}, 'created_at': '2026-10-26T08:14:03.000000Z',
        },
        'flags': [],
        'warnings': [],
      }));
      await tap(tester, 'checkout.confirm');

      expect(lastSaleBody()['items'], [
        {'product_id': 12, 'quantity': '1'},
        {'product_id': 12, 'quantity': '2', 'sale_unit': 'pack'},
      ]);
      expect(find.byType(ReceiptScreen), findsOneWidget);
      expect(find.textContaining('2 كرتونة × ₪ 54.00'), findsOneWidget);
      expect(find.text('= 48 قطعة'), findsOneWidget);
    });

    testWidgets('an electronic method has its icon and is recorded only, never shown as verified', (tester) async {
      api.on('GET /products/lookup', lookup(milk));
      await pumpApp(tester);
      await scan(tester, milkCode);
      await tap(tester, 'cart.checkout');

      expect(find.byKey(const Key('checkout.methodNote')), findsNothing, reason: 'cash needs no note');
      for (final method in ['cash', 'jawwal_pay', 'palpay', 'bank_of_palestine']) {
        expect(find.byKey(Key('checkout.method.$method')), findsOneWidget);
      }
      await tap(tester, 'checkout.method.jawwal_pay');
      expect(find.textContaining('حسبة لا تتصل بهذه الخدمة ولا تتحقق من وصول المبلغ'), findsOneWidget);

      api.on('POST /sales', saleCreated(total: '6.50', paid: '6.50'));
      await tap(tester, 'checkout.confirm');
      expect(lastSaleBody()['payment_method'], 'jawwal_pay');
      expect(lastSaleBody()['paid_amount'], '6.50');
    });
  });

  group('M-06 receipt', () {
    testWidgets('owner voids with a required reason; the receipt shows «ملغاة»', (tester) async {
      api.on('GET /products/lookup', lookup(milk));
      await pumpApp(tester, role: 'owner');
      await scan(tester, milkCode);
      await tap(tester, 'cart.checkout');
      api.on('POST /sales', saleCreated(flags: ['NEGATIVE_STOCK']));
      await tap(tester, 'checkout.confirm');
      await tester.scrollUntilVisible(find.textContaining('بمخزون سالب'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('بمخزون سالب'), findsOneWidget);

      await tap(tester, 'receipt.void');
      await tap(tester, 'void.confirm');
      expect(find.text('اكتب سبب الإلغاء — يُحفظ في سجل التدقيق'), findsOneWidget);
      expect(api.requestsTo('POST /sales/9001/void'), isEmpty);

      api.on('POST /sales/9001/void', envelope(409, 'INVOICE_HAS_PAYMENTS'));
      await tester.enterText(find.byKey(const Key('void.reason')), 'خطأ في الإدخال');
      await tap(tester, 'void.confirm');
      expect(find.byKey(const Key('void.problem')), findsOneWidget);

      api.on('POST /sales/9001/void', saleCreated(status: 'voided'));
      await tap(tester, 'void.confirm');
      expect(jsonDecode(jsonEncode(api.requestsTo('POST /sales/9001/void').last.data)), {'reason': 'خطأ في الإدخال'});
      expect(find.text('أُلغيت الفاتورة'), findsOneWidget);
      expect(find.text('ملغاة'), findsOneWidget);
      expect(find.byKey(const Key('receipt.void')), findsNothing);
    });
  });
}
