import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../products/domain/product.dart';
import '../domain/cart.dart';
import '../domain/repeat_scan_guard.dart';

/// What a scan did to the cart, for the scanner UI (sheet, haptic, message) and for timing evidence.
sealed class ScanResult {
  const ScanResult(this.code);

  final String code;
}

/// The same code again inside the D-31 cooldown: nothing happened.
final class ScanIgnored extends ScanResult {
  const ScanIgnored(super.code);
}

/// A piece product was added or its line went up by 1. [elapsed] runs from the camera event to
/// the cart update (US-0505 AC1 target ≤ 1.5 s); [lookup] is the network part of it.
final class ScanAdded extends ScanResult {
  const ScanAdded(super.code, this.line, {required this.elapsed, required this.lookup});

  final CartLine line;
  final Duration elapsed;
  final Duration lookup;
}

/// A kg product: the UI opens the weight sheet, then calls [CartController.setQuantity].
final class ScanNeedsWeight extends ScanResult {
  const ScanNeedsWeight(super.code, this.product, {required this.elapsed, required this.lookup});

  final Product product;
  final Duration elapsed;
  final Duration lookup;
}

/// No active product has this barcode (AC3: offer manual search).
final class ScanUnknown extends ScanResult {
  const ScanUnknown(super.code);
}

/// The lookup failed (network, server); the cart is unchanged.
final class ScanFailed extends ScanResult {
  const ScanFailed(super.code, this.failure);

  final ApiFailure failure;
}

/// Overridden in tests with a fixed clock.
final repeatScanGuardProvider = Provider<RepeatScanGuard>((ref) => RepeatScanGuard());

/// The POS cart (US-0505). Scanner events, the cart rules ([Cart]) and the API
/// ([ProductRepository]) stay separate: this controller only connects them.
/// Kept alive across tabs so a re-login or a trip to another screen never loses the cart.
class CartController extends Notifier<Cart> {
  @override
  Cart build() => Cart.empty;

  /// A barcode from the camera or the manual field. [retry] is «إعادة المحاولة» after a failed
  /// lookup: the same code on purpose, so the D-31 cooldown does not apply.
  Future<ScanResult> scan(String rawCode, {bool retry = false}) async {
    final code = rawCode.trim();
    final started = Stopwatch()..start();
    if (code.isEmpty) return ScanIgnored(code);
    if (!retry && !ref.read(repeatScanGuardProvider).accept(code)) return ScanIgnored(code);

    final Product? product;
    final lookupWatch = Stopwatch()..start();
    try {
      product = await ref.read(productRepositoryProvider).lookupByBarcode(code);
    } on ApiFailure catch (failure) {
      return ScanFailed(code, failure);
    }
    lookupWatch.stop();

    if (product == null) return ScanUnknown(code);
    if (product.isWeighed) {
      return ScanNeedsWeight(code, product, elapsed: started.elapsed, lookup: lookupWatch.elapsed);
    }
    if (!ref.mounted) return ScanIgnored(code);

    state = state.addPiece(product);
    return ScanAdded(code, state.lineFor(product.id)!, elapsed: started.elapsed, lookup: lookupWatch.elapsed);
  }

  /// A product picked from manual search: +1 for pieces. Returns false for a kg product, which
  /// needs the weight sheet first.
  bool addProduct(Product product) {
    if (product.isWeighed) return false;
    state = state.addPiece(product);
    return true;
  }

  /// Weight sheet (kg) or stepper (pieces); zero removes the line.
  void setQuantity(Product product, Quantity quantity) => state = state.setQuantity(product, quantity);

  void remove(int productId) => state = state.remove(productId);

  /// After a completed sale, or when the cashier empties the cart.
  void clear() {
    state = Cart.empty;
    ref.read(repeatScanGuardProvider).reset();
  }
}

final cartControllerProvider = NotifierProvider<CartController, Cart>(CartController.new);
