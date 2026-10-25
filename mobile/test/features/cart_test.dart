import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/api/api_client.dart';
import 'package:smartshop/core/api/api_failure.dart';
import 'package:smartshop/core/api/idempotency_key_store.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/products/data/product_repository.dart';
import 'package:smartshop/features/products/domain/product.dart';
import 'package:smartshop/features/sale/application/cart_controller.dart';
import 'package:smartshop/features/sale/data/sale_repository.dart';
import 'package:smartshop/features/sale/domain/cart.dart';
import 'package:smartshop/features/sale/domain/repeat_scan_guard.dart';

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;

/// US-0505 cart state (weighed goods per doc 15 §4, D-31 cooldown) and the POST /sales client.
void main() {
  final cola = Product.fromJson(productJson(id: 7, name: 'Cola', barcode: '111', price: '5.00', stock: '2'));
  final almonds = Product.fromJson(productJson(id: 9, name: 'Almonds', barcode: '222', unit: 'kg', price: '60.00', stock: '10.000'));
  final spice = Product.fromJson(productJson(id: 10, name: 'Spice', barcode: '333', unit: 'kg', price: '7.50', stock: '1.000'));

  group('exact money and quantities', () {
    test('parse and format the API strings', () {
      expect(Money.parse('12.5').toApi(), '12.50');
      expect(Money.parse('0').toApi(), '0.00');
      expect(Quantity.parse('0.750').format(ProductUnit.kg), '0.750');
      expect(Quantity.parse('3').format(ProductUnit.piece), '3');
      expect(Quantity.parse('2.5').format(ProductUnit.kg), '2.500');
      expect(() => Money.parse('1.999'), throwsFormatException);
      expect(() => Quantity.parse('0.7505'), throwsFormatException);
    });

    test('line total is rounded half-up to 2 decimals, like the server', () {
      expect(lineTotal(Money.parse('60.00'), Quantity.parse('0.750')).toApi(), '45.00');
      expect(lineTotal(Money.parse('7.50'), Quantity.parse('0.333')).toApi(), '2.50'); // 2.4975
      expect(lineTotal(Money.parse('4.10'), Quantity.whole(3)).toApi(), '12.30');
      expect(lineTotal(Money.parse('0.10'), Quantity.parse('0.005')).toApi(), '0.00'); // 0.0005 → 0.00
      expect(lineTotal(Money.parse('1.00'), Quantity.parse('0.005')).toApi(), '0.01'); // 0.005 → 0.01
    });
  });

  group('Cart', () {
    test('repeat +1 keeps one line per product (AC-02)', () {
      final cart = Cart.empty.addPiece(cola).addPiece(cola).addPiece(cola);

      expect(cart.lines, hasLength(1));
      expect(cart.lineFor(7)!.quantity, Quantity.whole(3));
      expect(cart.total.toApi(), '15.00');
    });

    test('weighed and piece lines give exact totals (S2 demo)', () {
      final cart = Cart.empty.setQuantity(almonds, Quantity.parse('0.750')).addPiece(cola).addPiece(cola).addPiece(cola);

      expect(cart.total.toApi(), '60.00');
      expect(cart.toSaleItems(), [
        {'product_id': 9, 'quantity': '0.750'},
        {'product_id': 7, 'quantity': '3'},
      ]);
    });

    test('a kg product needs a weight; a piece needs a whole quantity', () {
      expect(() => Cart.empty.addPiece(almonds), throwsArgumentError);
      expect(() => Cart.empty.setQuantity(cola, Quantity.parse('1.5')), throwsArgumentError);
      expect(() => Cart.empty.setQuantity(cola, const Quantity.milli(-1000)), throwsArgumentError);
    });

    test('zero removes a line; a new product snapshot replaces the old', () {
      final cart = Cart.empty.addPiece(cola).setQuantity(spice, Quantity.parse('0.333'));

      expect(cart.setQuantity(cola, Quantity.zero).lines.map((l) => l.product.id), [10]);
      expect(cart.remove(10).lines.map((l) => l.product.id), [7]);
      expect(cart.total.toApi(), '7.50'); // 5.00 + 2.50
    });

    test('selling above the recorded stock is allowed and flagged (D-27)', () {
      final cart = Cart.empty.addPiece(cola).addPiece(cola).addPiece(cola);

      expect(cart.exceedsStock(cart.lineFor(7)!), isTrue);
      expect(cart.overStockLines.map((l) => l.product.id), [7]);
      expect(Cart.empty.addPiece(cola).overStockLines, isEmpty);
    });
  });

  group('Cartons', () {
    // 2.50 a bottle, 54.00 a carton of 24; 30 bottles on the shelf.
    final water = Product.fromJson({
      ...productJson(id: 12, name: 'Water', barcode: '444', price: '2.50', stock: '30'),
      'pack_size': 24,
      'pack_price': '54.00',
    });

    test('pieces and cartons of one product are two lines, each at its own price', () {
      final cart = Cart.empty.addPiece(water).addPiece(water).addPack(water).addPack(water);

      expect(cart.lines, hasLength(2));
      expect(cart.lineFor(12)!.quantity, Quantity.whole(2));
      expect(cart.lineFor(12, pack: true)!.quantity, Quantity.whole(2));
      expect(cart.lineFor(12, pack: true)!.unitPrice.toApi(), '54.00', reason: 'per carton, never per piece');
      expect(cart.lineFor(12, pack: true)!.baseQuantity, Quantity.whole(48));
      // 2 × 2.50 + 2 × 54.00
      expect(cart.total.toApi(), '113.00');
      expect(cart.toSaleItems(), [
        {'product_id': 12, 'quantity': '2'},
        {'product_id': 12, 'quantity': '2', 'sale_unit': 'pack'},
      ]);
    });

    test('the stock warning counts every piece inside the cartons', () {
      final oneCarton = Cart.empty.addPack(water);
      expect(oneCarton.overStockLines, isEmpty, reason: '24 of 30');

      final more = oneCarton.addPiece(water).addPiece(water).addPiece(water).addPiece(water).addPiece(water).addPiece(water).addPiece(water);
      expect(more.baseQuantityOf(12), Quantity.whole(31));
      expect(more.overStockLines, hasLength(2), reason: '24 + 7 = 31 > 30: both lines of the product');
    });

    test('a carton is whole, only for products that have one, and removing it keeps the pieces', () {
      expect(() => Cart.empty.setQuantity(water, Quantity.parse('1.500'), pack: true), throwsArgumentError);
      expect(() => Cart.empty.addPack(cola), throwsArgumentError);

      final cart = Cart.empty.addPiece(water).addPack(water).remove(12, pack: true);
      expect(cart.lines.single.pack, isFalse);
      expect(cart.lineFor(12)!.quantity, Quantity.one);
    });
  });

  group('RepeatScanGuard (D-31, 1.5 s)', () {
    late DateTime now;
    late RepeatScanGuard guard;

    setUp(() {
      now = DateTime(2026, 10, 22, 9);
      guard = RepeatScanGuard(clock: () => now);
    });

    void advance(int ms) => now = now.add(Duration(milliseconds: ms));

    test('a barcode held in view is accepted once', () {
      var accepted = 0;
      for (var i = 0; i < 25; i++) {
        if (guard.accept('111')) accepted++;
        advance(200); // the camera reports the code 5× a second for 5 s
      }

      expect(accepted, 1);
    });

    test('a deliberate second scan after the code left the view is accepted', () {
      expect(guard.accept('111'), isTrue);
      advance(1499);
      expect(guard.accept('111'), isFalse);
      advance(1500);
      expect(guard.accept('111'), isTrue);
    });

    test('different codes never block each other', () {
      expect(guard.accept('111'), isTrue);
      expect(guard.accept('222'), isTrue);
      advance(100);
      expect(guard.accept('111'), isFalse);
      expect(guard.accept('333'), isTrue);
    });
  });

  group('CartController', () {
    late FakeApi api;
    late DateTime now;
    late ProviderContainer container;

    setUp(() {
      api = FakeApi();
      now = DateTime(2026, 10, 22, 9);
      container = ProviderContainer(
        overrides: [
          productRepositoryProvider.overrideWithValue(ProductRepository(_client(api))),
          repeatScanGuardProvider.overrideWithValue(RepeatScanGuard(clock: () => now)),
        ],
      );
      addTearDown(container.dispose);
    });

    CartController controller() => container.read(cartControllerProvider.notifier);
    Cart cart() => container.read(cartControllerProvider);

    test('scan → lookup → cart line; a repeat inside the cooldown does nothing', () async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': productJson(id: 7, barcode: '111', price: '5.00')}));

      final first = await controller().scan('111');
      final repeat = await controller().scan('111');

      expect(first, isA<ScanAdded>());
      expect((first as ScanAdded).line.quantity, Quantity.whole(1));
      expect(first.elapsed, greaterThanOrEqualTo(first.lookup));
      expect(repeat, isA<ScanIgnored>());
      expect(api.requestsTo('GET /products/lookup'), hasLength(1));
      expect(cart().lineFor(7)!.quantity, Quantity.whole(1));

      now = now.add(const Duration(seconds: 2));
      expect(await controller().scan('111'), isA<ScanAdded>());
      expect(cart().lineFor(7)!.quantity, Quantity.whole(2));
      expect(cart().lines, hasLength(1));
    });

    test('a kg product asks for the weight instead of adding 1', () async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': productJson(id: 9, barcode: '222', unit: 'kg', price: '60.00', stock: '10.000')}));

      final result = await controller().scan('222');

      expect(result, isA<ScanNeedsWeight>());
      expect(cart().isEmpty, isTrue);

      controller().setQuantity((result as ScanNeedsWeight).product, Quantity.parse('0.750'));
      expect(cart().total.toApi(), '45.00');
    });

    test('unknown barcodes and failed lookups leave the cart unchanged', () async {
      api.on('GET /products/lookup', envelope(404, 'NOT_FOUND'));
      expect(await controller().scan('999'), isA<ScanUnknown>());

      api.offline('GET /products/lookup');
      final failed = await controller().scan('888');
      expect(failed, isA<ScanFailed>());
      expect((failed as ScanFailed).failure, isA<NetworkFailure>());
      expect(cart().isEmpty, isTrue);
    });

    test('manual search adds pieces; clear empties the cart and the cooldown', () async {
      expect(controller().addProduct(cola), isTrue);
      expect(controller().addProduct(almonds), isFalse);
      expect(cart().lines, hasLength(1));

      controller().clear();
      expect(cart().isEmpty, isTrue);
    });
  });

  group('SaleRepository (POST /sales)', () {
    late FakeApi api;
    late MemoryKeyValueStore store;
    late SaleRepository sales;

    setUp(() {
      api = FakeApi();
      store = MemoryKeyValueStore();
      sales = SaleRepository(_client(api), IdempotencyKeyStore(store));
    });

    final cart = Cart.empty.setQuantity(almonds, Quantity.parse('0.750')).addPiece(cola);

    test('sends products and quantities only; parses the receipt and NEGATIVE_STOCK', () async {
      api.on('POST /sales', FakeResponse(201, _saleCreated(flags: ['NEGATIVE_STOCK'])));

      final receipt = await sales.submit(
        SaleDraft(cart: cart, paidAmount: Money.parse('20.00'), customerId: 12, paymentMethod: 'cash', dueDate: '2026-11-01'),
        operationId: 'checkout-1',
      );

      final request = api.requestsTo('POST /sales').single;
      expect(request.data, {
        'customer_id': 12,
        'items': [
          {'product_id': 9, 'quantity': '0.750'},
          {'product_id': 7, 'quantity': '1'},
        ],
        'paid_amount': '20.00',
        'payment_method': 'cash',
        'due_date': '2026-11-01',
      });
      expect(request.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(receipt.id, 41);
      expect(receipt.total.toApi(), '50.00');
      expect(receipt.debt.toApi(), '30.00');
      expect(receipt.flags, ['NEGATIVE_STOCK']);
      expect(receipt.warnings.single.balanceAfter, '-3');
      expect(await IdempotencyKeyStore(store).pendingOperations(), isEmpty);
    });

    test('a retry after no response reuses the same key (US-0506 AC3)', () async {
      api.offline('POST /sales');
      final draft = SaleDraft(cart: cart, paidAmount: Money.parse('50.00'), paymentMethod: 'cash');

      await expectLater(sales.submit(draft, operationId: 'checkout-2'), throwsA(isA<NetworkFailure>()));
      expect(await IdempotencyKeyStore(store).pendingOperations(), ['checkout-2']);

      final retryApi = FakeApi()..on('POST /sales', FakeResponse(201, _saleCreated()));
      await SaleRepository(_client(retryApi), IdempotencyKeyStore(store)).submit(draft, operationId: 'checkout-2');

      expect(
        retryApi.requestsTo('POST /sales').single.headers['Idempotency-Key'],
        api.requestsTo('POST /sales').single.headers['Idempotency-Key'],
      );
      expect(await IdempotencyKeyStore(store).pendingOperations(), isEmpty);
    });

    test('a credit-limit refusal is final and carries the amounts', () async {
      api.on(
        'POST /sales',
        const FakeResponse(422, {
          'message': 'تتجاوز هذه العملية سقف دين العميل',
          'code': 'CREDIT_LIMIT_CONFIRMATION_REQUIRED',
          'errors': {'confirm_over_limit': ['…']},
          'details': {'credit_limit': '100.00', 'outstanding': '90.00', 'new_debt': '25.00', 'balance_after': '115.00', 'can_override': true},
          'correlation_id': '01TEST',
        }),
      );

      final failure = await sales
          .submit(SaleDraft(cart: cart, paidAmount: Money.zero, customerId: 12), operationId: 'checkout-3')
          .then<Object>((_) => fail('expected a refusal'), onError: (Object e) => e);

      expect(failure, isA<BusinessRuleViolation>());
      final violation = failure as BusinessRuleViolation;
      expect(violation.code, 'CREDIT_LIMIT_CONFIRMATION_REQUIRED');
      expect(violation.details['balance_after'], '115.00');
      expect(violation.details['can_override'], isTrue);
      expect(await IdempotencyKeyStore(store).pendingOperations(), isEmpty, reason: 'a final answer releases the key');
      expect(SaleDraft(cart: cart, paidAmount: Money.zero, customerId: 12, confirmOverLimit: true).toJson()['confirm_over_limit'], isTrue);
    });
  });
}

ApiClient _client(FakeApi api) =>
    ApiClient(baseUrl: 'http://api.test/api/v1', readToken: () async => 'tok', onSessionFailure: (_) {}, adapter: api);

Map<String, dynamic> _saleCreated({List<String> flags = const []}) => {
  'message': 'تم حفظ عملية البيع بنجاح.',
  'data': {'id': 41, 'status': 'active', 'total_amount': '50.00', 'paid_amount': '20.00', 'debt_amount': '30.00'},
  'flags': flags,
  'warnings': [
    if (flags.contains('NEGATIVE_STOCK')) {'code': 'NEGATIVE_STOCK', 'product_id': 7, 'name': 'Cola', 'balance_after': '-3'},
  ],
  'meta': {'currency': 'ILS'},
};
