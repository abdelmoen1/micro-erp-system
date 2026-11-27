import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../domain/cart.dart';
import 'cart_controller.dart';

/// A customer's cart put aside at the till («علّق») while the cashier serves someone else. Lives on
/// this phone only: nothing is sent and no stock is reserved until it is taken back and paid.
class HeldCart {
  const HeldCart({required this.id, required this.label, required this.heldAt, required this.cart});

  factory HeldCart.fromJson(Map<String, dynamic> json) => HeldCart(
    id: json['id'] as String,
    label: json['label'] as String? ?? '',
    heldAt: DateTime.tryParse(json['held_at'] as String? ?? '') ?? DateTime.now(),
    cart: Cart.fromJson(json['lines'] as List<dynamic>),
  );

  final String id;

  /// What the cashier typed to know whose it is (a name, «أبو أحمد», «الطاولة»); may be empty.
  final String label;
  final DateTime heldAt;
  final Cart cart;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'held_at': heldAt.toIso8601String(),
    'lines': cart.toJson(),
  };
}

/// The held carts of the signed-in store, oldest first, kept on the phone so closing the app
/// (or the phone restarting) never loses them.
class HeldCartsController extends Notifier<List<HeldCart>> {
  @override
  List<HeldCart> build() {
    final session = ref.watch(sessionProvider);
    final storeId = session is SignedIn ? session.user.storeId : null;
    _key = storeId == null ? null : 'held_carts.store.$storeId';
    _loaded = false;
    unawaited(_restore());
    return const [];
  }

  String? _key;

  /// Changes made before the phone's copy was read are merged with it, never overwritten.
  bool _loaded = false;

  Future<void> _restore() async {
    final key = _key;
    if (key == null) return;
    List<HeldCart> saved = const [];
    try {
      final raw = await ref.read(keyValueStoreProvider).read(key);
      if (raw != null && raw.isNotEmpty) {
        saved = [
          for (final item in jsonDecode(raw) as List<dynamic>) HeldCart.fromJson(item as Map<String, dynamic>),
        ];
      }
    } on Object {
      // An unreadable copy (an older format, a damaged write) starts the list empty.
    }
    if (!ref.mounted || key != _key) return;
    _loaded = true;
    if (state.isEmpty) {
      state = saved;
      return;
    }
    final known = {for (final h in state) h.id};
    state = [...saved.where((h) => !known.contains(h.id)), ...state];
    await _save();
  }

  Future<void> _save() async {
    final key = _key;
    if (key == null) return;
    final store = ref.read(keyValueStoreProvider);
    if (state.isEmpty) {
      await store.delete(key);
    } else {
      await store.write(key, jsonEncode([for (final h in state) h.toJson()]));
    }
  }

  void _set(List<HeldCart> next) {
    state = next;
    // Before the phone's copy is read, saving would drop it; _restore merges and the next change saves.
    if (_loaded) unawaited(_save());
  }

  /// «علّق»: the till's cart goes aside under [label] and the till starts empty. Returns the held cart.
  HeldCart hold({String label = ''}) {
    final cart = ref.read(cartControllerProvider);
    final held = HeldCart(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label.trim(),
      heldAt: DateTime.now(),
      cart: cart,
    );
    _set([...state, held]);
    ref.read(cartControllerProvider.notifier).clear();
    return held;
  }

  /// Takes [held] back to the till. A cart already on the till is held in its place first (under
  /// [labelForCurrent]), so switching between two customers never loses either.
  void resume(HeldCart held, {String labelForCurrent = ''}) {
    final current = ref.read(cartControllerProvider);
    final rest = state.where((h) => h.id != held.id).toList();
    if (!current.isEmpty) {
      rest.add(
        HeldCart(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          label: labelForCurrent.trim(),
          heldAt: DateTime.now(),
          cart: current,
        ),
      );
    }
    _set(rest);
    ref.read(cartControllerProvider.notifier).replace(held.cart);
  }

  /// The customer left: the held cart is thrown away (nothing was sold, nothing to undo).
  void discard(HeldCart held) => _set(state.where((h) => h.id != held.id).toList());
}

final heldCartsProvider = NotifierProvider<HeldCartsController, List<HeldCart>>(HeldCartsController.new);
