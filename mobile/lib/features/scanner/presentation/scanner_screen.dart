import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/camera_tokens.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../l10n/app_localizations.dart';
import '../../shell/app_shell.dart';
import '../application/lookup_controller.dart';
import '../domain/barcode_camera.dart';
import 'camera_permission_view.dart';
import 'manual_entry_sheet.dart';
import 'scan_frame.dart';
import 'scan_sheets.dart';

/// A · «مسح باركود» from the بيع tab. B: the permission is checked on every open, and the
/// Android dialog is shown only now, over the entry context (never at app launch).
Future<void> openScanner(BuildContext context, WidgetRef ref) async {
  final permissions = ref.read(cameraPermissionsProvider);
  var permission = await permissions.status();
  // TODO(U-10): no rationale screen before the first system dialog (rationale only after a denial).
  if (permission == CameraPermission.denied) permission = await permissions.request();
  if (!context.mounted) return;
  // A page-less route on the root navigator, above the shell and its bottom bar. It is not a
  // go_router location, so after a 401 re-login returns to بيع without the scanner (spec H).
  await Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => ScannerScreen(initialPermission: permission)));
}

/// C / C′ / F with the D, E, G and H sheets on top (S2 · T-1301-7). View only.
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key, required this.initialPermission});

  final CameraPermission initialPermission;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

enum _Source { camera, manual }

class _ScannerScreenState extends ConsumerState<ScannerScreen> with WidgetsBindingObserver {
  late CameraPermission _permission = widget.initialPermission;
  BarcodeCamera? _camera;
  StreamSubscription<String>? _detections;
  bool _cameraPaused = false;

  bool _manualOpen = false;
  _Source _source = _Source.camera;

  /// The failure being retried: its sheet stays up, busy, until the new answer arrives.
  LookupFailed? _retrying;

  Timer? _hintTimer;
  bool _hint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_permission == CameraPermission.granted) _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    unawaited(_detections?.cancel());
    // Releasing the camera also turns the torch off.
    unawaited(_camera?.dispose());
    super.dispose();
  }

  /// Back from the Android settings (F blocked): check again, and scan if it is now allowed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _permission == CameraPermission.granted) return;
    unawaited(_recheckPermission());
  }

  Future<void> _recheckPermission() async {
    final now = await ref.read(cameraPermissionsProvider).status();
    if (!mounted || now == _permission) return;
    setState(() => _permission = now);
    if (now == CameraPermission.granted) _startCamera();
  }

  void _startCamera() {
    final camera = ref.read(barcodeCameraFactoryProvider)();
    _camera = camera;
    _cameraPaused = false;
    _detections = camera.detections.listen(_onDetected);
    _restartHintTimer();
  }

  // ---- scanning state ----

  bool get _scanning => _camera != null && !_cameraPaused;

  void _onDetected(String code) {
    if (!_scanning || _manualOpen || ref.read(lookupControllerProvider) is! LookupIdle) return;
    // TODO(C4): Android CONFIRM haptic is not exposed by Flutter; mediumImpact stands in.
    // TODO(U-5): no beep on read (off by default in the spec).
    unawaited(HapticFeedback.mediumImpact());
    _source = _Source.camera;
    _pauseCamera();
    unawaited(ref.read(lookupControllerProvider.notifier).lookup(code));
  }

  void _pauseCamera() {
    final camera = _camera;
    if (camera == null || _cameraPaused) return;
    setState(() {
      _cameraPaused = true;
      _hint = false;
    });
    _hintTimer?.cancel();
    unawaited(camera.pause());
  }

  /// Scanning restarts only from «مسح منتج آخر» / «مسح مرة أخرى» or after closing a sheet.
  void _resumeCamera() {
    final camera = _camera;
    if (camera == null || !_cameraPaused) return;
    setState(() => _cameraPaused = false);
    unawaited(camera.resume());
    _restartHintTimer();
  }

  // TODO(U-7): no auto-pause of the camera after inactivity yet (guidance ~8–10 s, one-tap resume).
  void _restartHintTimer() {
    _hintTimer?.cancel();
    if (_hint) setState(() => _hint = false);
    _hintTimer = Timer(CameraTokens.hintDelay, () {
      if (mounted && _scanning) setState(() => _hint = true);
    });
  }

  // ---- actions ----

  void _closeResult() {
    ref.read(lookupControllerProvider.notifier).clear();
    _resumeCamera();
  }

  void _openManual() {
    ref.read(lookupControllerProvider.notifier).clear();
    _pauseCamera();
    setState(() => _manualOpen = true);
  }

  void _cancelManual() {
    ref.read(lookupControllerProvider.notifier).clear();
    setState(() => _manualOpen = false);
    _resumeCamera();
  }

  void _submitManual(String code) {
    _source = _Source.manual;
    unawaited(ref.read(lookupControllerProvider.notifier).lookup(code));
  }

  Future<void> _allowCamera() async {
    final permissions = ref.read(cameraPermissionsProvider);
    if (_permission == CameraPermission.permanentlyDenied) {
      await permissions.openSettings();
      return; // Checked again when the app resumes.
    }
    final now = await permissions.request();
    if (!mounted) return;
    setState(() => _permission = now);
    if (now == CameraPermission.granted) _startCamera();
  }

  void _backToSale() => Navigator.of(context).pop();

  /// Android back: closes the open sheet first, then the scanner.
  bool get _sheetOpen => _manualOpen || ref.read(lookupControllerProvider) is! LookupIdle;

  void _closeTopSheet() {
    if (_manualOpen) {
      _cancelManual();
    } else {
      _closeResult();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(lookupControllerProvider);
    // A typed code keeps the manual sheet open (busy) until its answer replaces it.
    ref.listen(lookupControllerProvider, (_, next) {
      if (next is LookupLoading) return;
      setState(() {
        _retrying = null;
        if (next is! LookupIdle) _manualOpen = false;
      });
    });
    final online = ref.watch(serverReachableProvider);
    final granted = _permission == CameraPermission.granted && _camera != null;

    final sheet = _buildSheet(lookup);

    return PopScope(
      canPop: !(_manualOpen || lookup is! LookupIdle),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _sheetOpen) _closeTopSheet();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: granted ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: granted ? CameraTokens.background : HisbahColors.ground,
          // The sheets follow the keypad themselves; the preview must not resize.
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              // Spec H: the global offline banner when the server is known to be unreachable.
              if (!online) const OfflineBanner(),
              Expanded(
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: !online,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: granted
                            ? _CameraLayer(
                                camera: _camera!,
                                lookup: lookup,
                                locked: _source == _Source.camera && lookup is! LookupIdle,
                                paused: _cameraPaused,
                                hint: _hint,
                                onClose: _backToSale,
                                onManual: _openManual,
                              )
                            : CameraPermissionView(
                                blocked: _permission == CameraPermission.permanentlyDenied,
                                onAllow: _allowCamera,
                                onManual: _openManual,
                                onBack: _backToSale,
                              ),
                      ),
                      if (sheet != null) Positioned(left: 0, right: 0, bottom: 0, child: sheet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildSheet(LookupState lookup) {
    if (_manualOpen) {
      return ManualEntrySheet(busy: lookup is LookupLoading, onSubmit: _submitManual, onCancel: _cancelManual);
    }
    final retrying = _retrying;
    if (lookup is LookupLoading && retrying != null) {
      return LookupErrorSheet(
        barcode: retrying.barcode,
        failure: retrying.failure,
        retrying: true,
        onRetry: () {},
        onBack: _backToSale,
      );
    }
    return switch (lookup) {
      LookupIdle() || LookupLoading() => null,
      LookupFound(:final barcode, :final product) => ProductFoundSheet(
        barcode: barcode,
        product: product,
        onScanAnother: _closeResult,
        onBack: _backToSale,
      ),
      LookupNotFound(:final barcode) => NotFoundSheet(
        barcode: barcode,
        onScanAgain: _closeResult,
        onManual: _openManual,
      ),
      LookupFailed(:final barcode, :final failure) => LookupErrorSheet(
        barcode: barcode,
        failure: failure,
        retrying: false,
        onRetry: () {
          setState(() => _retrying = lookup);
          unawaited(ref.read(lookupControllerProvider.notifier).retry());
        },
        onBack: _backToSale,
      ),
    };
  }
}

/// C · full-screen rear camera with the frame, instruction, status, torch, close and manual entry.
class _CameraLayer extends StatelessWidget {
  const _CameraLayer({
    required this.camera,
    required this.lookup,
    required this.locked,
    required this.paused,
    required this.hint,
    required this.onClose,
    required this.onManual,
  });

  final BarcodeCamera camera;
  final LookupState lookup;

  /// A code was read by the camera (C′): closed frame + ✓, frozen preview.
  final bool locked;
  final bool paused;
  final bool hint;
  final VoidCallback onClose;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final padding = MediaQuery.paddingOf(context);
    final instruction = locked ? t.scanRead : (paused ? t.scanPaused : t.scanInstruction);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final frame = scanFrameRect(size);
        return Stack(
          children: [
            Positioned.fill(child: camera.buildPreview(context, frame)),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ScanFramePainter(frame: frame, locked: locked),
                ),
              ),
            ),
            if (locked)
              Positioned(
                left: frame.center.dx - CameraTokens.badgeSize / 2,
                top: frame.top - CameraTokens.badgeSize / 2,
                child: const ExcludeSemantics(child: ScanReadBadge()),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: size.height - frame.top + 26,
              child: Semantics(
                liveRegion: true,
                child: Text(
                  instruction,
                  key: const Key('scan.instruction'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CameraTokens.instruction,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: frame.bottom + 14,
              child: Column(
                children: [
                  _StatusPill(lookup: lookup, paused: paused),
                  if (hint) ...[const SizedBox(height: 12), const _HintCard()],
                ],
              ),
            ),
            // Top bar: close at the start (right in RTL), torch at the end.
            Positioned(
              left: 12,
              right: 12,
              top: padding.top + 10,
              child: Row(
                children: [
                  _CameraControl(
                    key: const Key('scan.close'),
                    icon: Icons.close_rounded,
                    label: t.scanCloseA11y,
                    onTap: onClose,
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        t.scanBarcode,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  ValueListenableBuilder(
                    valueListenable: camera.torch,
                    builder: (_, torch, _) => torch == TorchMode.unavailable
                        // Hidden without a flash; the space keeps the title centred.
                        ? const SizedBox(width: CameraTokens.controlSize)
                        : _CameraControl(
                            key: const Key('scan.torch'),
                            icon: torch == TorchMode.on ? Icons.flash_on : Icons.flash_off,
                            label: torch == TorchMode.on ? t.scanTorchOffA11y : t.scanTorchOnA11y,
                            selected: torch == TorchMode.on,
                            onTap: () => unawaited(camera.toggleTorch()),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: CameraTokens.manualButtonGap + padding.bottom,
              child: FilledButton.icon(
                key: const Key('scan.manual'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: HisbahColors.ink,
                  minimumSize: const Size.fromHeight(CameraTokens.manualButtonHeight),
                ),
                icon: const Icon(Icons.keyboard_outlined, size: 22),
                label: Text(t.scanManual, maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: onManual,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// `camera.control`: 48 dp circle; "on" = white fill + ink icon (state by icon and fill too).
class _CameraControl extends StatelessWidget {
  const _CameraControl({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    toggled: selected ? true : null,
    excludeSemantics: true,
    child: Material(
      color: selected ? Colors.white : CameraTokens.control,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: CameraTokens.controlSize,
          child: Icon(icon, size: 22, color: selected ? HisbahColors.ink : Colors.white),
        ),
      ),
    ),
  );
}

/// `camera.status`: what the scanner is doing, as text (the dot is only a second cue).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.lookup, required this.paused});

  final LookupState lookup;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (text, code, dot) = switch (lookup) {
      LookupLoading() => (t.scanSearchingProduct, null, CameraTokens.dotRead),
      LookupFound(:final barcode) ||
      LookupNotFound(:final barcode) ||
      LookupFailed(:final barcode) => (t.scanPaused, barcode, CameraTokens.dotRead),
      LookupIdle() =>
        paused ? (t.scanPaused, null, CameraTokens.dotRead) : (t.scanSearchingCode, null, CameraTokens.dotScanning),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('scan.status'),
        constraints: const BoxConstraints(minHeight: CameraTokens.statusHeight),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(color: CameraTokens.control, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: CameraTokens.statusDot,
              height: CameraTokens.statusDot,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text, style: CameraTokens.statusText, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (code != null) ...[
              const SizedBox(width: 8),
              LtrValue(formatBarcode(code), style: CameraTokens.statusText.copyWith(fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}

/// `camera.hint`: after 8 s without a read.
class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('scan.hint'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: CameraTokens.hint, borderRadius: BorderRadius.circular(HisbahRadius.field)),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${t.scanHintTitle} ',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(text: t.scanHintBody),
            ],
          ),
          style: CameraTokens.hintText,
        ),
      ),
    );
  }
}
