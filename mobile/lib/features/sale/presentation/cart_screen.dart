import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../more/presentation/more_widgets.dart' show MoreField, FormSheet, confirmDanger, pushScreen, showNote;
import '../../products/domain/product.dart';
import '../../shell/tab_screens.dart';
import '../application/cart_controller.dart';
import '../application/held_carts.dart';
import '../domain/cart.dart';
import 'cart_widgets.dart';
import 'checkout_screen.dart';
import 'product_search_sheet.dart';
import 'sale_scanner_screen.dart';
import 'sale_widgets.dart';
import 'sell_and_count.dart';
import 'suspended_invoices_screen.dart';
import 'weight_sheet.dart';

/// Sales waiting for a bank transfer to land (server-side suspended invoices). Zero when the
/// server cannot be asked (offline, or a role that may not list them): the chip just hides.
final pendingTransfersProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    return (await ref.watch(moreRepositoryProvider).suspendedInvoices('pending_transfer')).length;
  } on ApiFailure {
    return 0;
  }
});

final _heldTime = DateFormat.Hm('en');

/// SCR-M-02 · cart (US-0505): scan or search, piece stepper, weight sheet for kg, exact total.
/// Never past the recorded stock; an unknown code becomes a product here; a customer's cart can
/// be held while the next one is served, and taken back from the strip on top.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> with TillActions<CartScreen> {
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

  @override
  void showFeedback(ScanFeedback? feedback, {bool flash = false}) {
    _clearTimer?.cancel();
    setState(() => _feedback = feedback);
    if (flash) {
      _clearTimer = Timer(const Duration(milliseconds: 3200), () {
        if (mounted) setState(() => _feedback = null);
      });
    }
  }

  @override
  void markJust(int productId) => setState(() => _justId = productId);

  /// «مسح»: the camera stays open and fills the cart over it (sale_scanner_screen.dart).
  Future<void> _scan() async {
    showFeedback(null);
    await openSaleScanner(context);
  }

  Future<void> _handleCode(String code, {bool retry = false}) async {
    // «جارٍ البحث» only when the lookup is slower than 300 ms (hi-fi M-02 scan-loading).
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) showFeedback(ScanFeedback(ScanFeedbackKind.loading, code: code));
    });
    final result = await till.scan(code, retry: retry);
    _loadingTimer?.cancel();
    if (!mounted) return;

    switch (result) {
      case ScanIgnored(:final code) when code.isNotEmpty:
        showFeedback(const ScanFeedback(ScanFeedbackKind.duplicate), flash: true);
      case ScanIgnored():
        break;
      case ScanAdded(:final line):
        unawaited(HapticFeedback.lightImpact());
        final again = line.quantity > Quantity.one;
        markJust(line.product.id);
        showFeedback(
          ScanFeedback(
            again ? ScanFeedbackKind.updated : ScanFeedbackKind.added,
            productName: line.product.name,
            quantity: line.quantity.format(line.product.unit),
          ),
          flash: true,
        );
      case ScanNeedsWeight(:final product):
        showFeedback(null);
        await openWeight(product);
      case ScanOutOfStock(:final product):
        showOutOfStock(product);
      case ScanUnknown(:final code):
        await addUnknown(code);
      case ScanFailed(:final code):
        showFeedback(ScanFeedback(ScanFeedbackKind.networkError, code: code));
    }
  }

  @override
  Future<void> openWeight(Product product) async {
    final existing = ref.read(cartControllerProvider).lineFor(product.id);
    final result = await showWeightSheet(context, product, current: existing?.quantity);
    if (result == null || !mounted) return;
    if (result.remove) {
      till.remove(product.id);
      return;
    }
    if (!applyWeight(product, result.quantity!)) return;
    markJust(product.id);
    if (existing == null) showFeedback(ScanFeedback(ScanFeedbackKind.weighedAdded, productName: product.name), flash: true);
  }

  Future<void> _search({String query = ''}) async {
    showFeedback(null);
    final product = await showProductSearch(context, initialQuery: query);
    if (product == null || !mounted) return;
    await addToTill(product);
  }

  void _checkout() {
    showFeedback(null);
    setState(() => _justId = null);
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()));
  }

  // ---- held carts ----

  String _labelOf(HeldCart held) {
    final t = AppLocalizations.of(context);
    if (held.label.isNotEmpty) return held.label;
    final index = ref.read(heldCartsProvider).indexWhere((h) => h.id == held.id);
    return t.heldUnnamed(index < 0 ? ref.read(heldCartsProvider).length + 1 : index + 1);
  }

  /// «علّق»: the customer's cart goes aside under a name, and the till is free for the next one.
  Future<void> _hold() async {
    final t = AppLocalizations.of(context);
    final label = await _askLabel(title: t.holdTitle, body: t.holdBody, confirm: t.holdConfirm);
    if (label == null || !mounted) return;
    showFeedback(null);
    setState(() => _justId = null);
    final held = ref.read(heldCartsProvider.notifier).hold(label: label);
    showNote(context, t.holdDone(_labelOf(held)));
  }

  /// Takes [held] back. A cart on the till is held first, under a name asked for here.
  Future<void> _resume(HeldCart held) async {
    final t = AppLocalizations.of(context);
    final name = _labelOf(held);
    var labelForCurrent = '';
    if (!ref.read(cartControllerProvider).isEmpty) {
      final label = await _askLabel(title: t.heldSwapTitle, body: t.heldSwapBody(name), confirm: t.heldSwapConfirm);
      if (label == null || !mounted) return;
      labelForCurrent = label;
    }
    showFeedback(null);
    setState(() => _justId = null);
    ref.read(heldCartsProvider.notifier).resume(held, labelForCurrent: labelForCurrent);
    showNote(context, t.heldOpened(name));
    unawaited(_refreshTill(held.cart));
  }

  /// The products of a cart taken back, as the server holds them now: a held cart may wait an
  /// hour while other customers buy the same goods. Offline, the held snapshot stays.
  Future<void> _refreshTill(Cart taken) async {
    final repo = ref.read(productRepositoryProvider);
    final ids = {for (final line in taken.lines) line.product.id};
    final fresh = <int, Product>{};
    Future<void> read(int id) async {
      try {
        fresh[id] = await repo.product(id);
      } on ApiFailure {
        // Offline or gone: this line keeps the snapshot it was held with.
      }
    }

    await Future.wait([for (final id in ids) read(id)]);
    if (!mounted || fresh.isEmpty) return;
    final now = ref.read(cartControllerProvider);
    // The cashier may have changed it meanwhile: only the lines' products are swapped.
    if (now.lines.length != taken.lines.length) return;
    till.replace(now.withProducts(fresh));
  }

  Future<void> _discard(HeldCart held) async {
    final t = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: t.heldDiscardTitle(_labelOf(held)),
      body: t.heldDiscardBody,
      action: t.heldDiscard,
    );
    if (ok && mounted) ref.read(heldCartsProvider.notifier).discard(held);
  }

  /// The name to hold a cart under; empty is fine («زبون 2»). Null when the cashier backed out.
  Future<String?> _askLabel({required String title, required String body, required String confirm}) =>
      showSaleSheet<String>(
        context,
        builder: (_) => _HoldSheet(title: title, body: body, confirm: confirm),
      );

  Future<void> _openTransfers() async {
    await pushScreen<void>(context, const SuspendedInvoicesScreen());
    if (mounted) ref.invalidate(pendingTransfersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartControllerProvider);
    final held = ref.watch(heldCartsProvider);
    final transfers = ref.watch(pendingTransfersProvider).value ?? 0;
    final session = ref.watch(sessionProvider);
    final storeName = session is SignedIn ? session.user.storeName : '';
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final stockChanged = cart.overStockLines.isNotEmpty;

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
            if (held.isNotEmpty || transfers > 0)
              _HeldStrip(
                held: held,
                transfers: transfers,
                labelOf: _labelOf,
                onOpen: _resume,
                onDiscard: _discard,
                onTransfers: _openTransfers,
              ),
            if (_feedback != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: ScanFeedbackCard(
                  feedback: _feedback!,
                  onAction: switch (_feedback!.kind) {
                    ScanFeedbackKind.unknown => () => _search(),
                    ScanFeedbackKind.networkError => () => _handleCode(_feedback!.code, retry: true),
                    ScanFeedbackKind.outOfStock => countOutOfStock,
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
                        if (stockChanged) ...[
                          ToneCard(
                            key: const Key('cart.stockChanged'),
                            tone: StatusTone.warning,
                            icon: Icons.inventory_2_outlined,
                            title: t.heldStockChanged,
                          ),
                          const SizedBox(height: 10),
                        ],
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
                                  onIncrement: () => increment(line),
                                  onDecrement: () =>
                                      till.setQuantity(line.product, line.quantity - Quantity.one, pack: line.pack),
                                  onEditWeight: () => openWeight(line.product),
                                  onRemove: () => till.remove(line.product.id, pack: line.pack),
                                  onAddPack: () => addToTill(line.product, pack: true),
                                  onPrice: (price) => till.setPrice(line.product.id, price, pack: line.pack),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Num(shekel(cart.total), key: const Key('cart.total'), size: 28, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (!cart.isEmpty) ...[
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        key: const Key('cart.hold'),
                        onPressed: _hold,
                        icon: const Icon(Icons.pause_circle_outline_rounded, size: 20),
                        label: Text(t.holdCart),
                        style: OutlinedButton.styleFrom(
                          // The theme's buttons are full width; this one sits beside «الدفع».
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: const BorderSide(color: HisbahColors.primary, width: 1.5),
                          backgroundColor: HisbahColors.surface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 112,
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

/// The carts waiting at the till, one tap from coming back, plus the sales waiting for a transfer.
class _HeldStrip extends StatelessWidget {
  const _HeldStrip({
    required this.held,
    required this.transfers,
    required this.labelOf,
    required this.onOpen,
    required this.onDiscard,
    required this.onTransfers,
  });

  final List<HeldCart> held;
  final int transfers;
  final String Function(HeldCart) labelOf;
  final ValueChanged<HeldCart> onOpen;
  final ValueChanged<HeldCart> onDiscard;
  final VoidCallback onTransfers;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (held.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.pause_circle_outline_rounded, size: 16, color: HisbahColors.inkMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${t.heldTitle} · ${held.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: 64,
            child: ListView(
              key: const Key('cart.held'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final h in held) ...[
                  _HeldChip(held: h, label: labelOf(h), onOpen: () => onOpen(h), onDiscard: () => onDiscard(h)),
                  const SizedBox(width: 8),
                ],
                if (transfers > 0) _TransfersChip(count: transfers, onTap: onTransfers),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeldChip extends StatelessWidget {
  const _HeldChip({required this.held, required this.label, required this.onOpen, required this.onDiscard});

  final HeldCart held;
  final String label;
  final VoidCallback onOpen;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      key: Key('cart.held.${held.id}'),
      color: HisbahColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: HisbahColors.primary, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 2, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: HisbahColors.ink),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Num(shekel(held.cart.total), size: 13, weight: FontWeight.w700, color: HisbahColors.primary),
                        const SizedBox(width: 6),
                        Num(_heldTime.format(held.heldAt), size: 12, weight: FontWeight.w500, color: HisbahColors.inkMuted),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('cart.held.${held.id}.discard'),
                tooltip: t.heldDiscard,
                visualDensity: VisualDensity.compact,
                onPressed: onDiscard,
                icon: const Icon(Icons.close_rounded, size: 18, color: HisbahColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransfersChip extends StatelessWidget {
  const _TransfersChip({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tone = StatusTone.info;
    return Material(
      key: const Key('cart.transfers'),
      color: tone.bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: tone.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_top_rounded, size: 18, color: tone.fg),
              const SizedBox(width: 6),
              Text(t.transfersPending(count), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: tone.fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The hold sheet: what to call this customer (optional), and one button.
class _HoldSheet extends StatefulWidget {
  const _HoldSheet({required this.title, required this.body, required this.confirm});

  final String title;
  final String body;
  final String confirm;

  @override
  State<_HoldSheet> createState() => _HoldSheetState();
}

class _HoldSheetState extends State<_HoldSheet> {
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_label.text.trim());

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return FormSheet(
      header: SheetHeader(title: widget.title, closeLabel: t.cancel),
      action: FilledButton(key: const Key('hold.confirm'), onPressed: _done, child: Text(widget.confirm)),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(widget.body, style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted)),
        ),
        MoreField(
          fieldKey: 'hold.label',
          label: t.holdLabel,
          hint: t.holdLabelHint,
          controller: _label,
          action: TextInputAction.done,
          onSubmitted: _done,
        ),
      ],
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
