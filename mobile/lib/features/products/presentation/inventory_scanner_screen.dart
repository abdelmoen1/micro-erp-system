import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/camera_tokens.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/domain/repeat_scan_guard.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../scanner/application/lookup_controller.dart';
import '../../scanner/application/scan_cue.dart';
import '../../scanner/domain/barcode_camera.dart';
import '../../scanner/presentation/camera_permission_view.dart';
import '../../scanner/presentation/scan_frame.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../domain/product_code_payload.dart';
import 'add_product_flow.dart';
import 'product_detail_screen.dart' show openProduct;

/// S3 · add products by scanning (Owner / Manager). Its own camera, separate from the sale: a code
/// read here never touches the cart. A compact form opens over the live camera; after a save the
/// form closes, a short confirmation shows at the top and the next code can be scanned at once.
/// True when at least one product was added or restocked.
Future<bool> openInventoryScanner(BuildContext context) async {
  final permission = await checkCameraPermission(context);
  if (!context.mounted) return false;
  final changed = await Navigator.of(
    context,
    rootNavigator: true,
  ).push<bool>(MaterialPageRoute(builder: (_) => InventoryScannerScreen(initialPermission: permission)));
  return changed ?? false;
}

/// What is open over the camera.
sealed class _Sheet {
  const _Sheet();
}

final class _Checking extends _Sheet {
  const _Checking(this.code);

  final String code;
}

/// Already in this store: show it, offer «إضافة كمية». Never a second product.
final class _Existing extends _Sheet {
  const _Existing(this.product);

  final Product product;
}

/// A new product: what the code and the shared catalog know, the rest typed by the cashier.
final class _NewProduct extends _Sheet {
  const _NewProduct(this.payload, {this.catalogName, this.catalogUnit, this.lookupFailed = false});

  final ProductCodePayload payload;
  final String? catalogName;
  final ProductUnit? catalogUnit;
  final bool lookupFailed;
}

class InventoryScannerScreen extends ConsumerStatefulWidget {
  const InventoryScannerScreen({super.key, required this.initialPermission});

  final CameraPermission initialPermission;

  @override
  ConsumerState<InventoryScannerScreen> createState() => _InventoryScannerScreenState();
}

class _InventoryScannerScreenState extends ConsumerState<InventoryScannerScreen> with WidgetsBindingObserver {
  late CameraPermission _permission = widget.initialPermission;
  BarcodeCamera? _camera;
  StreamSubscription<String>? _detections;

  /// The same code still in front of the lens after its sheet closed is not opened again (D-31).
  final _guard = RepeatScanGuard();

  _Sheet? _sheet;
  String? _toast;
  Timer? _toastTimer;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_permission == CameraPermission.granted) _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
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
    final camera = ref.read(productCodeCameraFactoryProvider)();
    _camera = camera;
    _detections = camera.detections.listen(_onDetected);
  }

  /// The camera keeps running under the form; reads are only counted (for the repeat guard), not
  /// acted on, until the form closes, so typing never opens another product by accident.
  void _onDetected(String raw) {
    final code = raw.trim();
    final fresh = _guard.accept(code);
    if (!fresh || _sheet != null || code.isEmpty) return;
    ref.read(scanCueProvider).success();
    unawaited(_open(parseProductCode(code)));
  }

  /// Manual entry over the camera (a product without a readable code).
  void _openManual() {
    if (_sheet != null) return;
    setState(() => _sheet = const _NewProduct(ProductCodeData()));
  }

  Future<void> _open(ProductCodePayload payload) async {
    final barcode = payload is ProductCodeData ? payload.barcode : null;
    if (barcode == null) {
      setState(() => _sheet = _NewProduct(payload));
      return;
    }
    setState(() => _sheet = _Checking(barcode));
    try {
      final match = await ref.read(productRepositoryProvider).catalogLookup(barcode);
      if (!mounted || _sheet is! _Checking) return;
      setState(() {
        _sheet = match.product != null
            ? _Existing(match.product!)
            : _NewProduct(payload, catalogName: match.catalogName, catalogUnit: match.catalogUnit);
      });
    } on ApiFailure {
      // The server refuses a duplicate barcode on save anyway (422), so the form can go on.
      if (!mounted || _sheet is! _Checking) return;
      setState(() => _sheet = _NewProduct(payload, lookupFailed: true));
    }
  }

  void _closeSheet() => setState(() => _sheet = null);

  /// The open new-product form's «discard what you typed?» check, so a back gesture asks first.
  Future<bool> Function()? _newProductGuard;

  void _done(String message) {
    unawaited(HapticFeedback.lightImpact());
    _changed = true;
    _toastTimer?.cancel();
    setState(() {
      _sheet = null;
      _toast = message;
    });
    _toastTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _close() => Navigator.of(context).pop(_changed);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final granted = _permission == CameraPermission.granted && _camera != null;
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final sheet = _sheet;

    return PopScope(
      canPop: sheet == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || sheet == null) return;
        final guard = sheet is _NewProduct ? _newProductGuard : null;
        if (guard == null || await guard()) _closeSheet();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: granted ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: granted ? CameraTokens.background : HisbahColors.ground,
          // The form follows the keypad itself; the preview never resizes.
          resizeToAvoidBottomInset: false,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final frame = scanFrameRect(size);
              return Stack(
                children: [
                  Positioned.fill(
                    child: granted
                        ? _InventoryCamera(
                            camera: _camera!,
                            frame: frame,
                            busy: sheet != null,
                            onClose: _close,
                            onManual: _openManual,
                          )
                        : CameraPermissionView(
                            blocked: _permission == CameraPermission.permanentlyDenied,
                            onAllow: _allowCamera,
                            onManual: _openManual,
                            onBack: _close,
                          ),
                  ),
                  // Near the top, under the controls: short, announced, gone after 3.5 s.
                  Positioned(
                    left: 16,
                    right: 16,
                    top: padding.top + 70,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _toast == null ? const SizedBox.shrink() : _Toast(key: ValueKey(_toast), message: _toast!),
                    ),
                  ),
                  if (sheet != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: keyboard,
                      child: ConstrainedBox(
                        // Over the camera, never over the whole screen: the top stays live.
                        // At most ~2/3 of what the keyboard leaves, and never over the top controls.
                        constraints: BoxConstraints(
                          maxHeight: [
                            (size.height - keyboard) * 0.68,
                            size.height - keyboard - padding.top - 64,
                          ].reduce((a, b) => a < b ? a : b).clamp(160.0, double.infinity),
                        ),
                        child: Material(
                          key: const Key('inventory.sheet'),
                          color: HisbahColors.surface,
                          elevation: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                          clipBehavior: Clip.antiAlias,
                          child: switch (sheet) {
                            _Checking(:final code) => _CheckingBody(code: code, onClose: _closeSheet),
                            _Existing(:final product) => _ExistingBody(
                              product: product,
                              bottomInset: keyboard > 0 ? 0 : padding.bottom,
                              onClose: _closeSheet,
                              onAdded: (updated) =>
                                  _done(t.invStockAdded(updated.name, updated.currentStock.format(updated.unit))),
                              onUpdated: (updated) => setState(() => _sheet = _Existing(updated)),
                            ),
                            _NewProduct() => _NewProductBody(
                              key: ValueKey(sheet),
                              sheet: sheet,
                              bottomInset: keyboard > 0 ? 0 : padding.bottom,
                              onClose: _closeSheet,
                              onGuard: (guard) => _newProductGuard = guard,
                              onSaved: (product) => _done(t.savedTitle(product.name)),
                            ),
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InventoryCamera extends StatelessWidget {
  const _InventoryCamera({
    required this.camera,
    required this.frame,
    required this.busy,
    required this.onClose,
    required this.onManual,
  });

  final BarcodeCamera camera;
  final Rect frame;

  /// A sheet is open: the frame closes and the text says reads wait for it.
  final bool busy;
  final VoidCallback onClose;
  final VoidCallback onManual;

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
              painter: ScanFramePainter(frame: frame, locked: busy),
            ),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: ScanPulse(frame: frame))),
        Positioned(
          left: 16,
          right: 16,
          top: frame.bottom + 14,
          child: Semantics(
            liveRegion: true,
            child: Text(
              busy ? t.invWaiting : t.invInstruction,
              key: const Key('inventory.instruction'),
              textAlign: TextAlign.center,
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
                key: const Key('inventory.close'),
                icon: Icons.close_rounded,
                label: t.invCloseA11y,
                onTap: onClose,
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    t.invTitle,
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
                        icon: torch == TorchMode.on ? Icons.flash_on : Icons.flash_off,
                        label: torch == TorchMode.on ? t.scanTorchOffA11y : t.scanTorchOnA11y,
                        selected: torch == TorchMode.on,
                        onTap: () => unawaited(camera.toggleTorch()),
                      ),
              ),
            ],
          ),
        ),
        if (!busy)
          Positioned(
            left: 16,
            right: 16,
            bottom: CameraTokens.manualButtonGap + padding.bottom,
            child: FilledButton.icon(
              key: const Key('inventory.manual'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: HisbahColors.ink,
                minimumSize: const Size.fromHeight(CameraTokens.manualButtonHeight),
              ),
              icon: const Icon(Icons.edit_outlined, size: 22),
              label: Text(t.addManual, maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: onManual,
            ),
          ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const Key('addProduct.saved'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: StatusTone.success.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StatusTone.success.line),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: StatusTone.success.fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w700, color: StatusTone.success.fg),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The sheet's own title row: what this is, and ✕ back to scanning.
class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.onClose, this.code});

  final String title;
  final String? code;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                if (code != null)
                  LtrValue(formatBarcode(code!), style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
              ],
            ),
          ),
          IconButton(
            key: const Key('inventory.sheetClose'),
            tooltip: t.invBackToScanning,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _CheckingBody extends StatelessWidget {
  const _CheckingBody({required this.code, required this.onClose});

  final String code;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetTitle(title: t.addChecking, code: code, onClose: onClose),
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 28), child: LinearProgressIndicator()),
      ],
    );
  }
}

/// Already in the store: never added twice. «إضافة كمية» records goods received (a stock movement).
class _ExistingBody extends ConsumerStatefulWidget {
  const _ExistingBody({
    required this.product,
    required this.bottomInset,
    required this.onClose,
    required this.onAdded,
    required this.onUpdated,
  });

  final Product product;
  final double bottomInset;
  final VoidCallback onClose;
  final void Function(Product updated) onAdded;

  /// The product page changed it (price, stock, carton): show the new values here.
  final void Function(Product updated) onUpdated;

  @override
  ConsumerState<_ExistingBody> createState() => _ExistingBodyState();
}

class _ExistingBodyState extends ConsumerState<_ExistingBody> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  bool _reasonFilled = false;
  bool _adding = false;
  bool _saving = false;

  /// Received by the carton (products with a carton): the quantity counts whole cartons.
  bool _byPack = false;
  String? _error;
  String? _banner;

  /// One adjustment: kept across retries of the same values, so a resend is never counted twice.
  String? _operationId;

  @override
  void initState() {
    super.initState();
    _quantity.addListener(_edited);
    _reason.addListener(_edited);
  }

  /// The usual reason, already written; the cashier may change it.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reasonFilled) return;
    _reasonFilled = true;
    _reason.text = AppLocalizations.of(context).invReasonDefault;
  }

  void _edited() => _operationId = null;

  /// The full product page (price, stock, movements). Reads under the open sheet are ignored, so
  /// the camera does not act while it is open; coming back shows what changed.
  Future<void> _openProduct() async {
    final repository = ref.read(productRepositoryProvider);
    if (!await openProduct(context, widget.product.id) || !mounted) return;
    try {
      widget.onUpdated(await repository.product(widget.product.id));
    } on ApiFailure {
      // The sheet keeps the values it had; the product page already saved the change.
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations t) async {
    if (_saving) return;
    final product = widget.product;
    final text = _quantity.text.trim();
    final weighed = product.isWeighed && !_byPack;
    final pattern = weighed ? RegExp(r'^\d{1,7}(\.\d{1,3})?$') : RegExp(r'^\d{1,7}$');
    final valid = pattern.hasMatch(text) && Quantity.parse(text) > Quantity.zero;
    setState(() {
      _error = valid ? null : (weighed ? t.invQtyKg : (_byPack ? t.invQtyPack : t.invQtyPiece));
      _banner = null;
    });
    if (!valid || _reason.text.trim().isEmpty) {
      if (_reason.text.trim().isEmpty) setState(() => _banner = t.invReasonRequired);
      return;
    }
    _operationId ??= 'restock-${product.id}-${DateTime.now().microsecondsSinceEpoch}';
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(stockRepositoryProvider)
          .addStock(product, quantity: text, reason: _reason.text, operationId: _operationId!, pack: _byPack);
      if (!mounted) return;
      widget.onAdded(updated);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _banner = switch (failure) {
          ValidationFailed(:final fieldErrors) when fieldErrors.isNotEmpty => fieldErrors.values.first.first,
          Forbidden() => t.invStockForbidden,
          NetworkFailure() => t.formNetwork,
          _ => failure.message ?? t.formFailed,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final p = widget.product;
    final unitWord = p.unit == ProductUnit.kg ? t.prodPerKg : t.prodPerPiece;
    return _SheetLayout(
      title: _SheetTitle(title: t.addExistsTitle, code: p.barcode, onClose: _saving ? null : widget.onClose),
      bottomInset: widget.bottomInset,
      action: _adding
          ? FilledButton(
              key: const Key('stock.save'),
              onPressed: _saving ? null : () => _save(t),
              child: _saving
                  ? BusyLabel(busy: true, label: t.formSaving)
                  : Text(_banner == t.formNetwork ? t.payRetry : t.invAddStockSave),
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('inventory.scanNext'),
                    onPressed: widget.onClose,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, HisbahSize.button)),
                    child: Text(t.addScanAnother, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('inventory.addStock'),
                    onPressed: () => setState(() => _adding = true),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, HisbahSize.button)),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(t.invAddStock, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
      fields: [
        LineCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  key: const Key('addProduct.existing'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isolateLtr(formatShekel(p.sellingPrice))} / $unitWord · ${t.invStockNow(isolateLtr(p.currentStock.format(p.unit)))}',
                  style: const TextStyle(color: HisbahColors.inkMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(t.invExistsNote, style: const TextStyle(fontSize: 13, height: 1.6, color: HisbahColors.inkMuted)),
        if (!_adding)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('inventory.openProduct'),
              onPressed: _openProduct,
              icon: const Icon(Icons.edit_outlined),
              label: Text(t.invOpenProduct),
            ),
          ),
        const SizedBox(height: 12),
        if (_adding) ...[
          if (_banner != null) ...[
            ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _banner!, alert: true),
            const SizedBox(height: 10),
          ],
          if (p.hasPack) ...[
            // Goods usually arrive by the carton: count cartons, the server adds their pieces.
            OptionRow(
              children: [
                OptionButton(
                  key: const Key('stock.byPiece'),
                  label: t.formByPiece,
                  selected: !_byPack,
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          _byPack = false;
                          _operationId = null;
                        }),
                ),
                OptionButton(
                  key: const Key('stock.byPack'),
                  label: t.unitChipPack(p.packSize!),
                  selected: _byPack,
                  onTap: _saving
                      ? null
                      : () => setState(() {
                          _byPack = true;
                          _operationId = null;
                        }),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          _QuickField(
            fieldKey: 'stock.quantity',
            hint: t.phAddQty,
            label: t.invAddStockQty(_byPack ? t.packWord : unitWord),
            controller: _quantity,
            number: true,
            whole: _byPack || !p.isWeighed,
            autofocus: true,
            enabled: !_saving,
            error: _error,
            action: TextInputAction.next,
            onChanged: () => setState(() {}),
          ),
          if (_byPack && RegExp(r'^\d{1,5}$').hasMatch(_quantity.text.trim()))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                t.packEquals(Quantity.whole(int.parse(_quantity.text.trim()) * p.packSize!).format(ProductUnit.piece)),
                key: const Key('stock.packPieces'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          _QuickField(
            fieldKey: 'stock.reason',
            hint: t.phReason,
            label: t.invReason,
            controller: _reason,
            enabled: !_saving,
            action: TextInputAction.done,
            onSubmitted: () => _save(t),
          ),
        ],
      ],
    );
  }
}

/// The new-product form over the camera: only what a cashier needs (name, how it is sold, prices,
/// the quantity on the shelf). The values stay in the fields after any failure.
class _NewProductBody extends ConsumerStatefulWidget {
  const _NewProductBody({
    super.key,
    required this.sheet,
    required this.bottomInset,
    required this.onClose,
    required this.onGuard,
    required this.onSaved,
  });

  final _NewProduct sheet;
  final double bottomInset;
  final VoidCallback onClose;

  /// Receives this form's «may it close?» check, used by the screen's back gesture.
  final void Function(Future<bool> Function() guard) onGuard;
  final void Function(Product product) onSaved;

  @override
  ConsumerState<_NewProductBody> createState() => _NewProductBodyState();
}

class _NewProductBodyState extends ConsumerState<_NewProductBody> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _stock = TextEditingController();
  final _packSize = TextEditingController();
  final _packPrice = TextEditingController();
  ProductUnit _unit = ProductUnit.piece;

  /// «يُباع بالكرتونة أيضاً» is on (piece products only); off by default to keep the form short.
  bool _pack = false;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _banner;

  /// The last send may have reached the server (no answer after sending). A retry that then hears
  /// «barcode already in your store» means the first one was saved, not a duplicate.
  bool _uncertain = false;

  ProductCodeData? get _data =>
      widget.sheet.payload is ProductCodeData ? widget.sheet.payload as ProductCodeData : null;

  String? get _barcode => _data?.barcode;

  @override
  void initState() {
    super.initState();
    final data = _data;
    _name.text = widget.sheet.catalogName ?? data?.name ?? '';
    _price.text = data?.sellingPrice ?? '';
    _unit = widget.sheet.catalogUnit ?? data?.unit ?? ProductUnit.piece;
    _opened = (_name.text, _price.text, _unit);
    widget.onGuard(_mayClose);
  }

  /// What the form held when it opened (prefilled from the code or the catalog).
  late final (String, String, ProductUnit) _opened;

  /// Something was typed or changed since the form opened.
  bool get _edited =>
      (_name.text, _price.text, _unit) != _opened ||
      _pack ||
      [_cost, _stock, _packSize, _packPrice].any((c) => c.text.trim().isNotEmpty);

  /// Closing loses unsaved typing, so it asks first; never while a save is on its way.
  Future<bool> _mayClose() async {
    if (_saving) return false;
    return !_edited || await confirmDiscard(context);
  }

  @override
  void dispose() {
    for (final c in [_name, _price, _cost, _stock, _packSize, _packPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppLocalizations t) async {
    if (_saving) return;
    final stock = _stock.text.trim().isEmpty ? '0' : _stock.text;
    final errors = productFormErrors(
      t,
      unit: _unit,
      name: _name.text,
      price: _price.text,
      cost: _cost.text,
      stock: stock,
      pack: _pack,
      packSize: _packSize.text,
      packPrice: _packPrice.text,
    );
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    final repository = ref.read(productRepositoryProvider);
    try {
      final product = await repository.create(
        NewProduct(
          name: _name.text,
          barcode: _barcode,
          unit: _unit,
          sellingPrice: _price.text,
          costPrice: _cost.text,
          currentStock: stock,
          packSize: _pack ? _packSize.text : null,
          packPrice: _pack ? _packPrice.text : null,
        ),
      );
      if (!mounted) return;
      widget.onSaved(product);
    } on ValidationFailed catch (failure) {
      final barcode = _barcode;
      if (_uncertain && barcode != null && failure.fieldErrors.containsKey('barcode')) {
        final recovered = await _recover(barcode);
        if (recovered != null && mounted) return widget.onSaved(recovered);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uncertain = false;
        _errors = {
          for (final e in failure.fieldErrors.entries)
            if (e.value.isNotEmpty && e.key != 'barcode') e.key: e.value.first,
        };
        final barcodeError = failure.fieldErrors['barcode'];
        _banner = barcodeError != null && barcodeError.isNotEmpty
            ? barcodeError.first
            : (_errors.isEmpty ? failure.message ?? t.formFailed : null);
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (failure is NetworkFailure && failure.maybeDelivered) _uncertain = true;
        _banner = switch (failure) {
          Forbidden() => t.formForbidden,
          NetworkFailure(:final maybeDelivered) => maybeDelivered ? t.invNetworkUncertain : t.formNetwork,
          _ => failure.message ?? t.formFailed,
        };
      });
    }
  }

  /// A corrected field loses its old error at once (and the carton hint follows the new value).
  void _clearError(String key) => setState(() => _errors = {..._errors}..remove(key));

  /// After an unanswered save: is the product with this barcode in the store now?
  Future<Product?> _recover(String barcode) async {
    try {
      return (await ref.read(productRepositoryProvider).catalogLookup(barcode)).product;
    } on ApiFailure {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final fromCode = _data?.fromCode ?? const <String>{};
    final payload = widget.sheet.payload;
    final note =
        payload is ProductCodeData &&
            payload.barcode != null &&
            widget.sheet.catalogName == null &&
            fromCode.length == 1
        ? null // A plain barcode: the title already shows it.
        : productCodeNote(t, payload is ProductCodeData && payload.fromCode.isEmpty ? null : payload);
    final raw = payload is UnreadableCode ? payload.raw : null;
    final retry = _banner == t.formNetwork || _banner == t.invNetworkUncertain;

    return _SheetLayout(
      title: _SheetTitle(
        title: t.formNewTitle,
        code: _barcode,
        onClose: _saving
            ? null
            : () async {
                if (await _mayClose()) widget.onClose();
              },
      ),
      bottomInset: widget.bottomInset,
      action: FilledButton(
        key: const Key('form.save'),
        onPressed: _saving ? null : () => _save(t),
        child: _saving ? BusyLabel(busy: true, label: t.formSaving) : Text(retry ? t.payRetry : t.formSave),
      ),
      fields: [
        if (_banner != null) ...[
          ToneCard(
            key: const Key('inventory.error'),
            tone: StatusTone.error,
            icon: Icons.error_outline_rounded,
            title: _banner!,
            alert: true,
          ),
          const SizedBox(height: 10),
        ],
        if (widget.sheet.catalogName != null) ...[
          _InlineNote(
            key: const Key('addProduct.fromCatalog'),
            tone: StatusTone.success,
            icon: Icons.inventory_2_outlined,
            text: t.invFromCatalog,
          ),
          const SizedBox(height: 8),
        ] else if (note != null) ...[
          ToneCard(
            tone: note.$1,
            icon: Icons.qr_code_2_rounded,
            title: note.$2,
            children: [if (raw != null) LtrValue(raw.length > 120 ? '${raw.substring(0, 120)}…' : raw)],
          ),
          const SizedBox(height: 10),
        ],
        if (widget.sheet.lookupFailed) ...[
          ToneCard(tone: StatusTone.warning, icon: Icons.wifi_off_rounded, title: t.addLookupFailed),
          const SizedBox(height: 10),
        ],
        _QuickField(
          fieldKey: 'name',
          label: t.formName,
          hint: t.formNameHint,
          controller: _name,
          enabled: !_saving,
          error: _errors['name'],
          fromCode: fromCode.contains('name'),
          autofocus: _name.text.isEmpty,
          action: TextInputAction.next,
        ),
        Text(t.formSoldBy, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        OptionRow(
          children: [
            OptionButton(
              key: const Key('form.unit.piece'),
              label: t.formByPiece,
              selected: _unit == ProductUnit.piece,
              onTap: _saving ? null : () => setState(() => _unit = ProductUnit.piece),
            ),
            OptionButton(
              key: const Key('form.unit.kg'),
              label: t.formByKg,
              selected: _unit == ProductUnit.kg,
              onTap: _saving ? null : () => setState(() => _unit = ProductUnit.kg),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Two short money fields side by side; they stack only when the text is very large.
        LayoutBuilder(
          builder: (context, c) {
            final price = _QuickField(
              fieldKey: 'selling_price',
              label: t.formPrice,
              helper: _unit == ProductUnit.kg ? t.formPriceHelpKg : t.formPriceHelpPiece,
              controller: _price,
              number: true,
              enabled: !_saving,
              error: _errors['selling_price'],
              fromCode: fromCode.contains('selling_price'),
              onChanged: () => _clearError('selling_price'),
              autofocus: _name.text.isNotEmpty && _price.text.isEmpty,
              action: TextInputAction.next,
            );
            final cost = _QuickField(
              fieldKey: 'cost_price',
              label: t.formCost,
              helper: t.formCostHelp,
              optional: true,
              controller: _cost,
              number: true,
              enabled: !_saving,
              error: _errors['cost_price'],
              action: TextInputAction.next,
            );
            if (c.maxWidth < 300 || MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(children: [price, cost]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: price),
                const SizedBox(width: 10),
                Expanded(child: cost),
              ],
            );
          },
        ),
        if (_unit == ProductUnit.piece)
          PackSection(
            enabled: !_saving,
            open: _pack,
            onOpen: (open) => setState(() => _pack = open),
            size: _packSize,
            price: _packPrice,
            piecePrice: _price.text,
            errors: _errors,
            fieldBuilder: (key, label, controller) => _QuickField(
              hint: key == 'pack_size' ? t.phPackSize : t.phPackPrice,
              fieldKey: key,
              label: label,
              controller: controller,
              number: true,
              whole: key == 'pack_size',
              enabled: !_saving,
              error: _errors[key],
              action: TextInputAction.next,
              onChanged: () => _clearError(key),
            ),
          ),
        _QuickField(
          fieldKey: 'current_stock',
          label: t.invOpeningStock(_unit == ProductUnit.kg ? t.prodPerKg : t.prodPerPiece),
          hint: t.phOpeningStock,
          controller: _stock,
          number: true,
          whole: _unit == ProductUnit.piece,
          enabled: !_saving,
          error: _errors['current_stock'],
          action: TextInputAction.done,
          onSubmitted: () => _save(t),
        ),
      ],
    );
  }
}

/// A quick sheet: its title on top, the fields scrolling in between, and the one action pinned at
/// the bottom, so the save button stays in reach above the keyboard on a small phone.
class _SheetLayout extends StatelessWidget {
  const _SheetLayout({required this.title, required this.fields, required this.action, required this.bottomInset});

  final Widget title;
  final List<Widget> fields;
  final Widget action;
  final double bottomInset;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      title,
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
        ),
      ),
      Container(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: HisbahColors.border)),
        ),
        child: action,
      ),
    ],
  );
}

/// One short line of context (from the catalog, from the code) instead of a full card.
class _InlineNote extends StatelessWidget {
  const _InlineNote({super.key, required this.tone, required this.icon, required this.text});

  final StatusTone tone;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        Icon(icon, size: 18, color: tone.fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: tone.fg),
          ),
        ),
      ],
    ),
  );
}

/// A labelled field in the quick sheets: error under it, numeric keypad and LTR for numbers, and
/// the keyboard's next / done actions moving through the form.
class _QuickField extends StatelessWidget {
  const _QuickField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.enabled,
    this.hint,
    this.helper,
    this.error,
    this.number = false,
    this.whole = false,
    this.optional = false,
    this.fromCode = false,
    this.autofocus = false,
    this.action,
    this.onSubmitted,
    this.onChanged,
  });

  final String fieldKey;
  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController controller;
  final bool enabled;
  final String? error;
  final bool number;

  /// A whole number (pieces, cartons): the plain digit keypad, without a decimal key.
  final bool whole;

  /// Marked «(اختياري)»; every other field gets the required «*».
  final bool optional;
  final bool fromCode;
  final bool autofocus;
  final TextInputAction? action;
  final VoidCallback? onSubmitted;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldLabel(label: label, required: !optional, fromCode: fromCode),
          const SizedBox(height: 4),
          TextField(
            key: Key('form.$fieldKey'),
            controller: controller,
            enabled: enabled,
            autofocus: autofocus,
            textInputAction: action,
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
            onChanged: onChanged == null ? null : (_) => onChanged!(),
            keyboardType: !number
                ? TextInputType.text
                : whole
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: number ? const [LatinDigitsFormatter()] : null,
            textDirection: number ? TextDirection.ltr : null,
            textAlign: number ? TextAlign.left : TextAlign.start,
            decoration: InputDecoration(
              // What the field is for sits inside it, not as a note under it; only errors go below.
              hintText: helper ?? hint,
              hintMaxLines: 2,
              hintTextDirection: Directionality.of(context),
              errorText: error,
              errorMaxLines: 3,
              isDense: true,
              filled: true,
              fillColor: HisbahColors.raised,
            ),
          ),
        ],
      ),
    );
  }
}
