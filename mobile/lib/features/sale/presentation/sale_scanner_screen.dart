import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/camera_tokens.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/domain/product.dart';
import '../../scanner/application/lookup_controller.dart';
import '../../scanner/application/scan_cue.dart';
import '../../scanner/domain/barcode_camera.dart';
import '../../scanner/presentation/camera_permission_view.dart';
import '../../scanner/presentation/scan_frame.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../shell/app_shell.dart';
import '../application/cart_controller.dart';
import '../domain/cart.dart';
import 'cart_widgets.dart';
import 'checkout_screen.dart';
import 'product_search_sheet.dart';
import 'sale_widgets.dart';
import 'weight_sheet.dart';

/// «مسح» on the sale tab: the camera stays on and every product read goes into the cart, shown in a
/// panel over the camera. «إتمام البيع» opens the payment screen; nothing is sold before it.
Future<void> openSaleScanner(BuildContext context) async {
  final permission = await checkCameraPermission(context);
  if (!context.mounted) return;
  // On the root navigator, above the shell and its bottom bar (like the T-1301-7 scanner).
  await Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => SaleScannerScreen(initialPermission: permission)));
}

/// Continuous scanning for a sale (US-0505 on the camera). The cart rules, the lookup and the D-31
/// repeat guard stay in [CartController]; this screen only shows them over the preview.
class SaleScannerScreen extends ConsumerStatefulWidget {
  const SaleScannerScreen({super.key, required this.initialPermission});

  final CameraPermission initialPermission;

  @override
  ConsumerState<SaleScannerScreen> createState() => _SaleScannerScreenState();
}

class _SaleScannerScreenState extends ConsumerState<SaleScannerScreen> with WidgetsBindingObserver {
  /// The panel's resting height: the camera keeps the upper part, where the frame is.
  static const _panelInitial = 0.44;
  static const _panelMin = 0.24;
  static const _panelMax = 0.9;

  late CameraPermission _permission = widget.initialPermission;
  BarcodeCamera? _camera;
  StreamSubscription<String>? _detections;

  /// Why the camera is not reading now (a sheet, the payment screen); empty = scanning.
  final Set<String> _holds = {};

  ScanFeedback? _feedback;
  int? _justId;
  Timer? _clearTimer;
  Timer? _loadingTimer;

  /// «إتمام البيع» is on its way to the payment screen: a second tap does nothing.
  bool _leaving = false;

  CartController get _cart => ref.read(cartControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_permission == CameraPermission.granted) _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearTimer?.cancel();
    _loadingTimer?.cancel();
    unawaited(_detections?.cancel());
    unawaited(_camera?.dispose());
    super.dispose();
  }

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

  Future<void> _allowCamera() async {
    final permissions = ref.read(cameraPermissionsProvider);
    if (_permission == CameraPermission.permanentlyDenied) {
      await permissions.openSettings();
      return;
    }
    final now = await permissions.request();
    if (!mounted) return;
    setState(() => _permission = now);
    if (now == CameraPermission.granted) _startCamera();
  }

  void _startCamera() {
    final camera = ref.read(barcodeCameraFactoryProvider)();
    _camera = camera;
    _detections = camera.detections.listen(_onDetected);
  }

  // ---- the camera stays on; it only holds while something covers it ----

  bool get _reading => _camera != null && _holds.isEmpty && (ModalRoute.of(context)?.isCurrent ?? false);

  void _hold(String reason) {
    final wasReading = _holds.isEmpty;
    setState(() => _holds.add(reason));
    if (wasReading) unawaited(_camera?.pause());
  }

  void _release(String reason) {
    if (!mounted || !_holds.contains(reason)) return;
    setState(() => _holds.remove(reason));
    if (_holds.isEmpty) unawaited(_camera?.resume());
  }

  /// After the payment screen: it may have been replaced by the receipt, so scanning restarts only
  /// once this screen is on top again («بيع جديد»), never under the receipt.
  void _releaseWhenOnTop(String reason) {
    final route = ModalRoute.of(context);
    if (route == null || route.isCurrent) return _release(reason);
    final above = route.secondaryAnimation;
    if (above == null) return _release(reason);
    void listener(AnimationStatus status) {
      if (status != AnimationStatus.dismissed) return;
      above.removeStatusListener(listener);
      _release(reason);
    }

    above.addStatusListener(listener);
  }

  // ---- scanning ----

  void _onDetected(String code) {
    if (!_reading) return;
    unawaited(_handleCode(code));
  }

  void _show(ScanFeedback? feedback, {bool flash = false}) {
    _clearTimer?.cancel();
    setState(() => _feedback = feedback);
    if (flash) {
      _clearTimer = Timer(const Duration(milliseconds: 3200), () {
        if (mounted) setState(() => _feedback = null);
      });
    }
  }

  Future<void> _handleCode(String code, {bool retry = false}) async {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _show(ScanFeedback(ScanFeedbackKind.loading, code: code));
    });
    final result = await _cart.scan(code, retry: retry);
    _loadingTimer?.cancel();
    if (!mounted) return;

    switch (result) {
      case ScanIgnored():
        // The same code still in view (D-31): camera frames repeat many times a second, so a
        // repeat is silent here; the line's highlight already shows what was counted.
        if (_feedback?.kind == ScanFeedbackKind.loading) _show(null);
      case ScanAdded(:final line):
        // A code that matched a product: beep, light haptic and frame pulse (repeats are ScanIgnored).
        ref.read(scanCueProvider).success();
        setState(() => _justId = line.product.id);
        _show(
          ScanFeedback(
            line.quantity > Quantity.one ? ScanFeedbackKind.updated : ScanFeedbackKind.added,
            productName: line.product.name,
            quantity: line.quantity.format(line.product.unit),
          ),
          flash: true,
        );
      case ScanNeedsWeight(:final product):
        ref.read(scanCueProvider).success();
        _show(null);
        await _openWeight(product);
      case ScanUnknown(:final code):
        unawaited(HapticFeedback.mediumImpact());
        _show(ScanFeedback(ScanFeedbackKind.unknown, code: code));
      case ScanFailed(:final code):
        _show(ScanFeedback(ScanFeedbackKind.networkError, code: code));
    }
  }

  Future<void> _openWeight(Product product) async {
    _hold('weight');
    final existing = ref.read(cartControllerProvider).lineFor(product.id);
    final result = await showWeightSheet(context, product, current: existing?.quantity);
    _release('weight');
    if (result == null || !mounted) return;
    if (result.remove) {
      _cart.remove(product.id);
      return;
    }
    _cart.setQuantity(product, result.quantity!);
    setState(() => _justId = product.id);
    if (existing == null) _show(ScanFeedback(ScanFeedbackKind.weighedAdded, productName: product.name), flash: true);
  }

  Future<void> _search() async {
    _show(null);
    _hold('search');
    final product = await showProductSearch(context);
    _release('search');
    if (product == null || !mounted) return;
    if (product.isWeighed) {
      await _openWeight(product);
      return;
    }
    _cart.addProduct(product);
    final line = ref.read(cartControllerProvider).lineFor(product.id)!;
    setState(() => _justId = product.id);
    _show(
      ScanFeedback(
        line.quantity > Quantity.one ? ScanFeedbackKind.updated : ScanFeedbackKind.added,
        productName: product.name,
        quantity: line.quantity.format(product.unit),
      ),
      flash: true,
    );
  }

  /// Opens the payment screen. The sale is created there, only by its confirm button.
  Future<void> _checkout() async {
    if (_leaving || ref.read(cartControllerProvider).isEmpty) return;
    _leaving = true;
    _show(null);
    setState(() => _justId = null);
    _hold('checkout');
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()));
    _leaving = false;
    if (mounted) _releaseWhenOnTop('checkout');
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartControllerProvider);
    final online = ref.watch(serverReachableProvider);
    final granted = _permission == CameraPermission.granted && _camera != null;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: granted ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: granted ? CameraTokens.background : HisbahColors.ground,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            if (!online) const OfflineBanner(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !online,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    // The frame sits in the part the panel leaves uncovered at rest.
                    final frame = scanFrameRect(Size(size.width, size.height * (1 - _panelInitial) * 1.3));
                    final feedback = _feedback;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: granted
                              ? _SaleCamera(
                                  camera: _camera!,
                                  frame: frame,
                                  reading: _holds.isEmpty,
                                  quiet: feedback != null,
                                  onClose: _close,
                                )
                              : CameraPermissionView(
                                  blocked: _permission == CameraPermission.permanentlyDenied,
                                  onAllow: _allowCamera,
                                  onManual: _search,
                                  onBack: _close,
                                ),
                        ),
                        // The latest scan, right under the frame where the cashier is looking.
                        if (feedback != null && granted)
                          Positioned(
                            left: 16,
                            right: 16,
                            top: frame.bottom + 10,
                            child: ScanFeedbackCard(
                              feedback: feedback,
                              onAction: switch (feedback.kind) {
                                ScanFeedbackKind.unknown => _search,
                                ScanFeedbackKind.networkError => () => _handleCode(feedback.code, retry: true),
                                _ => null,
                              },
                            ),
                          ),
                        DraggableScrollableSheet(
                          initialChildSize: _panelInitial,
                          minChildSize: _panelMin,
                          maxChildSize: _panelMax,
                          snap: true,
                          snapSizes: const [_panelInitial],
                          builder: (context, scroll) => _CartPanel(
                            scroll: scroll,
                            justId: _justId,
                            onSearch: _search,
                            onIncrement: (line) {
                              _cart.setQuantity(line.product, line.quantity + Quantity.one, pack: line.pack);
                              setState(() => _justId = line.product.id);
                            },
                            onDecrement: (line) =>
                                _cart.setQuantity(line.product, line.quantity - Quantity.one, pack: line.pack),
                            onEditWeight: (line) => _openWeight(line.product),
                            onRemove: (line) => _cart.remove(line.product.id, pack: line.pack),
                            footer: _CheckoutBar(
                              bottomInset: bottomInset,
                              linesLabel: t.linesCount(cart.lines.length),
                              total: cart.total,
                              onCheckout: cart.isEmpty ? null : _checkout,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The preview, its frame and the top controls. While held, the frame closes and the text says so.
class _SaleCamera extends StatelessWidget {
  const _SaleCamera({
    required this.camera,
    required this.frame,
    required this.reading,
    required this.quiet,
    required this.onClose,
  });

  final BarcodeCamera camera;
  final Rect frame;
  final bool reading;

  /// A scan message is shown under the frame instead of the instruction.
  final bool quiet;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final padding = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(child: camera.buildPreview(context, frame)),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ScanFramePainter(frame: frame, locked: !reading),
            ),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: ScanPulse(frame: frame))),
        if (!quiet)
          Positioned(
            left: 16,
            right: 16,
            top: frame.bottom + 12,
            child: Semantics(
              liveRegion: true,
              child: Text(
                reading ? t.saleScanKeepGoing : t.scanPaused,
                key: const Key('saleScan.instruction'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CameraTokens.instruction,
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: padding.top + 10,
          child: Row(
            children: [
              CameraControl(
                key: const Key('saleScan.close'),
                icon: Icons.close_rounded,
                label: t.saleScanCloseA11y,
                onTap: onClose,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    t.saleScanTitle,
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
                    ? const SizedBox(width: CameraTokens.controlSize)
                    : CameraControl(
                        key: const Key('saleScan.torch'),
                        icon: torch == TorchMode.on ? Icons.flash_on : Icons.flash_off,
                        label: torch == TorchMode.on ? t.scanTorchOffA11y : t.scanTorchOnA11y,
                        selected: torch == TorchMode.on,
                        onTap: () => unawaited(camera.toggleTorch()),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The cart over the camera: drag handle and title, the lines (newest first, so the product just
/// scanned is always in view), and the payment bar pinned under them inside the panel.
class _CartPanel extends ConsumerWidget {
  const _CartPanel({
    required this.scroll,
    required this.justId,
    required this.onSearch,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditWeight,
    required this.onRemove,
    required this.footer,
  });

  final ScrollController scroll;
  final int? justId;
  final VoidCallback onSearch;
  final void Function(CartLine line) onIncrement;
  final void Function(CartLine line) onDecrement;
  final void Function(CartLine line) onEditWeight;
  final void Function(CartLine line) onRemove;
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartControllerProvider);
    final lines = cart.lines.reversed.toList();
    return Material(
      key: const Key('saleScan.panel'),
      color: HisbahColors.ground,
      elevation: 12,
      shadowColor: Colors.black54,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.list(
                    children: [
                      const _DragHandle(),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                t.cartPanelTitle,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            key: const Key('saleScan.search'),
                            onPressed: onSearch,
                            icon: const Icon(Icons.search, size: 20),
                            label: Text(t.searchByName),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: cart.isEmpty
                        ? LineCard(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                              child: Column(
                                children: [
                                  Text(
                                    t.cartEmptyTitle,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.saleScanEmptyBody,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : LineCard(
                            child: Column(
                              children: [
                                for (final (i, line) in lines.indexed)
                                  CartLineRow(
                                    key: Key('cart.line.${line.product.id}${line.pack ? '.pack' : ''}'),
                                    line: line,
                                    divider: i > 0,
                                    justAdded: line.product.id == justId,
                                    overStock: cart.exceedsStock(line),
                                    onIncrement: () => onIncrement(line),
                                    onDecrement: () => onDecrement(line),
                                    onEditWeight: () => onEditWeight(line),
                                    onRemove: () => onRemove(line),
                                    onAddPack: () => ref.read(cartControllerProvider.notifier).addPack(line.product),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          footer,
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      width: 40,
      height: 5,
      decoration: BoxDecoration(color: HisbahColors.borderStrong, borderRadius: BorderRadius.circular(999)),
    ),
  );
}

/// Pinned under the panel: how much, and the one way forward. It never sells by itself.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.bottomInset,
    required this.linesLabel,
    required this.total,
    required this.onCheckout,
  });

  final double bottomInset;
  final String linesLabel;
  final Money total;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
      decoration: const BoxDecoration(
        color: HisbahColors.surface,
        border: Border(top: BorderSide(color: HisbahColors.border)),
      ),
      child: Row(
        children: [
          // Fixed shares, so a long total or large text never squeezes the other side into wrapping.
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$linesLabel · ${t.totalWord}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Num(shekel(total), key: const Key('cart.total'), size: 26, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                key: const Key('cart.checkout'),
                onPressed: onCheckout,
                icon: const Icon(Icons.point_of_sale_rounded),
                label: Text(t.completeSale, maxLines: 1, overflow: TextOverflow.ellipsis),
                // The theme's buttons are full-width; this one shares its row with the total.
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
