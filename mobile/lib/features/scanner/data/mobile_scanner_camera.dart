import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/camera_tokens.dart';
import '../domain/barcode_camera.dart';

/// [BarcodeCamera] on mobile_scanner (CameraX + bundled ML Kit on Android).
class MobileScannerCamera implements BarcodeCamera {
  /// [productCodes] adds QR and Data Matrix (S3 · add a product by its code); the till keeps to
  /// retail 1D codes so a QR on a poster never interrupts a sale.
  MobileScannerCamera({bool productCodes = false})
    : _controller = MobileScannerController(
        facing: CameraFacing.back,
        // TODO(U-8 / US-1305): formats, multi-frame confirmation and cooldown come from the spike.
        // Retail 1D codes first; Code 128 for shop-printed labels.
        formats: [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          if (productCodes) ...[BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
        ],
      ) {
    _controller.addListener(_syncTorch);
    _subscription = _controller.barcodes.listen((capture) {
      for (final barcode in capture.barcodes) {
        final value = barcode.rawValue;
        if (value != null && value.trim().isNotEmpty) {
          _detections.add(value.trim());
          return;
        }
      }
    });
  }

  final MobileScannerController _controller;
  final _detections = StreamController<String>.broadcast();
  final _torch = ValueNotifier(TorchMode.unavailable);
  StreamSubscription<BarcodeCapture>? _subscription;

  void _syncTorch() {
    _torch.value = switch (_controller.value.torchState) {
      TorchState.unavailable => TorchMode.unavailable,
      TorchState.off => TorchMode.off,
      TorchState.on || TorchState.auto => TorchMode.on,
    };
  }

  @override
  Stream<String> get detections => _detections.stream;

  @override
  ValueListenable<TorchMode> get torch => _torch;

  @override
  Widget buildPreview(BuildContext context, Rect scanWindow) => MobileScanner(
    controller: _controller,
    fit: BoxFit.cover,
    scanWindow: scanWindow,
    placeholderBuilder: (_) => const ColoredBox(color: CameraTokens.background),
    errorBuilder: (_, _) => const ColoredBox(color: CameraTokens.background),
  );

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> resume() => _controller.start();

  @override
  Future<void> toggleTorch() => _controller.toggleTorch();

  @override
  Future<void> dispose() async {
    _controller.removeListener(_syncTorch);
    await _subscription?.cancel();
    await _detections.close();
    _torch.dispose();
    await _controller.dispose();
  }
}

/// [CameraPermissions] on permission_handler.
class SystemCameraPermissions implements CameraPermissions {
  const SystemCameraPermissions();

  static CameraPermission _map(PermissionStatus status) => switch (status) {
    PermissionStatus.granted || PermissionStatus.limited => CameraPermission.granted,
    PermissionStatus.permanentlyDenied || PermissionStatus.restricted => CameraPermission.permanentlyDenied,
    _ => CameraPermission.denied,
  };

  @override
  Future<CameraPermission> status() async => _map(await Permission.camera.status);

  @override
  Future<CameraPermission> request() async => _map(await Permission.camera.request());

  @override
  Future<bool> openSettings() => openAppSettings();
}
