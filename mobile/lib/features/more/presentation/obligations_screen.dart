import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/motion/motion.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import 'more_widgets.dart';

const obligationFrequencies = ['daily', 'weekly', 'monthly', 'yearly'];

String frequencyLabel(AppLocalizations t, String frequency) => switch (frequency) {
  'daily' => t.obDaily,
  'weekly' => t.obWeekly,
  'yearly' => t.obYearly,
  _ => t.obMonthly,
};

/// One running cost of the store, as `GET /obligations` sends it.
class Obligation {
  const Obligation({
    required this.id,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.active,
  });

  factory Obligation.fromJson(Map<String, dynamic> json) => Obligation(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    amount: Money.parse('${json['amount'] ?? '0'}'),
    frequency: json['frequency'] as String? ?? 'monthly',
    active: json['active'] as bool? ?? true,
  );

  final int id;
  final String name;
  final Money amount;
  final String frequency;
  final bool active;

  /// Its cost for [day], as the server takes it off that day's profit.
  Money shareOn(DateTime day) {
    final days = switch (frequency) {
      'daily' => 1,
      'weekly' => 7,
      'yearly' => DateTime(day.year, 12, 31).difference(DateTime(day.year)).inDays + 1,
      _ => DateTime(day.year, day.month + 1, 0).day,
    };
    return Money.cents((amount.cents / days).round());
  }
}

/// «الالتزامات» (owner and managers): rent, electricity, salaries… Each day's share comes off the
/// net profit on Home.
class ObligationsScreen extends ConsumerStatefulWidget {
  const ObligationsScreen({super.key});

  @override
  ConsumerState<ObligationsScreen> createState() => _ObligationsScreenState();
}

class _ObligationsScreenState extends ConsumerState<ObligationsScreen> {
  List<Obligation>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final rows = await ref.read(moreRepositoryProvider).obligations();
      if (mounted) setState(() => _items = [for (final row in rows) Obligation.fromJson(row)]);
    } on ApiFailure {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit([Obligation? obligation]) async {
    final t = AppLocalizations.of(context);
    final result = await showSaleSheet<String>(context, builder: (_) => _ObligationSheet(obligation: obligation));
    if (result == null || !mounted) return;
    showNote(context, result == 'deleted' ? t.obDeleted : t.obSaved);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: Text(t.obTitle)),
      body: SafeArea(
        child: FadeSwitcher(
          fill: true,
          child: _failed && items == null
              ? ErrorView(key: const ValueKey('ob.error'), message: t.obLoadError, onRetry: _load)
              : items == null
              ? const LoadingView(key: ValueKey('ob.loading'), rows: 3)
              : items.isEmpty
              ? EmptyView(
                  key: const ValueKey('ob.empty'),
                  icon: Icons.receipt_long_outlined,
                  title: t.obEmptyTitle,
                  body: t.obEmptyBody,
                  actionLabel: t.obAdd,
                  onAction: _edit,
                )
              : _list(t, items),
        ),
      ),
      bottomNavigationBar: items == null || items.isEmpty
          ? null
          : ActionBar(
              bottomInset: MediaQuery.paddingOf(context).bottom,
              child: FilledButton.icon(
                key: const Key('ob.add'),
                onPressed: _edit,
                icon: const Icon(Icons.add_rounded),
                label: Text(t.obAdd),
              ),
            ),
    );
  }

  Widget _list(AppLocalizations t, List<Obligation> items) {
    final today = DateTime.now();
    final daily = items.where((o) => o.active).fold(Money.zero, (sum, o) => sum + o.shareOn(today));

    return RefreshIndicator(
      key: const ValueKey('ob.list'),
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          EntranceFade(
            child: LineCard(
              color: HisbahColors.primaryTint,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.event_repeat_rounded, color: HisbahColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.obDailyTotal, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(t.obIntro, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    LtrValue(
                      formatShekel(daily.toApi()),
                      key: const Key('ob.dailyTotal'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: HisbahColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          EntranceFade(
            delay: const Duration(milliseconds: 60),
            child: LineCard(
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                    _ObligationRow(obligation: items[i], today: today, onTap: () => _edit(items[i])),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObligationRow extends StatelessWidget {
  const _ObligationRow({required this.obligation, required this.today, required this.onTap});

  final Obligation obligation;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final o = obligation;
    final muted = !o.active;

    return InkWell(
      key: Key('ob.row.${o.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: muted ? HisbahColors.inkMuted : null,
                    ),
                  ),
                  Text(
                    o.active ? t.obPerDay(formatShekel(o.shareOn(today).toApi())) : t.obPaused,
                    style: TextStyle(fontSize: 13, color: o.active ? HisbahColors.inkMuted : StatusTone.voided.fg),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LtrValue(
                  formatShekel(o.amount.toApi()),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: muted ? HisbahColors.inkMuted : null,
                  ),
                ),
                Text(
                  frequencyLabel(t, o.frequency),
                  style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkSubtle),
          ],
        ),
      ),
    );
  }
}

final _amountPattern = RegExp(r'^\d{1,8}(\.\d{1,2})?$');

/// Add or edit one obligation. Pops 'saved' or 'deleted'.
class _ObligationSheet extends ConsumerStatefulWidget {
  const _ObligationSheet({this.obligation});

  final Obligation? obligation;

  @override
  ConsumerState<_ObligationSheet> createState() => _ObligationSheetState();
}

class _ObligationSheetState extends ConsumerState<_ObligationSheet> {
  late final _name = TextEditingController(text: widget.obligation?.name ?? '');
  late final _amount = TextEditingController(text: widget.obligation?.amount.toApi() ?? '');
  late String _frequency = widget.obligation?.frequency ?? 'monthly';
  late bool _active = widget.obligation?.active ?? true;
  bool _busy = false;
  bool _tried = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _amountOk {
    final text = _amount.text.trim();
    return _amountPattern.hasMatch(text) && Money.parse(text).isPositive;
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() => _tried = true);
    if (_name.text.trim().isEmpty || !_amountOk) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(moreRepositoryProvider)
          .saveObligation(
            id: widget.obligation?.id,
            name: _name.text.trim(),
            amount: Money.parse(_amount.text.trim()).toApi(),
            frequency: _frequency,
            active: _active,
          );
      if (mounted) Navigator.of(context).pop('saved');
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = switch (failure) {
          ValidationFailed(:final fieldErrors) => fieldErrors.values.expand((e) => e).firstOrNull ?? t.obSaveError,
          _ => failure.message ?? t.obSaveError,
        };
      });
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final o = widget.obligation!;
    final ok = await confirmDanger(context, title: t.obDelete, body: t.obDeleteBody(o.name), action: t.obDeleteAction);
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(moreRepositoryProvider).deleteObligation(o.id);
      if (mounted) Navigator.of(context).pop('deleted');
    } on ApiFailure catch (failure) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failure.message ?? t.obSaveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final editing = widget.obligation != null;

    return FormSheet(
      header: SheetHeader(title: editing ? t.obEdit : t.obAdd, closeLabel: t.cancel),
      action: FilledButton(
        key: const Key('ob.save'),
        onPressed: _busy ? null : _save,
        child: BusyLabel(busy: _busy, label: t.obSave),
      ),
      children: [
        if (_error != null) ...[
          ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _error!, alert: true),
          const SizedBox(height: 12),
        ],
        MoreField(
          fieldKey: 'ob.name',
          label: t.obName,
          hint: t.obNameHint,
          controller: _name,
          required: true,
          enabled: !_busy,
          error: _tried && _name.text.trim().isEmpty ? t.obNameRequired : null,
          onChanged: (_) => setState(() {}),
        ),
        MoreField(
          fieldKey: 'ob.amount',
          label: t.obAmount,
          controller: _amount,
          required: true,
          ltr: true,
          enabled: !_busy,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          error: _tried && !_amountOk ? t.obAmountInvalid : null,
          onChanged: (_) => setState(() {}),
        ),
        GroupLabel(t.obFrequency),
        const SizedBox(height: 8),
        OptionRow(
          children: [
            for (final f in obligationFrequencies)
              OptionButton(
                key: Key('ob.freq.$f'),
                label: frequencyLabel(t, f),
                selected: _frequency == f,
                onTap: _busy ? null : () => setState(() => _frequency = f),
              ),
          ],
        ),
        if (editing) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('ob.active'),
            contentPadding: EdgeInsets.zero,
            title: Text(_active ? t.obActive : t.obPaused),
            value: _active,
            onChanged: _busy ? null : (v) => setState(() => _active = v),
          ),
          TextButton.icon(
            key: const Key('ob.delete'),
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: HisbahColors.dangerSolid),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(t.obDelete),
          ),
        ],
      ],
    );
  }
}
