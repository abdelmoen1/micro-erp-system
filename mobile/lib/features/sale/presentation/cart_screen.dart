import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../products/domain/product.dart';
import '../../scanner/presentation/scanner_screen.dart';
import '../../shell/tab_screens.dart';
import '../application/cart_controller.dart';
import '../domain/cart.dart';
import 'checkout_screen.dart';
import 'product_search_sheet.dart';
import 'sale_widgets.dart';
import 'weight_sheet.dart';

/// The scan feedback slot: one message at a time, the newest replaces the older (hi-fi M-02).
enum _FeedbackKind { loading, added, updated, weighedAdded, duplicate, unknown, networkError }

class _Feedback {
  const _Feedback(this.kind, {this.code = '', this.productName = '', this.quantity = ''});

  final _FeedbackKind kind;
  final String code;
  final String productName;
  final String quantity;
}

/// SCR-M-02 · cart (US-0505): scan or search, piece stepper, weight sheet for kg, exact total.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  _Feedback? _feedback;
  int? _justId;
  Timer? _clearTimer;
  Timer? _loadingTimer;

  @override
  void dispose() {
    _clearTimer?.cancel();
    _loadingTimer?.cancel();
    super.dispose();
  }

  CartController get _cart => ref.read(cartControllerProvider.notifier);

  void _show(_Feedback? feedback, {bool flash = false}) {
    _clearTimer?.cancel();
    setState(() => _feedback = feedback);
    if (flash) {
      _clearTimer = Timer(const Duration(milliseconds: 3200), () {
        if (mounted) setState(() => _feedback = null);
      });
    }
  }

  Future<void> _scan() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    await _handleCode(code);
  }

  Future<void> _handleCode(String code, {bool retry = false}) async {
    // «جارٍ البحث» only when the lookup is slower than 300 ms (hi-fi M-02 scan-loading).
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _show(_Feedback(_FeedbackKind.loading, code: code));
    });
    final result = await _cart.scan(code, retry: retry);
    _loadingTimer?.cancel();
    if (!mounted) return;

    switch (result) {
      case ScanIgnored(:final code) when code.isNotEmpty:
        _show(const _Feedback(_FeedbackKind.duplicate), flash: true);
      case ScanIgnored():
        break;
      case ScanAdded(:final line):
        unawaited(HapticFeedback.lightImpact());
        final again = line.quantity > Quantity.one;
        setState(() => _justId = line.product.id);
        _show(
          _Feedback(
            again ? _FeedbackKind.updated : _FeedbackKind.added,
            productName: line.product.name,
            quantity: line.quantity.format(line.product.unit),
          ),
          flash: true,
        );
      case ScanNeedsWeight(:final product):
        _show(null);
        await _openWeight(product);
      case ScanUnknown(:final code):
        _show(_Feedback(_FeedbackKind.unknown, code: code));
      case ScanFailed(:final code):
        _show(_Feedback(_FeedbackKind.networkError, code: code));
    }
  }

  Future<void> _openWeight(Product product) async {
    final existing = ref.read(cartControllerProvider).lineFor(product.id);
    final result = await showWeightSheet(context, product, current: existing?.quantity);
    if (result == null || !mounted) return;
    if (result.remove) {
      _cart.remove(product.id);
      return;
    }
    _cart.setQuantity(product, result.quantity!);
    setState(() => _justId = product.id);
    if (existing == null) _show(_Feedback(_FeedbackKind.weighedAdded, productName: product.name), flash: true);
  }

  Future<void> _search({String query = ''}) async {
    _show(null);
    final product = await showProductSearch(context, initialQuery: query);
    if (product == null || !mounted) return;
    if (product.isWeighed) {
      await _openWeight(product);
      return;
    }
    _cart.addProduct(product);
    final line = ref.read(cartControllerProvider).lineFor(product.id)!;
    setState(() => _justId = product.id);
    _show(
      _Feedback(
        line.quantity > Quantity.one ? _FeedbackKind.updated : _FeedbackKind.added,
        productName: product.name,
        quantity: line.quantity.format(product.unit),
      ),
      flash: true,
    );
  }

  void _checkout() {
    _show(null);
    setState(() => _justId = null);
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartControllerProvider);
    final session = ref.watch(sessionProvider);
    final storeName = session is SignedIn ? session.user.storeName : '';
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TabHeader(title: t.tabPos, storeName: storeName),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('cart.search'),
                      onPressed: _search,
                      icon: const Icon(Icons.search, color: HisbahColors.inkMuted),
                      label: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(t.searchByName, style: const TextStyle(color: HisbahColors.inkSubtle, fontWeight: FontWeight.w500)),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: HisbahColors.surface,
                        side: const BorderSide(color: HisbahColors.borderStrong, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    height: 52,
                    child: _ScanButton(filled: cart.isEmpty, label: t.scanShort, a11y: t.scanBarcode, onPressed: _scan),
                  ),
                ],
              ),
            ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _FeedbackCard(
                  feedback: _feedback!,
                  onAction: switch (_feedback!.kind) {
                    _FeedbackKind.unknown => () => _search(),
                    _FeedbackKind.networkError => () => _handleCode(_feedback!.code, retry: true),
                    _ => null,
                  },
                ),
              ),
            Expanded(
              child: cart.isEmpty
                  ? ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), children: const [_EmptyCart()])
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        LineCard(
                          child: Column(
                            children: [
                              for (final (i, line) in cart.lines.indexed)
                                _CartRow(
                                  key: Key('cart.line.${line.product.id}'),
                                  line: line,
                                  divider: i > 0,
                                  justAdded: line.product.id == _justId,
                                  onIncrement: () {
                                    _cart.setQuantity(line.product, line.quantity + Quantity.one);
                                    setState(() => _justId = line.product.id);
                                  },
                                  onDecrement: () => _cart.setQuantity(line.product, line.quantity - Quantity.one),
                                  onEditWeight: () => _openWeight(line.product),
                                  onRemove: () => _cart.remove(line.product.id),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            ActionBar(
              bottomInset: bottomInset,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t.linesCount(cart.lines.length)} · ${t.totalWord}',
                          style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
                        ),
                        Num(shekel(cart.total), key: const Key('cart.total'), size: 28, weight: FontWeight.w700),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 132,
                    child: FilledButton(
                      key: const Key('cart.checkout'),
                      onPressed: cart.isEmpty ? null : _checkout,
                      child: Text(t.payButton),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «مسح»: the screen's primary action while the cart is empty, then secondary (hi-fi M-02).
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.filled, required this.label, required this.a11y, required this.onPressed});

  final bool filled;
  final String label;
  final String a11y;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [const Icon(Icons.crop_free, size: 22), const SizedBox(width: 8), Text(label)],
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Semantics(
      label: a11y,
      button: true,
      excludeSemantics: true,
      child: filled
          ? FilledButton(
              key: const Key('cart.scan'),
              onPressed: onPressed,
              style: FilledButton.styleFrom(shape: shape, padding: EdgeInsets.zero),
              child: child,
            )
          : OutlinedButton(
              key: const Key('cart.scan'),
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: shape,
                padding: EdgeInsets.zero,
                side: const BorderSide(color: HisbahColors.primary, width: 1.5),
                backgroundColor: HisbahColors.surface,
              ),
              child: child,
            ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback, this.onAction});

  final _Feedback feedback;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (tone, icon, title, text, action) = switch (feedback.kind) {
      _FeedbackKind.loading => (StatusTone.neutral, Icons.schedule_rounded, t.scanLookingUp, t.barcodeWord, null),
      _FeedbackKind.added => (StatusTone.success, Icons.check_rounded, t.scanAdded, feedback.productName, null),
      _FeedbackKind.updated => (
        StatusTone.success,
        Icons.check_rounded,
        t.scanIncremented(feedback.productName),
        t.scanQuantityNow(feedback.quantity),
        null,
      ),
      _FeedbackKind.weighedAdded => (StatusTone.success, Icons.check_rounded, t.scanAddedWeighed, feedback.productName, null),
      _FeedbackKind.duplicate => (StatusTone.neutral, Icons.repeat_rounded, t.scanDuplicate, t.scanDuplicateBody, null),
      _FeedbackKind.unknown => (StatusTone.error, Icons.warning_amber_rounded, t.scanUnknown, t.scanUnknownBody, t.searchByName),
      _FeedbackKind.networkError => (StatusTone.error, Icons.wifi_off_rounded, t.scanLookupFailed, t.scanLookupFailedBody, t.retry),
    };
    final showCode = feedback.kind == _FeedbackKind.unknown || feedback.kind == _FeedbackKind.loading;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: Key('cart.feedback.${feedback.kind.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tone.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: tone.fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: tone.fg, height: 1.45)),
                  Wrap(
                    spacing: 4,
                    children: [
                      Text(text, style: const TextStyle(fontSize: 13, height: 1.5, color: HisbahColors.ink)),
                      if (showCode && feedback.code.isNotEmpty) Num(feedback.code, size: 13),
                    ],
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: HisbahColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: Text(action),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Column(
          children: [
            const Icon(Icons.crop_free, size: 44, color: HisbahColors.primary),
            const SizedBox(height: 10),
            Text(t.cartEmptyTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              t.cartEmptyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.6, color: HisbahColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({
    super.key,
    required this.line,
    required this.divider,
    required this.justAdded,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditWeight,
    required this.onRemove,
  });

  final CartLine line;
  final bool divider;
  final bool justAdded;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEditWeight;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final product = line.product;
    final kg = product.isWeighed;
    final qty = line.quantity.format(product.unit);
    final justText = kg ? t.justAddedWeighed : (line.quantity > Quantity.one ? t.justIncremented : t.justNew);

    return Container(
      color: justAdded ? HisbahColors.highlightRow : HisbahColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: HisbahColors.border)) : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4)),
                      UnitChip(label: kg ? t.unitChipWeighed : t.unitChipPiece),
                      if (justAdded)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: HisbahColors.primary, borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            justText,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: HisbahColors.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Num(shekel(line.total), size: 17, weight: FontWeight.w700),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(children: [TextSpan(text: shekel(line.unitPrice)), TextSpan(text: ' / ${kg ? t.kgShort : t.pieceWord}')]),
                        style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                      ),
                      if (product.barcode != null) Num(product.barcode!, size: 12, weight: FontWeight.w400, color: HisbahColors.inkSubtle),
                    ],
                  ),
                ),
                if (kg)
                  Row(
                    children: [
                      _BoxButton(
                        key: Key('cart.edit.${product.id}'),
                        label: t.editWeightOf(product.name),
                        onTap: onEditWeight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Num(qty, size: 17, weight: FontWeight.w700),
                            const SizedBox(width: 4),
                            Text(t.kgShort, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 16, color: HisbahColors.primary),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      _BoxButton(
                        label: t.removeItem(product.name),
                        onTap: onRemove,
                        width: 48,
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: HisbahColors.dangerSolid),
                      ),
                    ],
                  )
                else
                  _Stepper(
                    productId: product.id,
                    quantity: qty,
                    isLast: line.quantity <= Quantity.one,
                    decLabel: line.quantity <= Quantity.one ? t.removeItem(product.name) : t.decreaseItem(product.name),
                    incLabel: t.increaseItem(product.name),
                    onDecrement: onDecrement,
                    onIncrement: onIncrement,
                  ),
              ],
            ),
            if (line.exceedsStock) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: StatusTone.warning.bg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.warning.fg),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.lineStockNote(product.currentStock.format(product.unit)),
                        style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w600, color: StatusTone.warning.fg),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.productId,
    required this.quantity,
    required this.isLast,
    required this.decLabel,
    required this.incLabel,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int productId;
  final String quantity;
  final bool isLast;
  final String decLabel;
  final String incLabel;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Container(
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HisbahColors.raised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HisbahColors.borderStrong, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            key: Key('cart.dec.$productId'),
            label: decLabel,
            icon: isLast ? Icons.delete_outline_rounded : Icons.remove_rounded,
            color: isLast ? HisbahColors.dangerSolid : HisbahColors.ink,
            onTap: onDecrement,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              border: Border.symmetric(vertical: BorderSide(color: HisbahColors.border)),
            ),
            child: Num(quantity, key: Key('cart.qty.$productId'), size: 17, weight: FontWeight.w700),
          ),
          _StepButton(
            key: Key('cart.inc.$productId'),
            label: incLabel,
            icon: Icons.add_rounded,
            color: HisbahColors.primary,
            onTap: onIncrement,
          ),
        ],
      ),
    ),
  );
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(onTap: onTap, child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 18, color: color))),
  );
}

class _BoxButton extends StatelessWidget {
  const _BoxButton({super.key, required this.label, required this.onTap, required this.child, this.width});

  final String label;
  final VoidCallback onTap;
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: HisbahColors.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: HisbahColors.borderStrong, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          width: width,
          padding: width == null ? const EdgeInsets.symmetric(horizontal: 12) : null,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  );
}
