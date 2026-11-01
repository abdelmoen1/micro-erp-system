import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/returns.dart';

enum ListPeriod { today, week, month, all }

final _day = DateFormat('yyyy-MM-dd', 'en');

/// The store days a period covers, as the API reads them; null for no limit.
(String?, String?) periodDays(ListPeriod period) {
  final today = DateTime.now();
  String day(int back) => _day.format(today.subtract(Duration(days: back)));
  return switch (period) {
    ListPeriod.today => (day(0), day(0)),
    ListPeriod.week => (day(6), day(0)),
    ListPeriod.month => (day(29), day(0)),
    ListPeriod.all => (null, null),
  };
}

/// The four period buttons above every register.
class PeriodButtons extends StatelessWidget {
  const PeriodButtons({super.key, required this.selected, required this.onPick});

  final ListPeriod selected;
  final ValueChanged<ListPeriod> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OptionRow(
      gap: 4,
      children: [
        for (final (period, label) in [
          (ListPeriod.today, t.salesToday),
          (ListPeriod.week, t.sales7),
          (ListPeriod.month, t.sales30),
          (ListPeriod.all, t.salesAll),
        ])
          OptionButton(
            key: Key('period.${period.name}'),
            label: label,
            fontSize: 13,
            selected: selected == period,
            onTap: () => onPick(period),
          ),
      ],
    );
  }
}

/// A register by period, loaded a page at a time: purchases and both kinds of returns.
class PeriodList<T> extends StatefulWidget {
  const PeriodList({
    super.key,
    required this.load,
    required this.row,
    required this.emptyIcon,
    required this.emptyTitle,
    this.initial = ListPeriod.today,
  });

  final Future<RegisterPage<T>> Function(String? from, String? to, int page) load;
  final Widget Function(T row, Future<void> Function() reload) row;
  final IconData emptyIcon;
  final String emptyTitle;
  final ListPeriod initial;

  @override
  State<PeriodList<T>> createState() => _PeriodListState<T>();
}

class _PeriodListState<T> extends State<PeriodList<T>> {
  late ListPeriod _period = widget.initial;
  final List<T> _rows = [];
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

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _rows.clear();
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
    final (from, to) = periodDays(_period);
    try {
      final page = await widget.load(from, to, _page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _page++;
        _rows.addAll(page.rows);
        _hasMore = page.hasMore;
      });
    } on ApiFailure {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    Widget body;
    if (_rows.isEmpty && _loading) {
      body = const LoadingView();
    } else if (_rows.isEmpty && _failed) {
      body = ErrorView(message: t.listLoadError, onRetry: _reload);
    } else if (_rows.isEmpty) {
      body = EmptyView(icon: widget.emptyIcon, title: widget.emptyTitle);
    } else {
      body = RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            LineCard(
              child: Column(
                children: [
                  for (var i = 0; i < _rows.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                    widget.row(_rows[i], _reload),
                  ],
                ],
              ),
            ),
            if (_hasMore || _failed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  key: const Key('register.more'),
                  onPressed: _loading ? null : _more,
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  child: BusyLabel(busy: _loading, label: _failed ? t.salesMoreError : t.salesMore),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: PeriodButtons(
            selected: _period,
            onPick: (period) {
              if (_period == period) return;
              setState(() => _period = period);
              _reload();
            },
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}
