import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/customer_picker_sheet.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/customer.dart';

final _amountPattern = RegExp(r'^\d{1,8}(\.\d{1,2})?$');
final _apiDate = DateFormat('yyyy-MM-dd', 'en');
final _shownDate = DateFormat('dd/MM/yyyy', 'en');

/// Opens [LegacyDebtScreen]; true once a debt was recorded, so the caller refreshes its balances.
Future<bool> openLegacyDebt(BuildContext context, {Customer? customer}) async =>
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(MaterialPageRoute(builder: (_) => LegacyDebtScreen(customer: customer))) ??
    false;

/// «تسجيل دين قديم»: a balance a customer owed before the shop used Hisbah (POST /debts, owner or
/// manager). Only the debt is recorded: no sale, stock movement, payment or cash. If part of it
/// was already paid, the shopkeeper enters what is left. One Idempotency-Key per debt, kept until
/// the server answers, so a retry after a timeout never records it twice.
class LegacyDebtScreen extends ConsumerStatefulWidget {
  const LegacyDebtScreen({super.key, this.customer});

  /// Fixed when opened from a customer's page; chosen in the form when opened from the list.
  final Customer? customer;

  @override
  ConsumerState<LegacyDebtScreen> createState() => _LegacyDebtScreenState();
}

enum _Phase { form, busy, uncertain }

class _LegacyDebtScreenState extends ConsumerState<LegacyDebtScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late Customer? _customer = widget.customer;
  DateTime? _origin;
  DateTime? _due;
  _Phase _phase = _Phase.form;
  bool _touched = false;
  String? _error;
  Money? _recorded;

  String get _operationId => 'legacy-debt-${_customer?.id}';

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Money? get _value {
    final text = _amount.text.trim();
    if (!_amountPattern.hasMatch(text)) return null;
    final money = Money.parse(text);
    return money.isPositive ? money : null;
  }

  String? _amountError(AppLocalizations t) {
    if (!_touched) return null;
    if (_amount.text.trim().isEmpty) return t.legacyAmountInvalid;
    return _value == null ? t.legacyAmountInvalid : null;
  }

  bool get _busy => _phase == _Phase.busy;

  Future<void> _pickCustomer() async {
    final pick = await showCustomerPicker(context, customerRequired: true, canSkip: false, selected: _customer);
    final customer = pick?.customer;
    if (customer == null || !mounted || customer.id == _customer?.id) return;
    setState(() {
      _customer = customer;
      _error = null;
      // Another customer is another debt: a pending retry key belongs to the previous one.
      if (_phase == _Phase.uncertain) _phase = _Phase.form;
    });
  }

  Future<void> _pickDate({required bool due}) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (due ? _due : _origin) ?? today,
      firstDate: DateTime(today.year - 15),
      // The day a debt started is never in the future (the server refuses it); a due date may be.
      lastDate: due ? DateTime(today.year + 5) : today,
    );
    if (picked == null || !mounted) return;
    setState(() => due ? _due = picked : _origin = picked);
  }

  Future<void> _submit(AppLocalizations t) async {
    setState(() => _touched = true);
    final value = _value;
    final customer = _customer;
    if (value == null || customer == null || _busy) return;
    if (_phase != _Phase.uncertain && !await _confirm(t, customer, value)) return;

    final keys = ref.read(idempotencyKeyStoreProvider);
    final key = await keys.keyFor(_operationId);
    setState(() {
      _phase = _Phase.busy;
      _error = null;
    });
    final note = _note.text.trim();
    try {
      final remaining = await ref
          .read(customerRepositoryProvider)
          .recordLegacyDebt(
            customerId: customer.id,
            amount: value,
            idempotencyKey: key,
            originatedOn: _origin == null ? null : _apiDate.format(_origin!),
            dueDate: _due == null ? null : _apiDate.format(_due!),
            note: note.isEmpty ? null : note,
          );
      await keys.complete(_operationId);
      if (mounted) setState(() => _recorded = remaining);
    } on NetworkFailure {
      // The outcome is unknown: keep the key so the retry is the same operation.
      if (mounted) setState(() => _phase = _Phase.uncertain);
    } on ServerError {
      if (mounted) setState(() => _phase = _Phase.uncertain);
    } on ApiFailure catch (failure) {
      await keys.complete(_operationId);
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = switch (failure) {
          ValidationFailed(:final fieldErrors) =>
            (fieldErrors['amount'] ?? fieldErrors['customer_id'] ?? fieldErrors['originated_on'] ?? fieldErrors['note'])
                    ?.firstOrNull ??
                failure.message,
          Forbidden() => t.legacyForbidden,
          _ => failure.message ?? t.serverError,
        };
      });
    }
  }

  Future<bool> _confirm(AppLocalizations t, Customer customer, Money value) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t.legacyConfirmTitle),
          content: Text(t.legacyConfirmBody(customer.name, formatShekel(value.toApi()))),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.legacyBack)),
            FilledButton(
              key: const Key('legacy.confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(t.legacyConfirmOk),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final recorded = _recorded;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(t.legacyTitle)),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: recorded != null ? _done(t, recorded) : _form(t),
          ),
        ),
      ),
    );
  }

  Widget _done(AppLocalizations t, Money recorded) => Padding(
    key: const Key('legacy.done'),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: StatusTone.success.bg, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 40, color: StatusTone.success.fg),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t.legacyDone,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          t.legacyDoneBody(_customer?.name ?? '', formatShekel(recorded.toApi())),
          textAlign: TextAlign.center,
          style: const TextStyle(color: HisbahColors.inkMuted, fontSize: 15),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.legacyDoneButton)),
      ],
    ),
  );

  Widget _form(AppLocalizations t) {
    final customer = _customer;
    final ready = customer != null && _value != null;
    return Column(
      key: const Key('legacy.form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              ToneCard(tone: StatusTone.info, icon: Icons.menu_book_rounded, title: t.legacyIntro),
              const SizedBox(height: 12),
              if (_phase == _Phase.uncertain) ...[
                ToneCard(tone: StatusTone.info, icon: Icons.schedule_rounded, title: t.legacyUncertain, alert: true),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _error!, alert: true),
                const SizedBox(height: 12),
              ],
              GroupLabel(t.legacyCustomer),
              const SizedBox(height: 8),
              LineCard(
                child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    key: const Key('legacy.customer'),
                    enabled: !_busy && widget.customer == null,
                    onTap: _pickCustomer,
                    leading: CircleAvatar(
                      backgroundColor: HisbahColors.primaryTint,
                      child: Icon(
                        customer == null ? Icons.person_search_rounded : Icons.person_rounded,
                        color: HisbahColors.primary,
                      ),
                    ),
                    title: Text(
                      customer?.name ?? t.legacyPickCustomer,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: customer == null && _touched ? StatusTone.error.fg : HisbahColors.ink,
                      ),
                    ),
                    subtitle: customer == null ? null : Text(customer.phoneDisplay),
                    trailing: widget.customer == null
                        ? Text(
                            customer == null ? '' : t.legacyChange,
                            style: const TextStyle(color: HisbahColors.primary, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GroupLabel(t.legacyAmount),
              const SizedBox(height: 8),
              TextField(
                key: const Key('legacy.amount'),
                controller: _amount,
                readOnly: _busy,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => setState(() => _touched = true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [LatinDigitsFormatter()],
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: t.legacyAmountHint,
                  hintTextDirection: Directionality.of(context),
                  hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: HisbahColors.inkMuted),
                  suffixText: '₪',
                  errorText: _amountError(t),
                  fillColor: HisbahColors.raised,
                ),
              ),
              const SizedBox(height: 6),
              Text(t.legacyPartlyPaid, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
              const SizedBox(height: 16),
              LineCard(
                child: Column(
                  children: [
                    _DateRow(
                      key: const Key('legacy.origin'),
                      icon: Icons.event_note_rounded,
                      label: t.legacyOrigin,
                      value: _origin == null ? t.legacyOriginNone : _shownDate.format(_origin!),
                      onTap: _busy ? null : () => _pickDate(due: false),
                      onClear: _origin == null || _busy ? null : () => setState(() => _origin = null),
                      clearLabel: t.legacyClear,
                    ),
                    const Divider(height: 1),
                    _DateRow(
                      key: const Key('legacy.due'),
                      icon: Icons.event_available_rounded,
                      label: t.legacyDue,
                      value: _due == null ? t.legacyDueNone : _shownDate.format(_due!),
                      onTap: _busy ? null : () => _pickDate(due: true),
                      onClear: _due == null || _busy ? null : () => setState(() => _due = null),
                      clearLabel: t.legacyClear,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GroupLabel(t.legacyNote),
              const SizedBox(height: 8),
              TextField(
                key: const Key('legacy.note'),
                controller: _note,
                readOnly: _busy,
                maxLength: 255,
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: t.legacyNoteHint,
                  fillColor: HisbahColors.raised,
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        ActionBar(
          bottomInset: MediaQuery.paddingOf(context).bottom,
          child: FilledButton(
            key: const Key('legacy.save'),
            onPressed: _busy ? null : () => ready ? _submit(t) : setState(() => _touched = true),
            child: _busy
                ? BusyLabel(busy: true, label: t.legacySaving)
                : Text(_phase == _Phase.uncertain ? t.legacyRetry : t.legacySave),
          ),
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    required this.clearLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String clearLabel;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: HisbahSize.touchMin + 8),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
          child: Row(
            children: [
              Icon(icon, color: HisbahColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              LtrValue(
                value,
                style: const TextStyle(fontWeight: FontWeight.w700, color: HisbahColors.inkMuted),
              ),
              if (onClear != null)
                IconButton(onPressed: onClear, tooltip: clearLabel, icon: const Icon(Icons.close_rounded, size: 20))
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The «تسجيل دين قديم» entry on the customers tab: a card, so it reads as an action and not a row.
class LegacyDebtAction extends StatelessWidget {
  const LegacyDebtAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      color: HisbahColors.primaryTint,
      borderRadius: BorderRadius.circular(HisbahRadius.card),
      child: InkWell(
        key: const Key('customers.legacyDebt'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(HisbahRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: HisbahColors.primary,
                  borderRadius: BorderRadius.circular(HisbahRadius.chip),
                ),
                child: const Icon(Icons.history_edu_rounded, color: HisbahColors.onPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.legacyAction,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: HisbahColors.primaryPressed),
                    ),
                    Text(t.legacyActionSub, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: HisbahColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
