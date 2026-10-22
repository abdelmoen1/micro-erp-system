import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/api/api_client.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/features/products/data/product_repository.dart';
import 'package:smartshop/features/products/domain/product.dart';

import '../support/fake_api.dart';

/// Product JSON exactly as ProductResource renders it (docs/api/products.http). Since CR-13
/// (modified) quantities are strings in the product's unit: "12" pieces, "2.500" kg.
Map<String, dynamic> productJson({
  int id = 1,
  String name = 'Milk 1L',
  String? barcode = '7290000000017',
  String unit = 'piece',
  String price = '6.50',
  String stock = '12',
  String minimum = '5',
  String status = 'active',
}) => {
  'id': id,
  'name': name,
  'barcode': barcode,
  'unit': unit,
  'selling_price': price,
  'cost_price': null,
  'current_stock': stock,
  'minimum_stock': minimum,
  'is_low_stock': double.parse(stock) <= double.parse(minimum),
  'status': status,
  'created_at': '2026-10-17T08:00:00.000000Z',
  'updated_at': '2026-10-17T08:00:00.000000Z',
};

void main() {
  late FakeApi api;
  late ProductRepository products;
  late List<ApiFailure> sessionFailures;

  setUp(() {
    api = FakeApi();
    sessionFailures = [];
    products = ProductRepository(
      ApiClient(
        baseUrl: 'http://api.test/api/v1',
        readToken: () async => 'tok',
        onSessionFailure: sessionFailures.add,
        adapter: api,
      ),
    );
  });

  group('T-1301-7 barcode lookup', () {
    test('returns the product; money stays a string', () async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': productJson(), 'meta': {'currency': 'ILS'}}));

      final product = await products.lookupByBarcode('7290000000017');

      expect(product, isNotNull);
      expect(product!.id, 1);
      expect(product.name, 'Milk 1L');
      expect(product.sellingPrice, '6.50');
      expect(product.costPrice, isNull);
      expect(product.unit, ProductUnit.piece);
      expect(product.currentStock, Quantity.whole(12));
      expect(product.currentStock.format(product.unit), '12');
      expect(product.isLowStock, isFalse);
      expect(product.isActive, isTrue);
      final request = api.requestsTo('GET /products/lookup').single;
      expect(request.queryParameters, {'barcode': '7290000000017'});
      expect(request.headers['Authorization'], 'Bearer tok');
    });

    test('CR-13: a kg product keeps its stock to the gram', () async {
      api.on(
        'GET /products/lookup',
        FakeResponse(200, {'data': productJson(unit: 'kg', price: '60.00', stock: '2.500', minimum: '0.750')}),
      );

      final product = (await products.lookupByBarcode('2000000000017'))!;

      expect(product.unit, ProductUnit.kg);
      expect(product.isWeighed, isTrue);
      expect(product.currentStock, const Quantity.milli(2500));
      expect(product.currentStock.format(product.unit), '2.500');
      expect(product.minimumStock, const Quantity.milli(750));
    });

    test('a server from before the contract change (integer stock, no unit) still parses', () {
      final legacy = Product.fromJson({...productJson(), 'current_stock': 12, 'minimum_stock': 5}..remove('unit'));

      expect(legacy.unit, ProductUnit.piece);
      expect(legacy.currentStock, Quantity.whole(12));
      expect(legacy.minimumStock, Quantity.whole(5));
    });

    test('404 (unknown or inactive barcode) is null, not an error', () async {
      api.on('GET /products/lookup', envelope(404, 'NOT_FOUND'));

      expect(await products.lookupByBarcode('000'), isNull);
      expect(sessionFailures, isEmpty);
    });

    test('scanner input is trimmed; an empty scan sends no request', () async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': productJson(barcode: 'A 1/2&3')}));

      expect(await products.lookupByBarcode('   '), isNull);
      expect(api.requests, isEmpty);

      await products.lookupByBarcode('  A 1/2&3\n');
      final request = api.requestsTo('GET /products/lookup').single;
      expect(request.queryParameters['barcode'], 'A 1/2&3');
      expect(request.uri.query, 'barcode=A+1%2F2%263');
    });

    test('other failures are thrown; an expired session is reported', () async {
      api.on('GET /products/lookup', envelope(401, 'UNAUTHENTICATED'));

      await expectLater(products.lookupByBarcode('1'), throwsA(isA<Unauthenticated>()));
      expect(sessionFailures.single, isA<Unauthenticated>());
    });
  });

  group('US-0403 low stock', () {
    test('parses the list in server order', () async {
      api.on(
        'GET /products/low-stock',
        FakeResponse(200, {
          'data': [productJson(id: 2, name: 'Zero', stock: '0'), productJson(id: 3, name: 'Three', stock: '3')],
          'links': <String, dynamic>{},
          'meta': {'current_page': 1, 'per_page': 20, 'total': 2},
        }),
      );

      final list = await products.lowStock();

      expect(list.map((p) => p.name), ['Zero', 'Three']);
      expect(list.map((p) => p.currentStock), [Quantity.zero, Quantity.whole(3)]);
      expect(list.every((p) => p.isLowStock), isTrue);
    });

    test('an empty list is fine', () async {
      api.on('GET /products/low-stock', const FakeResponse(200, {'data': <Object>[]}));

      expect(await products.lowStock(), isEmpty);
    });
  });
}
