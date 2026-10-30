import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/app.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/data/auth_repository.dart';
import 'package:smartshop/features/goods/domain/goods.dart';

import '../support/fake_api.dart';

/// «تسجيل بضاعة»: three steps, totals computed for the person, the server told only what was typed.
void main() {
  late FakeApi api;

  Future<void> pumpApp(WidgetTester tester) async {
    api.on('GET /me', meOk());
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

  Future<void> type(WidgetTester tester, String key, String text) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.enterText(find.byKey(Key(key)), text);
    await tester.pumpAndSettle();
  }

  Future<void> addCarton(WidgetTester tester, String name, String cartons, String size, String sell) async {
    await tap(tester, find.byKey(const Key('goods.manual')));
    await type(tester, 'goodsItem.name', name);
    await type(tester, 'goodsItem.cartons', cartons);
    await type(tester, 'goodsItem.pack', size);
    await type(tester, 'goodsItem.sell', sell);
    await tap(tester, find.byKey(const Key('goodsItem.save')));
  }

  setUp(() {
    api = FakeApi();
    api.on('GET /dashboard', dashboardOk());
    api.on('GET /subscription', subscriptionOk(state: 'trial', hasAccess: true));
    api.on('GET /products', const FakeResponse(200, {'data': []}));
    api.on('GET /suppliers', const FakeResponse(200, {'data': []}));
  });

  test('a carton line multiplies by cartons, a weighed line by the kilo, half up', () {
    const carton = GoodsLine(name: 'كولا', kind: GoodsKind.carton, sellingPrice: '3.50', cartons: 4, packSize: 24);
    expect(carton.withBuyPrice(Money.parse('60.00')).total, Money.parse('240.00'));
    expect(carton.withBuyPrice(Money.parse('60.00')).pieceCost, Money.parse('2.50'));
    expect(carton.pieces, 96);

    final kilos = GoodsLine(name: 'لوز', kind: GoodsKind.weight, sellingPrice: '40.00', kilos: Quantity.parse('0.333'));
    expect(kilos.withBuyPrice(Money.parse('28.50')).total, Money.parse('9.49'));
  });

  testWidgets('three steps: the total is locked, what is left follows the paid amount, and the invoice is saved', (tester) async {
    api.on('POST /purchases', const FakeResponse(201, {
      'data': {
        'id': 1,
        'supplier': {'id': 7, 'name': 'شركة الأمل'},
        'total': '718.00',
        'paid': '400.00',
        'remaining': '318.00',
        'lines': 3,
      },
    }));
    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('nav.products')));
    await tap(tester, find.byKey(const Key('products.add')));

    await addCarton(tester, 'كولا علبة', '4', '24', '3.50');
    expect(find.text('4 كرتونة، 96 قطعة'), findsOneWidget);
    await addCarton(tester, 'حليب', '3', '12', '6.50');

    await tap(tester, find.byKey(const Key('goods.manual')));
    await tap(tester, find.byKey(const Key('goodsItem.kind.weight')));
    await type(tester, 'goodsItem.name', 'لوز نيء');
    await type(tester, 'goodsItem.kilos', '10');
    await type(tester, 'goodsItem.sell', '40');
    await tap(tester, find.byKey(const Key('goodsItem.save')));

    await tap(tester, find.byKey(const Key('goods.toSupplier')));
    await tap(tester, find.byKey(const Key('goods.toPayment')));
    expect(find.text('اكتب اسم المورد'), findsOneWidget, reason: 'the supplier is required');

    await type(tester, 'goods.supplier', 'شركة الأمل');
    await type(tester, 'goods.buyPrice.0', '60');
    await type(tester, 'goods.buyPrice.1', '66');
    await type(tester, 'goods.buyPrice.2', '28');
    expect(find.text('₪ 718.00'), findsOneWidget);

    await tap(tester, find.byKey(const Key('goods.toPayment')));
    final locked = find.byKey(const Key('goods.total'));
    expect(find.descendant(of: locked, matching: find.text('₪ 718.00')), findsOneWidget);
    expect(find.descendant(of: locked, matching: find.byType(TextField)), findsNothing);

    await type(tester, 'goods.paid', '400');
    expect(find.text('₪ 318.00'), findsOneWidget);
    await tap(tester, find.byKey(const Key('goods.save')));

    expect(find.byKey(const Key('goods.saved')), findsOneWidget);
    final body = api.requestsTo('POST /purchases').single.data as Map<String, dynamic>;
    expect(body['supplier_name'], 'شركة الأمل');
    expect(body['paid_amount'], '400.00');
    expect(body.containsKey('total'), isFalse, reason: 'the server computes it');
    final lines = body['lines'] as List<dynamic>;
    expect(lines[0], containsPair('cartons', 4));
    expect(lines[0], containsPair('pack_size', 24));
    expect(lines[0], containsPair('buy_price', '60.00'));
    expect(lines[2], containsPair('quantity', '10.000'));
    expect((lines[2] as Map).containsKey('barcode'), isFalse, reason: 'a weighed item has no barcode');
  });

  testWidgets('weight hides the carton fields, and paying more than the total cannot be saved', (tester) async {
    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('nav.products')));
    await tap(tester, find.byKey(const Key('products.add')));
    await tap(tester, find.byKey(const Key('goods.manual')));
    await tap(tester, find.byKey(const Key('goodsItem.kind.weight')));
    expect(find.byKey(const Key('goodsItem.cartons')), findsNothing);
    expect(find.byKey(const Key('goodsItem.pack')), findsNothing);

    await type(tester, 'goodsItem.name', 'لوز');
    await type(tester, 'goodsItem.kilos', '2');
    await type(tester, 'goodsItem.sell', '40');
    await tap(tester, find.byKey(const Key('goodsItem.save')));
    await tap(tester, find.byKey(const Key('goods.toSupplier')));
    await type(tester, 'goods.supplier', 'تاجر');
    await type(tester, 'goods.buyPrice.0', '30');
    await tap(tester, find.byKey(const Key('goods.toPayment')));
    await type(tester, 'goods.paid', '61');

    expect(find.text('أكثر من الإجمالي'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('goods.save'))).onPressed, isNull);
  });

  testWidgets('the supplier account shows what is owed and a payment is recorded with its method', (tester) async {
    api.on('GET /suppliers', const FakeResponse(200, {
      'data': [
        {'id': 7, 'name': 'شركة الأمل', 'phone': null, 'balance': '318.00'},
      ],
    }));
    api.on('GET /suppliers/7', const FakeResponse(200, {
      'data': {
        'id': 7,
        'name': 'شركة الأمل',
        'phone': null,
        'balance': '318.00',
        'entries': [
          {'type': 'invoice', 'id': 1, 'amount': '718.00', 'items': 3, 'at': '2026-10-30T08:00:00Z'},
          {'type': 'payment', 'id': 1, 'amount': '400.00', 'method': 'cash', 'at': '2026-10-30T08:00:00Z'},
        ],
      },
    }));
    api.on('POST /suppliers/7/payments', const FakeResponse(201, {'data': {'balance': '150.00'}}));

    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('nav.more')));
    await tap(tester, find.byKey(const Key('more.suppliers')));
    await tap(tester, find.byKey(const Key('suppliers.row.7')));
    expect(find.text('دفعة نقداً'), findsOneWidget);

    await tap(tester, find.byKey(const Key('supplier.pay')));
    await type(tester, 'supplier.amount', '500');
    await tap(tester, find.byKey(const Key('supplier.savePayment')));
    expect(find.text('أكبر من المبلغ اللي عليك'), findsOneWidget);

    await type(tester, 'supplier.amount', '168');
    await tap(tester, find.byKey(const Key('goods.method.jawwal_pay')));
    await tap(tester, find.byKey(const Key('supplier.savePayment')));

    final body = api.requestsTo('POST /suppliers/7/payments').single.data as Map<String, dynamic>;
    expect(body, {'amount': '168.00', 'method': 'jawwal_pay'});
  });
}
