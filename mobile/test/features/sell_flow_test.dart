import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartshop/core/api/api_client.dart';
import 'package:smartshop/core/money/fixed_point.dart';
import 'package:smartshop/core/providers.dart';
import 'package:smartshop/core/storage/key_value_store.dart';
import 'package:smartshop/features/auth/application/session_controller.dart';
import 'package:smartshop/features/auth/domain/app_user.dart';
import 'package:smartshop/features/products/data/product_repository.dart';
import 'package:smartshop/features/products/domain/product.dart';
import 'package:smartshop/features/sale/application/cart_controller.dart';
import 'package:smartshop/features/sale/application/held_carts.dart';
import 'package:smartshop/features/sale/domain/cart.dart';
import 'package:smartshop/features/sale/domain/repeat_scan_guard.dart';

import '../support/fake_api.dart';
import 'products_test.dart' show productJson;

/// No sale below zero, and a customer's cart held at the till (kept on the phone).
void main() {
  Product product({int id = 7, String stock = '2', String unit = 'piece', int? packSize, String? packPrice}) =>
      Product.fromJson({
        ...productJson(id: id, name: 'P$id', barcode: '$id$id$id', price: '5.00', stock: stock, unit: unit),
        'pack_size': ?packSize,
        'pack_price': ?packPrice,
      });

  group('Cart stock room', () {
    test('pieces stop at the recorded stock; lowering is always allowed', () {
      final cola = product(stock: '2');
      final two = Cart.empty.addPiece(cola).addPiece(cola);

      expect(two.allows(cola, Quantity.whole(3)), isFalse);
      expect(two.roomFor(cola), Quantity.whole(2));
      // A stock that fell meanwhile never blocks taking items off.
      final fell = product(stock: '1');
      expect(two.allows(fell, Quantity.whole(1)), isTrue);
    });

    test('cartons and pieces of one product share the shelf', () {
      final water = product(id: 8, stock: '30', packSize: 24, packPrice: '40.00');
      final carton = Cart.empty.addPack(water);

      expect(carton.roomFor(water), Quantity.whole(6));
      expect(carton.allows(water, Quantity.whole(6)), isTrue);
      expect(carton.allows(water, Quantity.whole(7)), isFalse);
      expect(carton.allows(water, Quantity.whole(2), pack: true), isFalse);
    });

    test('an empty shelf takes nothing, by the piece or by weight', () {
      expect(Cart.empty.allows(product(stock: '0'), Quantity.one), isFalse);
      final nuts = product(id: 9, unit: 'kg', stock: '0.500');
      expect(Cart.empty.allows(nuts, Quantity.parse('0.500')), isTrue);
      expect(Cart.empty.allows(nuts, Quantity.parse('0.501')), isFalse);
    });
  });

  group('CartController without negative stock', () {
    late FakeApi api;
    late DateTime now;
    late ProviderContainer container;

    setUp(() {
      api = FakeApi();
      now = DateTime(2026, 11, 27, 9);
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

    test('the last piece sells; one more scan says out of stock and leaves the cart', () async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': productJson(id: 7, barcode: '111', stock: '1')}));

      expect(await controller().scan('111'), isA<ScanAdded>());
      now = now.add(const Duration(seconds: 2));
      final again = await controller().scan('111');

      expect(again, isA<ScanOutOfStock>());
      expect((again as ScanOutOfStock).product.id, 7);
      expect(cart().lineFor(7)!.quantity, Quantity.one);
    });

    test('a product with nothing on the shelf never enters the cart', () async {
      api.on('GET /products/lookup', FakeResponse(200, {'data': productJson(id: 5, barcode: '555', stock: '0')}));

      expect(await controller().scan('555'), isA<ScanOutOfStock>());
      expect(cart().isEmpty, isTrue);
      expect(controller().addProduct(product(id: 5, stock: '0')), CartChange.outOfStock);
      expect(cart().isEmpty, isTrue);
    });

    test('a weight above the shelf is refused; the stepper stops at the stock', () {
      final nuts = product(id: 9, unit: 'kg', stock: '1.000');
      expect(controller().setQuantity(nuts, Quantity.parse('1.200')), CartChange.outOfStock);
      expect(cart().isEmpty, isTrue);
      expect(controller().setQuantity(nuts, Quantity.parse('0.750')), CartChange.done);

      final cola = product(stock: '2');
      controller().addProduct(cola);
      expect(controller().setQuantity(cola, Quantity.whole(2)), CartChange.done);
      expect(controller().setQuantity(cola, Quantity.whole(3)), CartChange.outOfStock);
      expect(cart().lineFor(7)!.quantity, Quantity.whole(2));
    });
  });

  group('Held carts', () {
    test('a held cart keeps its lines, cartons and set prices through JSON', () {
      final water = product(id: 8, stock: '30', packSize: 24, packPrice: '40.00');
      final cart = Cart.empty
          .addPiece(water)
          .addPack(water)
          .setPrice(8, Money.parse('4.50'))
          .setQuantity(product(id: 9, unit: 'kg', stock: '3.000'), Quantity.parse('0.750'));
      final held = HeldCart(id: '1', label: 'أبو أحمد', heldAt: DateTime(2026, 11, 27, 10), cart: cart);

      final back = HeldCart.fromJson(jsonDecode(jsonEncode(held.toJson())) as Map<String, dynamic>);

      expect(back.label, 'أبو أحمد');
      expect(back.cart.total, cart.total);
      expect(back.cart.toSaleItems(), cart.toSaleItems());
      expect(back.cart.lineFor(8, pack: true)!.product.packSize, 24);
      expect(back.cart.lineFor(9)!.product.currentStock, Quantity.parse('3.000'));
    });

    late MemoryKeyValueStore store;

    ProviderContainer signedIn() {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          sessionProvider.overrideWith(() => _SignedIn(AppUser.fromJson(userJson()))),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() => store = MemoryKeyValueStore());

    test('hold frees the till; resume swaps carts; both survive an app restart', () async {
      final first = signedIn();
      first.listen(heldCartsProvider, (_, _) {});
      await pumpEventQueue();
      final till = first.read(cartControllerProvider.notifier);
      final held = first.read(heldCartsProvider.notifier);

      till.addProduct(product(id: 1, stock: '5'));
      final a = held.hold(label: 'A');
      expect(first.read(cartControllerProvider).isEmpty, isTrue);

      till.addProduct(product(id: 2, stock: '5'));
      held.resume(a, labelForCurrent: 'B');

      expect(first.read(cartControllerProvider).lineFor(1), isNotNull);
      expect(first.read(heldCartsProvider).map((h) => h.label), ['B']);
      await pumpEventQueue();

      // The app closes and opens again: the held cart is read back from the phone.
      final second = signedIn();
      second.listen(heldCartsProvider, (_, _) {});
      await pumpEventQueue();
      final restored = second.read(heldCartsProvider);
      expect(restored.map((h) => h.label), ['B']);
      expect(restored.single.cart.lineFor(2)!.quantity, Quantity.one);

      second.read(heldCartsProvider.notifier).discard(restored.single);
      await pumpEventQueue();
      expect(await store.read('held_carts.store.1'), isNull);
    });
  });
}

class _SignedIn extends SessionController {
  _SignedIn(this.user);

  final AppUser user;

  @override
  SessionState build() => SignedIn(user);
}

ApiClient _client(FakeApi api) => ApiClient(
  baseUrl: 'http://api.test/api/v1',
  readToken: () async => 'tok',
  onSessionFailure: (_) {},
  adapter: api,
);
