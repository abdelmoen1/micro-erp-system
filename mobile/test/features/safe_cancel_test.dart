import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/products/domain/product.dart';
import 'package:smartshop/features/returns/domain/returns.dart';

import '../support/fake_api.dart';

/// Safe cancel on the phone: a return made by mistake is cancelled from its sheet by an owner or
/// manager, with the effects shown first, a required reason and one Idempotency-Key; staff are
/// not offered it; a refusal shows the server's reason; and only an unused product offers delete.
void main() {
  late FakeApi api;

  Map<String, dynamic> saleReturn({bool voided = false}) => {
    'id': 5,
    'invoice_id': 40,
    'customer': {'id': 3, 'name': 'أبو خالد'},
    'total_amount': '15.00',
    'debt_reduction': '0.00',
    'refund_amount': '15.00',
    'reason': 'منبعجة',
    'created_by': 'أبو محمد',
    'created_at': '2026-11-01T10:00:00Z',
    'status': voided ? 'voided' : 'active',
    'voided_at': voided ? '2026-11-02T10:00:00Z' : null,
    'void_reason': voided ? 'سُجّل بالخطأ' : null,
    'items': [
      {'item_name': 'زيت زيتون', 'unit': 'piece', 'quantity': '1', 'total': '15.00', 'damaged': false},
    ],
  };

  Map<String, dynamic> sale({bool voidedReturn = false}) => {
    'id': 40,
    'status': 'active',
    'total_amount': '30.00',
    'paid_amount': '30.00',
    'debt_amount': '0.00',
    'payment_method': 'cash',
    'created_at': '2026-11-01T09:00:00Z',
    'customer': {'id': 3, 'name': 'أبو خالد'},
    'items': [
      {'id': 9, 'product_id': 3, 'item_name': 'زيت زيتون', 'unit': 'piece', 'quantity': '2', 'returned_quantity': voidedReturn ? '0' : '1', 'unit_price': '15.00', 'line_total': '30.00'},
    ],
    'seller': {'id': 1, 'name': 'أبو محمد'},
    'returns': [saleReturn(voided: voidedReturn)],
    'returned_amount': voidedReturn ? '0.00' : '15.00',
  };

  Future<void> pumpApp(WidgetTester tester, {String role = 'owner'}) async {
    api.on('GET /me', meOk(role: role));
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore({AuthRepository.tokenKey: '1|tok'})),
          httpAdapterProvider.overrideWithValue(api),
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

  /// The returns sit below the receipt in a lazily built list.
  Future<void> scrollToReturn(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.byKey(const Key('saleDetail.returned.5')), 300, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  Future<void> openReturn(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('home.invoice.40')));
    await scrollToReturn(tester);
    await tap(tester, find.byKey(const Key('saleDetail.returned.5')));
  }

  setUp(() {
    api = FakeApi();
    // The shape of accounting_test's dashboard (fields the home screen reads, for every role).
    api.on('GET /dashboard', FakeResponse(200, {
      'data': {
        'summary': {'total_sales': '30.00', 'invoices_count': 1},
        'sales': {'total': '30.00', 'cash': '30.00', 'credit': '0.00'},
        'payments': {'today': '0.00'},
        'collections': {'at_sale': '30.00', 'debt_repayments': '0.00', 'total': '30.00', 'refunded': '15.00', 'net': '15.00'},
        'returns': {'count': 1, 'total': '15.00', 'refunded': '15.00'},
        'purchases': null,
        'debts': {'total_remaining': '0.00'},
        'customers': {'with_outstanding_debts': 0},
        'insights': {
          'low_stock': {'count': 0},
        },
        'recent_invoices': [
          {'id': 40, 'customer': null, 'total_amount': '30.00', 'type': 'cash', 'created_at': '2026-11-01T09:00:00Z'},
        ],
      },
    }));
    api.on('GET /sales/40', FakeResponse(200, {'data': sale()}));
  });

  testWidgets('an owner cancels a customer return: effects first, a reason, one key, then the invoice refreshes', (tester) async {
    api.handle('POST /returns/sales/5/void', (_) {
      api.on('GET /sales/40', FakeResponse(200, {'data': sale(voidedReturn: true)}));
      return FakeResponse(200, {'message': 'تم إلغاء المرتجع.', 'data': saleReturn(voided: true)});
    });
    await pumpApp(tester);
    await openReturn(tester);

    await tap(tester, find.byKey(const Key('return.cancel')));
    expect(find.text('إلغاء المرتجع على الفاتورة #40'), findsOneWidget);
    expect(find.textContaining('تخرج الأصناف المرتجعة من المخزون مرة أخرى.'), findsOneWidget);
    expect(find.textContaining('رُدّ للزبون ₪ 15.00 نقداً'), findsOneWidget);

    await tap(tester, find.byKey(const Key('cancelReturn.confirm')));
    expect(find.text('اكتب سبب الإلغاء — يُحفظ في سجل التدقيق'), findsOneWidget);
    expect(api.requestsTo('POST /returns/sales/5/void'), isEmpty);

    await tester.enterText(find.byKey(const Key('cancelReturn.reason')), 'سُجّل بالخطأ');
    await tap(tester, find.byKey(const Key('cancelReturn.confirm')));

    final sent = api.requestsTo('POST /returns/sales/5/void').single;
    expect(sent.data, {'reason': 'سُجّل بالخطأ'});
    expect(sent.headers['Idempotency-Key'], isNotNull);
    expect(find.byKey(const Key('cancelReturn.confirm')), findsNothing);
    expect(find.text('تم إلغاء المرتجع.'), findsOneWidget);
    // Let the confirmation note leave before tapping under it.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    // The invoice was fetched again: the return is now marked cancelled and offers no cancel.
    expect(api.requestsTo('GET /sales/40').length, greaterThanOrEqualTo(2));
    await scrollToReturn(tester);
    expect(find.text('ملغى'), findsOneWidget);
    await tap(tester, find.byKey(const Key('saleDetail.returned.5')));
    expect(find.byKey(const Key('return.voided')), findsOneWidget);
    expect(find.byKey(const Key('return.cancel')), findsNothing);
  });

  testWidgets('a refused cancel shows the server reason and keeps the sheet open', (tester) async {
    api.on('POST /returns/sales/5/void', envelope(409, 'RETURN_STOCK_CONSUMED', message: 'لا يمكن إلغاء المرتجع: الكمية المرتجعة من «زيت زيتون» لم تعد في المخزون.'));
    await pumpApp(tester);
    await openReturn(tester);
    await tap(tester, find.byKey(const Key('return.cancel')));
    await tester.enterText(find.byKey(const Key('cancelReturn.reason')), 'خطأ');
    await tap(tester, find.byKey(const Key('cancelReturn.confirm')));

    expect(find.byKey(const Key('cancelReturn.problem')), findsOneWidget);
    expect(find.textContaining('لم تعد في المخزون'), findsOneWidget);
    expect(find.byKey(const Key('cancelReturn.confirm')), findsOneWidget);
  });

  testWidgets('an employee can open a return but is not offered to cancel it', (tester) async {
    await pumpApp(tester, role: 'employee');
    // Staff land on the till; the home tab holds the recent invoices.
    await tap(tester, find.byKey(const Key('nav.home')));
    await openReturn(tester);

    expect(find.byKey(const Key('return.print')), findsOneWidget);
    expect(find.byKey(const Key('return.cancel')), findsNothing);
  });

  test('records read the void state, and only a product the server marks deletable offers delete', () {
    final record = SaleReturnRecord.fromJson(saleReturn(voided: true));
    expect(record.voided, isTrue);
    expect(record.voidReason, 'سُجّل بالخطأ');
    expect(SaleReturnRecord.fromJson(saleReturn()).voided, isFalse);

    Map<String, dynamic> product({bool? deletable}) => {
      'id': 3,
      'name': 'زيت',
      'selling_price': '15.00',
      'current_stock': '0',
      'minimum_stock': '0',
      'status': 'active',
      'deletable': ?deletable,
    };
    expect(Product.fromJson(product(deletable: true)).deletable, isTrue);
    expect(Product.fromJson(product(deletable: false)).deletable, isFalse);
    // Staff never receive the flag: nothing to delete.
    expect(Product.fromJson(product()).deletable, isFalse);
  });
}
