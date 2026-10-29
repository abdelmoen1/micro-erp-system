import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/offline/offline_store.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../sync/application/sync_engine.dart';
import '../domain/customer.dart';
import '../domain/ledger.dart';

// PalPay first and selected by default; cash last.
const paymentMethods = ['palpay', 'jawwal_pay', 'bank_of_palestine', 'cash'];

String methodLabel(AppLocalizations t, String method) => switch (method) {
  'jawwal_pay' => t.methodJawwalPay,
  'palpay' => t.methodPalPay,
  'bank_of_palestine' => t.methodBankOfPalestine,
  _ => t.methodCash,
};

final _amountPattern = RegExp(r'^\d{1,8}(\.\d{1,2})?$');

/// SCR-M-09 · record payment: full remaining pre-filled, another amount allowed, a summary before
/// confirm (US-0705 AC2). One Idempotency-Key per payment, kept until the server answers, so a
/// retry after a timeout or a restart never records it twice (AC3).
class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, required this.customer, required this.remaining});

  final Customer customer;
  final Money remaining;

  @override
  ConsumerState<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

enum _Phase { form, busy, uncertain, done }

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  final _amount = TextEditingController();
  late final _fullAmount = TextEditingController(text: widget.remaining.toApi());
  bool _full = true;
  String _method = paymentMethods.first;
  _Phase _phase = _Phase.form;
  String? _error;
  PaymentReceipt? _receipt;

  String get _operationId => 'payment-${widget.customer.id}';

  @override
  void dispose() {
    _amount.dispose();
    _fullAmount.dispose();
    super.dispose();
  }

  Money? get _value {
    if (_full) return widget.remaining;
    final text = _amount.text.trim();
    if (!_amountPattern.hasMatch(text)) return null;
    final money = Money.parse(text);
    return money.isPositive ? money : null;
  }

  String? _fieldError(AppLocalizations t) {
    if (_full || _amount.text.trim().isEmpty) return null;
    final value = _value;
    if (value == null) return t.payInvalid;
    if (value > widget.remaining) return t.payTooMuch(formatShekel(widget.remaining.toApi()));
    return null;
  }

  Future<void> _submit(AppLocalizations t) async {
    final value = _value;
    if (value == null || value > widget.remaining) return;
    final keys = ref.read(idempotencyKeyStoreProvider);
    final key = await keys.keyFor(_operationId);
    // A key already sent once must keep its exact body (a pay-all has no amount).
    final sentBefore = _phase == _Phase.uncertain;
    setState(() {
      _phase = _Phase.busy;
      _error = null;
    });

    // R2 (doc 16 §5): offline, or behind waiting items, the payment joins the queue (FIFO).
    final sync = ref.read(syncEngineProvider.notifier);
    if (await sync.shouldQueue()) return _queue(t, key, value, sendAmount: !_full || !sentBefore);

    try {
      final receipt = await ref
          .read(customerRepositoryProvider)
          .pay(customerId: widget.customer.id, method: _method, idempotencyKey: key, amount: _full ? null : value);
      await keys.complete(_operationId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _phase = _Phase.done;
      });
    } on NetworkFailure catch (failure) {
      if (await sync.canQueue) {
        // Offline, a "pay all" is sent with the amount the customer handed over, unless the
        // request may already have reached the server with its original body.
        return _queue(t, key, value, sendAmount: !_full || !(failure.maybeDelivered || sentBefore));
      }
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
          BusinessRuleViolation(code: 'NOTHING_TO_PAY') => t.payNothing,
          ValidationFailed(:final fieldErrors) => fieldErrors['amount']?.firstOrNull ?? failure.message,
          _ => failure.message ?? t.serverError,
        };
      });
    }
  }

  /// US-1103: the payment is committed on the phone and the customer's balance drops at once.
  Future<void> _queue(AppLocalizations t, String key, Money value, {required bool sendAmount}) async {
    final session = ref.read(sessionProvider);
    try {
      final receipt = await ref.read(customerRepositoryProvider).queuePayment(
        local: ref.read(offlineStoreProvider),
        customer: widget.customer,
        userId: session is SignedIn ? session.user.id : null,
        method: _method,
        idempotencyKey: key,
        amount: value,
        remainingBefore: widget.remaining,
        sendAmount: sendAmount,
      );
      await ref.read(idempotencyKeyStoreProvider).complete(_operationId);
      await ref.read(syncEngineProvider.notifier).enqueued();
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _phase = _Phase.done;
      });
    } on QueueFull {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = t.queueFullBody;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final receipt = _receipt;

    return Scaffold(
      appBar: AppBar(title: Text(t.payTitle(widget.customer.name))),
      body: SafeArea(child: receipt != null ? _done(t, receipt) : _form(t)),
    );
  }

  Widget _done(AppLocalizations t, PaymentReceipt receipt) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: StatusTone.success.bg, shape: BoxShape.circle),
            child: Icon(Icons.check_rounded, size: 40, color: StatusTone.success.fg),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t.payDone(formatShekel(receipt.paid.toApi())),
          key: const Key('payment.done'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          t.payDoneRemaining(widget.customer.name, formatShekel(receipt.remainingAfter.toApi())),
          textAlign: TextAlign.center,
          style: const TextStyle(color: HisbahColors.inkMuted, fontSize: 15),
        ),
        if (receipt.pending) ...[
          const SizedBox(height: 16),
          ToneCard(
            key: const Key('payment.pending'),
            tone: StatusTone.offline,
            icon: Icons.cloud_upload_outlined,
            title: t.payPendingNote(receipt.localRef!),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
          child: Text(t.payDoneButton),
        ),
      ],
    ),
  );

  Widget _form(AppLocalizations t) {
    final value = _value;
    final valid = value != null && value <= widget.remaining;
    final busy = _phase == _Phase.busy;
    final after = valid ? formatShekel((widget.remaining - value).toApi()) : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              if (_phase == _Phase.uncertain) ...[
                ToneCard(tone: StatusTone.info, icon: Icons.schedule_rounded, title: t.payUncertain, alert: true),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _error!, alert: true),
                const SizedBox(height: 12),
              ],
              GroupLabel(t.payAmount),
              const SizedBox(height: 8),
              OptionRow(
                children: [
                  OptionButton(
                    label: t.payFull,
                    selected: _full,
                    onTap: busy ? null : () => setState(() => _full = true),
                  ),
                  OptionButton(
                    label: t.payOther,
                    selected: !_full,
                    onTap: busy ? null : () => setState(() => _full = false),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('payment.amount'),
                controller: _full ? _fullAmount : _amount,
                readOnly: _full || busy,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [LatinDigitsFormatter()],
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: t.phPayAmount,
                  hintTextDirection: Directionality.of(context),
                  hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: HisbahColors.inkMuted),
                  errorText: _fieldError(t),
                  filled: true,
                  fillColor: HisbahColors.raised,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                t.payRemainingNote(formatShekel(widget.remaining.toApi())),
                style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
              ),
              const SizedBox(height: 16),
              GroupLabel(t.payMethod),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in paymentMethods)
                    ChoiceChip(
                      label: Text(methodLabel(t, method)),
                      selected: _method == method,
                      onSelected: busy ? null : (_) => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              LineCard(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      _SumRow(label: t.payNow, value: formatShekel(widget.remaining.toApi())),
                      _SumRow(label: t.payThis, value: valid ? '−${formatShekel(value.toApi())}' : '—'),
                      const Divider(color: HisbahColors.border),
                      _SumRow(label: t.payAfter, value: after, strong: true),
                    ],
                  ),
                ),
              ),
              if (!_full) ...[
                const SizedBox(height: 8),
                Text(t.payOldestFirst, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
              ],
            ],
          ),
        ),
        ActionBar(
          bottomInset: MediaQuery.paddingOf(context).bottom,
          child: FilledButton(
            key: const Key('payment.confirm'),
            onPressed: valid && !busy ? () => _submit(t) : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(HisbahSize.button)),
            child: busy
                ? BusyLabel(busy: true, label: t.paySaving)
                : Text(
                    _phase == _Phase.uncertain ? t.payRetry : t.payConfirm(valid ? formatShekel(value.toApi()) : ''),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
        ),
        LtrValue(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            color: strong ? StatusTone.debt.fg : null,
          ),
        ),
      ],
    ),
  );
}
