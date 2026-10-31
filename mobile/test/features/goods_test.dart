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

  Future<void> addCarton(WidgetTester tester, String name, String barcode, String cartons, String size, String sell) async {
    await tap(tester, find.byKey(const Key('goods.manual')));
    await type(tester, 'goodsItem.name', name);
    await type(tester, 'goodsItem.barcode', barcode);
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
    final priced = carton.withPrices(buy: Money.parse('60.00'), carton: Money.parse('72.00'));
    expect(priced.total, Money.parse('240.00'));
    expect(priced.pieceCost, Money.parse('2.50'));
    expect(priced.cartonPriceOk, isTrue);
    expect(carton.withPrices(carton: Money.parse('3.00')).cartonPriceOk, isFalse, reason: 'the piece price in the wrong field');
    expect(carton.pieces, 96);

    final kilos = GoodsLine(name: 'لوز', kind: GoodsKind.weight, sellingPrice: '40.00', kilos: Quantity.parse('0.333'));
    expect(kilos.withPrices(buy: Money.parse('28.50')).total, Money.parse('9.49'));
  });

  testWidgets('two steps, then the invoice: prices on the supplier step, nothing paid at saving', (tester) async {
    api.on('POST /purchases', const FakeResponse(201, {
      'data': {
        'id': 1,
        'supplier': {'id': 7, 'name': 'التاج مول'},
        'total': '718.00',
        'paid': '0.00',
        'remaining': '718.00',
        'lines': 3,
        'at': '2026-10-31T08:00:00Z',
      },
    }));
    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('nav.products')));
    await tap(tester, find.byKey(const Key('products.add')));

    await tap(tester, find.byKey(const Key('goods.manual')));
    await type(tester, 'goodsItem.name', 'كولا علبة');
    await type(tester, 'goodsItem.cartons', '4');
    await type(tester, 'goodsItem.pack', '24');
    await type(tester, 'goodsItem.sell', '3.50');
    await tap(tester, find.byKey(const Key('goodsItem.save')));
    expect(find.text('اكتب رقم الباركود'), findsOneWidget, reason: 'a carton needs its barcode');
    await type(tester, 'goodsItem.barcode', '6251234567890');
    await tap(tester, find.byKey(const Key('goodsItem.save')));
    expect(find.text('4 كرتونة، 96 قطعة'), findsOneWidget);

    await addCarton(tester, 'حليب', '6251234567807', '3', '12', '6.50');

    await tap(tester, find.byKey(const Key('goods.manual')));
    await tap(tester, find.byKey(const Key('goodsItem.kind.weight')));
    expect(find.byKey(const Key('goodsItem.barcode')), findsNothing, reason: 'a weighed item has no barcode');
    await type(tester, 'goodsItem.name', 'لوز نيء');
    await type(tester, 'goodsItem.kilos', '10');
    await type(tester, 'goodsItem.sell', '40');
    await tap(tester, find.byKey(const Key('goodsItem.save')));

    await tap(tester, find.byKey(const Key('goods.toSupplier')));
    await tap(tester, find.byKey(const Key('goods.save')));
    expect(find.text('اكتب اسم المورد'), findsOneWidget);
    expect(api.requestsTo('POST /purchases'), isEmpty);

    await type(tester, 'goods.supplier', 'التاج مول');
    await type(tester, 'goods.buyPrice.0', '60');
    await type(tester, 'goods.cartonPrice.0', '3');
    await type(tester, 'goods.buyPrice.1', '66');
    await type(tester, 'goods.cartonPrice.1', '75');
    await type(tester, 'goods.buyPrice.2', '28');
    expect(find.byKey(const Key('goods.cartonPrice.2')), findsNothing);
    expect(find.text('₪ 718.00'), findsOneWidget);

    await tap(tester, find.byKey(const Key('goods.save')));
    await tester.ensureVisible(find.byKey(const Key('goods.cartonPrice.0'), skipOffstage: false));
    await tester.pumpAndSettle();
    expect(find.text('أعلى من سعر القطعة'), findsOneWidget);
    await type(tester, 'goods.cartonPrice.0', '72');
    await tap(tester, find.byKey(const Key('goods.save')));

    expect(find.byKey(const Key('goods.invoice')), findsOneWidget);
    expect(find.text('التاج مول'), findsOneWidget);
    expect(find.text('₪ 718.00'), findsOneWidget);
    expect(find.text('لوز نيء'), findsOneWidget);

    final body = api.requestsTo('POST /purchases').single.data as Map<String, dynamic>;
    expect(body['supplier_name'], 'التاج مول');
    expect(body.containsKey('paid_amount'), isFalse);
    expect(body.containsKey('total'), isFalse, reason: 'the server computes it');
    final lines = body['lines'] as List<dynamic>;
    expect(lines[0], containsPair('barcode', '6251234567890'));
    expect(lines[0], containsPair('buy_price', '60.00'));
    expect(lines[0], containsPair('carton_price', '72.00'));
    expect(lines[2], containsPair('quantity', '10.000'));
    expect((lines[2] as Map).containsKey('barcode'), isFalse);
    expect((lines[2] as Map).containsKey('carton_price'), isFalse);

    await tap(tester, find.byKey(const Key('goods.finish')));
    expect(find.byKey(const Key('goods.invoice')), findsNothing);
  });

  testWidgets('supplier → product → its invoices and payments; a payment belongs to the product', (tester) async {
    api.on('GET /suppliers', const FakeResponse(200, {
      'data': [
        {'id': 7, 'name': 'التاج مول', 'phone': null, 'balance': '318.00'},
      ],
    }));
    api.on('GET /suppliers/7', const FakeResponse(200, {
      'data': {
        'id': 7,
        'name': 'التاج مول',
        'phone': null,
        'balance': '318.00',
        'products': [
          {'id': 3, 'name': 'كولا علبة', 'unit': 'piece', 'balance': '140.00'},
        ],
      },
    }));
    api.on('GET /suppliers/7/products/3', const FakeResponse(200, {
      'data': {
        'supplier': {'id': 7, 'name': 'التاج مول'},
        'product': {'id': 3, 'name': 'كولا علبة', 'unit': 'piece'},
        'balance': '140.00',
        'invoices': [
          {'id': 1, 'invoice_id': 12, 'at': '2026-10-30T08:00:00Z', 'by': 'أبو محمد', 'quantity': '96', 'cartons': 4, 'pack_size': 24, 'buy_price': '60.00', 'total': '240.00'},
        ],
        'payments': [
          {'id': 1, 'at': '2026-10-30T09:00:00Z', 'by': 'أبو محمد', 'amount': '100.00', 'method': 'cash'},
        ],
      },
    }));
    api.on('POST /suppliers/7/payments', const FakeResponse(201, {'data': {'balance': '40.00'}}));

    await pumpApp(tester);
    await tap(tester, find.byKey(const Key('nav.more')));
    await tap(tester, find.byKey(const Key('more.suppliers')));
    await tap(tester, find.byKey(const Key('suppliers.row.7')));
    await tap(tester, find.byKey(const Key('supplier.product.3')));
    expect(find.text('₪ 140.00'), findsOneWidget);

    await tap(tester, find.byKey(const Key('supplier.invoice.12')));
    expect(find.text('₪ 60.00'), findsOneWidget);
    expect(find.text('96'), findsOneWidget);
    expect(find.text('سعر الشراء'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tap(tester, find.byKey(const Key('supplier.payment.0')));
    expect(find.text('طريقة الدفع'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tap(tester, find.byKey(const Key('supplier.pay')));
    await type(tester, 'supplier.amount', '500');
    await tap(tester, find.byKey(const Key('supplier.savePayment')));
    expect(find.text('أكبر من المبلغ اللي عليك'), findsOneWidget);

    await type(tester, 'supplier.amount', '100');
    await tap(tester, find.byKey(const Key('goods.method.jawwal_pay')));
    await tap(tester, find.byKey(const Key('supplier.savePayment')));

    final body = api.requestsTo('POST /suppliers/7/payments').single.data as Map<String, dynamic>;
    expect(body, {'product_id': 3, 'amount': '100.00', 'method': 'jawwal_pay'});
  });
}
