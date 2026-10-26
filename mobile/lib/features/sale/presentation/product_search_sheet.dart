import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/domain/product.dart';
import 'sale_widgets.dart';

/// M-02 «بحث بالاسم»: find a product without its barcode (also offered after an unknown barcode).
/// Same pattern as the customer picker (M-05): search field, rows, skeleton, empty and error states.
Future<Product?> showProductSearch(BuildContext context, {String initialQuery = ''}) =>
    showSaleSheet<Product>(context, builder: (_) => ProductSearchSheet(initialQuery: initialQuery));

class ProductSearchSheet extends ConsumerStatefulWidget {
  const ProductSearchSheet({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<ProductSearchSheet> {
  late final _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<Product> _results = const [];
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;

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

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await ref.read(productRepositoryProvider).search(_query.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
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

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(title: t.productSearchTitle, closeLabel: t.cancel),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('productSearch.query'),
                  controller: _query,
                  autofocus: widget.initialQuery.isEmpty,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: t.productSearchHint,
                    prefixIcon: const Icon(Icons.search, color: HisbahColors.inkMuted),
                    filled: true,
                    fillColor: HisbahColors.raised,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (_loading)
                  const _SkeletonRows()
                else if (_failed)
                  _CenteredState(
                    icon: Icons.warning_amber_rounded,
                    iconColor: StatusTone.error.fg,
                    title: t.productSearchError,
                    body: t.listErrorBody,
                    action: OutlinedButton(onPressed: _load, child: Text(t.retry)),
                  )
                else if (_results.isEmpty)
                  _CenteredState(
                    icon: Icons.search,
                    iconColor: HisbahColors.inkMuted,
                    title: t.productSearchEmpty,
                    body: t.productSearchEmptyBody,
                  )
                else
                  LineCard(
                    color: HisbahColors.raised,
                    radius: 16,
                    child: Column(
                      children: [
                        for (final (i, product) in _results.indexed)
                          _ProductRow(product: product, divider: i > 0, onTap: () => Navigator.of(context).pop(product)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.divider, required this.onTap});

  final Product product;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final kg = product.isWeighed;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: divider ? const Border(top: BorderSide(color: HisbahColors.border)) : null),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(product.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      UnitChip(label: kg ? t.unitChipWeighed : t.unitChipPiece),
                    ],
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: shekel(product.price)),
                        TextSpan(text: ' / ${kg ? t.kgShort : t.pieceWord}'),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(t.stockWord, style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
                Num(
                  product.currentStock.format(product.unit),
                  size: 14,
                  weight: FontWeight.w700,
                  color: product.currentStock.isNegative || product.currentStock == Quantity.zero
                      ? StatusTone.error.fg
                      : HisbahColors.ink,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// «قطعة» / «بالوزن» chip beside a product name.
class UnitChip extends StatelessWidget {
  const UnitChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: HisbahColors.ground,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: HisbahColors.unitChipLine),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HisbahColors.inkMuted)),
  );
}

class _SkeletonRows extends StatelessWidget {
  const _SkeletonRows();

  @override
  Widget build(BuildContext context) => LineCard(
    color: HisbahColors.raised,
    radius: 16,
    child: Column(
      children: [
        for (final (i, w) in const [.62, .48, .7, .55].indexed)
          SkeletonRow(widthFactor: w, divider: i > 0),
      ],
    ),
  );
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({required this.icon, required this.iconColor, required this.title, required this.body, this.action});

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => CenteredStateCard(icon: icon, iconColor: iconColor, title: title, body: body, action: action);
}

/// Empty / error card inside a sheet list (hi-fi M-05 «لا نتائج» and «تعذّر التحميل»).
class CenteredStateCard extends StatelessWidget {
  const CenteredStateCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => LineCard(
    color: HisbahColors.raised,
    radius: 16,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
