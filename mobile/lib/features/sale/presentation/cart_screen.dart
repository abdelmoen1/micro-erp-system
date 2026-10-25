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
import '../../shell/tab_screens.dart';
import '../application/cart_controller.dart';
import 'cart_widgets.dart';
import 'checkout_screen.dart';
import 'product_search_sheet.dart';
import 'sale_scanner_screen.dart';
import 'sale_widgets.dart';
import 'weight_sheet.dart';

/// SCR-M-02 · cart (US-0505): scan or search, piece stepper, weight sheet for kg, exact total.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  ScanFeedback? _feedback;
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

  void _show(ScanFeedback? feedback, {bool flash = false}) {
    _clearTimer?.cancel();
    setState(() => _feedback = feedback);
    if (flash) {
      _clearTimer = Timer(const Duration(milliseconds: 3200), () {
        if (mounted) setState(() => _feedback = null);
      });
    }
  }

  /// «مسح»: the camera stays open and fills the cart over it (sale_scanner_screen.dart).
  Future<void> _scan() async {
    _show(null);
    await openSaleScanner(context);
  }

  Future<void> _handleCode(String code, {bool retry = false}) async {
    // «جارٍ البحث» only when the lookup is slower than 300 ms (hi-fi M-02 scan-loading).
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _show(ScanFeedback(ScanFeedbackKind.loading, code: code));
    });
    final result = await _cart.scan(code, retry: retry);
    _loadingTimer?.cancel();
    if (!mounted) return;

    switch (result) {
      case ScanIgnored(:final code) when code.isNotEmpty:
        _show(const ScanFeedback(ScanFeedbackKind.duplicate), flash: true);
      case ScanIgnored():
        break;
      case ScanAdded(:final line):
        unawaited(HapticFeedback.lightImpact());
        final again = line.quantity > Quantity.one;
        setState(() => _justId = line.product.id);
        _show(
          ScanFeedback(
            again ? ScanFeedbackKind.updated : ScanFeedbackKind.added,
            productName: line.product.name,
            quantity: line.quantity.format(line.product.unit),
          ),
          flash: true,
        );
      case ScanNeedsWeight(:final product):
        _show(null);
        await _openWeight(product);
      case ScanUnknown(:final code):
        _show(ScanFeedback(ScanFeedbackKind.unknown, code: code));
      case ScanFailed(:final code):
        _show(ScanFeedback(ScanFeedbackKind.networkError, code: code));
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
    if (existing == null) _show(ScanFeedback(ScanFeedbackKind.weighedAdded, productName: product.name), flash: true);
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
      ScanFeedback(
        line.quantity > Quantity.one ? ScanFeedbackKind.updated : ScanFeedbackKind.added,
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
                child: ScanFeedbackCard(
                  feedback: _feedback!,
                  onAction: switch (_feedback!.kind) {
                    ScanFeedbackKind.unknown => () => _search(),
                    ScanFeedbackKind.networkError => () => _handleCode(_feedback!.code, retry: true),
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
                                CartLineRow(
                                  key: Key('cart.line.${line.product.id}${line.pack ? '.pack' : ''}'),
                                  line: line,
                                  divider: i > 0,
                                  justAdded: line.product.id == _justId,
                                  overStock: cart.exceedsStock(line),
                                  onIncrement: () {
                                    _cart.setQuantity(line.product, line.quantity + Quantity.one, pack: line.pack);
                                    setState(() => _justId = line.product.id);
                                  },
                                  onDecrement: () =>
                                      _cart.setQuantity(line.product, line.quantity - Quantity.one, pack: line.pack),
                                  onEditWeight: () => _openWeight(line.product),
                                  onRemove: () => _cart.remove(line.product.id, pack: line.pack),
                                  onAddPack: () => _cart.addPack(line.product),
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
