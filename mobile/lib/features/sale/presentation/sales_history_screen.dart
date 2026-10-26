import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/sale_repository.dart';
import 'sale_detail_screen.dart';
import 'sale_widgets.dart';

enum SalesPeriod { today, week, month, all }

final _day = DateFormat('yyyy-MM-dd', 'en');
final _when = DateFormat('dd/MM · HH:mm', 'en');

/// Every sale of the store, newest first, by period; a tap opens the invoice in full.
class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  SalesPeriod _period = SalesPeriod.today;
  final List<SaleReceipt> _sales = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _failed = false;

  /// Bumped on each new period or refresh, so a late answer for an old filter is dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  (String?, String?) _range() {
    final today = DateTime.now();
    String day(int back) => _day.format(today.subtract(Duration(days: back)));
    return switch (_period) {
      SalesPeriod.today => (day(0), day(0)),
      SalesPeriod.week => (day(6), day(0)),
      SalesPeriod.month => (day(29), day(0)),
      SalesPeriod.all => (null, null),
    };
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _sales.clear();
      _page = 0;
      _hasMore = false;
    });
    await _more();
  }

  Future<void> _more() async {
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final (from, to) = _range();
    try {
      final page = await ref.read(saleRepositoryProvider).history(from: from, to: to, page: _page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _page++;
        // A sale made meanwhile shifts the pages by one: never show an invoice twice.
        final known = {for (final s in _sales) s.id};
        _sales.addAll(page.sales.where((s) => !known.contains(s.id)));
        _hasMore = page.hasMore;
      });
    } on ApiFailure {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _open(SaleReceipt sale) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id)));
    // A void from the invoice changes its row.
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final periods = [
      (SalesPeriod.today, t.salesToday),
      (SalesPeriod.week, t.sales7),
      (SalesPeriod.month, t.sales30),
      (SalesPeriod.all, t.salesAll),
    ];

    Widget body;
    if (_sales.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_sales.isEmpty && _failed) {
      body = ErrorView(message: t.salesLoadError, onRetry: _reload);
    } else if (_sales.isEmpty) {
      body = EmptyView(icon: Icons.receipt_long_outlined, title: t.salesEmpty);
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            LineCard(
              child: Column(
                children: [
                  for (var i = 0; i < _sales.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                    SaleRow(sale: _sales[i], onTap: () => _open(_sales[i])),
                  ],
                ],
              ),
            ),
            if (_hasMore || _failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  key: const Key('sales.more'),
                  onPressed: _loading ? null : _more,
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: BusyLabel(busy: _loading, label: _failed ? t.salesMoreError : t.salesMore),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.salesTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: OptionRow(
              gap: 4,
              children: [
                for (final (period, label) in periods)
                  OptionButton(
                    key: Key('sales.period.${period.name}'),
                    label: label,
                    fontSize: 13,
                    selected: _period == period,
                    onTap: () {
                      if (_period == period) return;
                      setState(() => _period = period);
                      _reload();
                    },
                  ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// One sale in a list: number, time, customer, how many items, total and how it was paid.
class SaleRow extends StatelessWidget {
  const SaleRow({super.key, required this.sale, required this.onTap});

  final SaleReceipt sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = sale;
    final at = s.createdAt;
    final (status, tone) = s.isVoided
        ? (t.voidedStamp, StatusTone.voided)
        : !s.debt.isPositive
        ? (t.saleStatusPaid, StatusTone.paid)
        : s.paid.isPositive
        ? (t.saleStatusPartial, StatusTone.pending)
        : (t.saleStatusCredit, StatusTone.debt);

    return InkWell(
      key: Key('sales.row.${s.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.custDebtSale(s.id)} · ${s.customerName ?? t.salesWalkIn}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (at != null) LtrValue(_when.format(at), style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
                      Text(t.salesItems(s.lines.length), style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  s.total.toApi(),
                  style: TextStyle(fontWeight: FontWeight.w700, decoration: s.isVoided ? TextDecoration.lineThrough : null),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
                  child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone.fg)),
                ),
              ],
            ),
            const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted),
          ],
        ),
      ),
    );
  }
}
