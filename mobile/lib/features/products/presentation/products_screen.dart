import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../goods/presentation/goods_flow.dart';
import '../../guide/coach_tour.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../shell/tab_screens.dart';
import '../domain/product.dart';
import 'product_detail_screen.dart';

/// SCR-M-11 · products tab: search, stock badge, low / negative filter (US-0406). Owners and
/// managers add products here, by scanning the product's code or by hand (S3 · QR add).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  String? _stock;
  List<Product> _products = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final inactive = _stock == 'inactive';
      final rows = await ref
          .read(productRepositoryProvider)
          .list(query: _query.text, stock: inactive ? null : _stock, inactive: inactive);
      if (!mounted || generation != _generation) return;
      setState(() {
        _products = rows;
        _loading = false;
      });
    } on ApiFailure {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _add() async {
    final added = await openGoodsFlow(context);
    if (added && mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final canAdd = user?.canOverride ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + MediaQuery.paddingOf(context).bottom),
            children: [
              TabHeader(title: t.tabProducts, storeName: user?.storeName ?? ''),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('products.query'),
                      controller: _query,
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), _load);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: t.prodSearchHint,
                        prefixIcon: const Icon(Icons.search, color: HisbahColors.inkMuted),
                        filled: true,
                        fillColor: HisbahColors.raised,
                      ),
                    ),
                  ),
                  if (canAdd) ...[
                    const SizedBox(width: 8),
                    CoachTarget(
                      id: CoachStep.add,
                      child: OutlinedButton(
                        key: const Key('products.add'),
                        onPressed: _add,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
                        child: Text(t.prodAdd),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final (value, label) in [
                    (null, t.prodFilterAll),
                    ('low', t.prodFilterLow),
                    ('negative', t.prodFilterNegative),
                    // Only the owner or a manager can bring a stopped product back.
                    if (canAdd) ('inactive', t.prodFilterInactive),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _stock == value,
                      onSelected: (_) {
                        setState(() => _stock = value);
                        _load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ..._content(t, canAdd),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations t, bool canAdd) {
    if (_loading && _products.isEmpty) {
      return const [Padding(padding: EdgeInsets.only(top: 4), child: LoadingView(padding: EdgeInsets.zero))];
    }
    if (_failed) return [ErrorView(message: t.prodLoadError, onRetry: _load)];
    if (_products.isEmpty) {
      final filtered = _query.text.trim().isNotEmpty || _stock != null;
      return [
        EmptyView(
          icon: filtered ? Icons.search_off_rounded : Icons.inventory_2_outlined,
          title: filtered ? t.prodNoResults : t.prodEmptyTitle,
          body: filtered ? null : t.prodEmptyBody,
        ),
        if (!filtered && canAdd) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: _add, child: Text(t.addTitle)),
        ],
      ];
    }
    return [
      LineCard(
        child: Column(
          children: [
            const _TableHeader(),
            for (final product in _products) ...[
              const Divider(height: 1, color: HisbahColors.border),
              _ProductRow(
                product: product,
                onTap: () async {
                  if (await openProduct(context, product.id) && mounted) unawaited(_load());
                },
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

/// The table's columns, shared by the header and every row: name, cartons, all pieces, piece price.
const _columns = [5, 4, 3, 3];

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HisbahColors.inkMuted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          for (final (i, label) in [t.prodColName, t.prodColCartons, t.prodColPieces, t.prodColPrice].indexed)
            Expanded(
              flex: _columns[i],
              child: Text(label, style: style, textAlign: i == 0 ? TextAlign.start : TextAlign.end),
            ),
        ],
      ),
    );
  }
}

/// One product: its name, how many cartons that is (with the pieces of an opened one), every piece
/// on hand, and the price of one piece. The pieces take the stock colour (low, out, below zero).
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;

  /// Opens the product: its movements, and for owners and managers a count, an edit.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final stock = product.currentStock;
    final stockColor = stock.isNegative || stock.isZero
        ? StatusTone.error.fg
        : product.isLowStock
        ? StatusTone.warning.fg
        : HisbahColors.ink;
    final cartons = product.cartonsOnHand;
    final weighed = product.unit == ProductUnit.kg;
    const number = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

    return InkWell(
      key: Key('products.row.${product.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: _columns[0],
              child: Text(product.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              flex: _columns[1],
              child: Text(
                cartons == null
                    ? '—'
                    : cartons.$2 == 0
                    ? t.cartonsCell(cartons.$1)
                    : t.cartonsCellLoose(cartons.$1, cartons.$2),
                key: Key('products.cartons.${product.id}'),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 13, color: HisbahColors.ink),
              ),
            ),
            Expanded(
              flex: _columns[2],
              child: Text(
                isolateLtr(weighed ? '${stock.format(product.unit)} ${t.prodPerKg}' : stock.format(product.unit)),
                key: Key('products.pieces.${product.id}'),
                textAlign: TextAlign.end,
                style: number.copyWith(color: stockColor),
              ),
            ),
            Expanded(
              flex: _columns[3],
              child: Text(
                isolateLtr(formatShekel(product.sellingPrice)),
                key: Key('products.price.${product.id}'),
                textAlign: TextAlign.end,
                style: number,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
