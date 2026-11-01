import 'package:flutter/material.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../print/domain/print_document.dart';
import '../../print/presentation/print_sheet.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/returns.dart';

/// An invoice line that can still go back, with what [quantity] of it is worth.
class ReturnableLine {
  const ReturnableLine({required this.id, required this.name, required this.unit, required this.max, required this.value});

  final int id;
  final String name;
  final ProductUnit unit;
  final Quantity max;
  final Money Function(Quantity quantity) value;
}

/// A return, from a customer or to a supplier. Quantities are capped at what can still go back,
/// the split is previewed (the server's answer is final), the reason is required, and the document
/// can be printed as soon as it is saved. Pops true when one was recorded.
class ReturnFormScreen extends StatefulWidget {
  const ReturnFormScreen({
    super.key,
    required this.title,
    required this.lines,
    required this.owed,
    required this.owedLabel,
    required this.refundLabel,
    required this.flagLabel,
    required this.submit,
  });

  final String title;
  final List<ReturnableLine> lines;

  /// What the value lowers first: the sale's debt, or what the store owes the supplier.
  final Money owed;
  final String owedLabel;
  final String refundLabel;
  final String flagLabel;
  final Future<PrintDocument> Function(List<ReturnChoice> lines, String reason) submit;

  @override
  State<ReturnFormScreen> createState() => _ReturnFormScreenState();
}

class _ReturnFormScreenState extends State<ReturnFormScreen> {
  late final _quantities = {for (final line in widget.lines) line.id: TextEditingController()};
  final _flagged = <int>{};
  final _reason = TextEditingController();
  bool _busy = false;
  bool _tried = false;
  String? _error;
  PrintDocument? _saved;

  @override
  void dispose() {
    for (final field in _quantities.values) {
      field.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  Quantity? _typed(ReturnableLine line) {
    final text = _quantities[line.id]!.text.trim();
    if (text.isEmpty) return Quantity.zero;
    try {
      final quantity = Quantity.parse(text);
      return quantity.fits(line.unit) && !quantity.isNegative ? quantity : null;
    } on FormatException {
      return null;
    }
  }

  bool _bad(ReturnableLine line) {
    final quantity = _typed(line);
    return quantity == null || quantity > line.max;
  }

  List<ReturnableLine> get _chosen => [for (final line in widget.lines) if (!_bad(line) && _typed(line)!.isPositive) line];

  Money get _value => _chosen.fold(Money.zero, (sum, line) => sum + line.value(_typed(line)!));

  Future<void> _save(AppLocalizations t) async {
    setState(() {
      _tried = true;
      _error = null;
    });
    if (widget.lines.any(_bad) || _chosen.isEmpty || _reason.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final document = await widget.submit([
        for (final line in _chosen) ReturnChoice(id: line.id, quantity: _typed(line)!, flagged: _flagged.contains(line.id)),
      ], _reason.text.trim());
      if (mounted) setState(() => _saved = document);
    } on ValidationFailed catch (failure) {
      if (mounted) setState(() => _error = failure.fieldErrors.values.expand((e) => e).firstOrNull ?? t.formFailed);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _error = failure is NetworkFailure ? t.formNetwork : failure.message ?? t.formFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _line(AppLocalizations t, ReturnableLine line) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(line.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(t.retAvailable(line.max.format(line.unit)), style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
        const SizedBox(height: 8),
        TextField(
          key: Key('return.quantity.${line.id}'),
          controller: _quantities[line.id],
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: t.retQuantity,
            filled: true,
            fillColor: HisbahColors.raised,
            errorText: _bad(line) ? t.retTooMuch(line.max.format(line.unit)) : null,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          key: Key('return.flag.${line.id}'),
          onTap: _busy
              ? null
              : () => setState(() => _flagged.contains(line.id) ? _flagged.remove(line.id) : _flagged.add(line.id)),
          child: Row(
            children: [
              // The whole row is the target; the box only shows the state.
              IgnorePointer(
                child: Checkbox(
                  value: _flagged.contains(line.id),
                  onChanged: _busy ? null : (_) {},
                ),
              ),
              Expanded(child: Text(widget.flagLabel, style: const TextStyle(fontSize: 14))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sum(String label, Money amount, {bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: strong ? 16 : 14, fontWeight: strong ? FontWeight.w700 : FontWeight.w500))),
        Num(shekel(amount), size: strong ? 17 : 14, weight: strong ? FontWeight.w700 : FontWeight.w600),
      ],
    ),
  );

  Widget _done(AppLocalizations t) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ToneCard(key: const Key('return.done'), tone: StatusTone.success, icon: Icons.check_rounded, title: t.retDoneTitle, alert: true),
        const SizedBox(height: 16),
        PrintButton(document: () => _saved!),
        const SizedBox(height: 10),
        FilledButton(
          key: const Key('return.close'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.retClose),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final value = _value;
    final toOwed = value > widget.owed ? widget.owed : value;
    final reasons = [t.retReasonDamaged, t.retReasonExpired, t.retReasonWrong, t.retReasonDispute];
    final saved = _saved != null;

    return PopScope(
      canPop: !_busy && !saved,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), automaticallyImplyLeading: !saved),
        bottomNavigationBar: saved
            ? null
            : ActionBar(
                bottomInset: MediaQuery.paddingOf(context).bottom,
                child: FilledButton(
                  key: const Key('return.save'),
                  onPressed: _busy ? null : () => _save(t),
                  child: BusyLabel(busy: _busy, label: _busy ? t.formSaving : t.retConfirm),
                ),
              ),
        body: saved
            ? _done(t)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(t.retHelp, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
                  const SizedBox(height: 10),
                  LineCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.lines.length; i++) ...[
                          if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                          _line(t, widget.lines[i]),
                        ],
                      ],
                    ),
                  ),
                  if (_tried && _chosen.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(t.retChooseLine, style: TextStyle(fontSize: 14, color: StatusTone.error.fg)),
                  ],
                  const SizedBox(height: 16),
                  GroupLabel(t.retReason),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final reason in reasons)
                        ActionChip(
                          label: Text(reason),
                          onPressed: _busy ? null : () => setState(() => _reason.text = reason),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('return.reason'),
                    controller: _reason,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 3,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: HisbahColors.raised,
                      counterText: '',
                      errorText: _tried && _reason.text.trim().isEmpty ? t.retReasonRequired : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LineCard(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _sum(t.retValue, value),
                          _sum(widget.owedLabel, toOwed),
                          _sum(widget.refundLabel, value - toOwed, strong: true),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ToneCard(key: const Key('return.error'), tone: StatusTone.error, icon: Icons.block_rounded, title: _error!, alert: true),
                  ],
                ],
              ),
      ),
    );
  }
}
