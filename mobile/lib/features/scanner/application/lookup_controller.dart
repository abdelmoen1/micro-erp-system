import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../products/domain/product.dart';
import '../data/mobile_scanner_camera.dart';
import '../domain/barcode_camera.dart';

/// Overridden in tests with a fake.
final cameraPermissionsProvider = Provider<CameraPermissions>((ref) => const SystemCameraPermissions());

/// A new camera for each scanner screen (the screen disposes it). Overridden in tests.
final barcodeCameraFactoryProvider = Provider<BarcodeCamera Function()>((ref) => MobileScannerCamera.new);

/// Result of looking up one barcode (S2 spec: D found, E not found, H failed).
sealed class LookupState {
  const LookupState();
}

/// No lookup, or its sheet was closed.
final class LookupIdle extends LookupState {
  const LookupIdle();
}

final class LookupLoading extends LookupState {
  const LookupLoading(this.barcode);

  final String barcode;
}

final class LookupFound extends LookupState {
  const LookupFound(this.barcode, this.product);

  final String barcode;
  final Product product;
}

/// 404, also for inactive products (US-0401 AC3): both look the same to the user.
final class LookupNotFound extends LookupState {
  const LookupNotFound(this.barcode);

  final String barcode;
}

/// Network, 5xx or another failure; the barcode is kept for «إعادة المحاولة».
final class LookupFailed extends LookupState {
  const LookupFailed(this.barcode, this.failure);

  final String barcode;
  final ApiFailure failure;
}

/// Looks up scanned or typed barcodes through `GET /products/lookup` (T-1301-7).
/// View only: nothing here touches a cart, a sale or stock.
class LookupController extends Notifier<LookupState> {
  /// Bumped by [lookup] and [clear], so a late answer for a closed sheet is dropped.
  int _generation = 0;

  @override
  LookupState build() => const LookupIdle();

  String? get barcode => switch (state) {
    LookupIdle() => null,
    LookupLoading(:final barcode) ||
    LookupFound(:final barcode) ||
    LookupNotFound(:final barcode) ||
    LookupFailed(:final barcode) => barcode,
  };

  // TODO(U-9): lookup timeout before the network error; today ApiClient's 10 s connect / 20 s receive apply.
  Future<void> lookup(String code) async {
    final generation = ++_generation;
    state = LookupLoading(code);
    LookupState next;
    try {
      final product = await ref.read(productRepositoryProvider).lookupByBarcode(code);
      next = product == null ? LookupNotFound(code) : LookupFound(code, product);
    } on Unauthenticated {
      // The global session handler takes over: login with «انتهت الجلسة», then back to بيع.
      next = const LookupIdle();
    } on UserInactive {
      next = const LookupIdle();
    } on ApiFailure catch (failure) {
      next = LookupFailed(code, failure);
    }
    if (generation == _generation && ref.mounted) state = next;
  }

  /// «إعادة المحاولة»: sends the same barcode again.
  Future<void> retry() async {
    final code = barcode;
    if (code != null) await lookup(code);
  }

  void clear() {
    _generation++;
    state = const LookupIdle();
  }
}

final lookupControllerProvider = NotifierProvider.autoDispose<LookupController, LookupState>(LookupController.new);
