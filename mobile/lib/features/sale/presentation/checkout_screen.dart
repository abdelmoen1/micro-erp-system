import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';
import '../application/cart_controller.dart';
import '../application/checkout_controller.dart';
import '../domain/cart.dart';
import 'customer_picker_sheet.dart';
import 'receipt_screen.dart';
import 'sale_widgets.dart';

/// Payment method labels, in the order of the 2 × 2 grid (05 §3.1).
const paymentMethods = ['cash', 'jawwal_pay', 'palpay', 'bank_of_palestine'];

String paymentMethodLabel(AppLocalizations t, String? method) => switch (method) {
  'cash' => t.methodCash,
  'jawwal_pay' => t.methodJawwalPay,
  'palpay' => t.methodPalPay,
  'bank_of_palestine' => t.methodBankOfPalestine,
  _ => t.methodNone,
};

/// SCR-M-04 · checkout (US-0506): sale mode, paid amount, method, customer, due date, the
/// warnings that let the sale continue and the restrictions that stop it, then one confirm.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _paid = TextEditingController();

  @override
  void dispose() {
    _paid.dispose();
    super.dispose();
  }

  CheckoutController get _controller => ref.read(checkoutControllerProvider.notifier);

  AppUser? get _user {
    final session = ref.read(sessionProvider);
    return session is SignedIn ? session.user : null;
  }

  Future<void> _pickCustomer(CheckoutState state) async {
    final pick = await showCustomerPicker(
      context,
      customerRequired: state.mode != SaleMode.cash,
      canSkip: state.mode == SaleMode.cash,
      selected: state.customer,
    );
    if (pick == null || !mounted) return;
    _controller.setCustomer(pick.customer);
  }

  Future<void> _confirm(Cart cart) async {
    final outcome = await _controller.confirm(cart, _user);
    if (!mounted) return;
    await _handle(outcome, cart);
  }

  Future<void> _handle(CheckoutOutcome outcome, Cart cart) async {
    switch (outcome) {
      case CheckoutNeedsOverride():
        final done = await showSaleSheet<CheckoutDone>(context, builder: (_) => OverrideSheet(cart: cart));
        _controller.dismissOverride();
        if (done != null && mounted) _finish(done);
      case CheckoutDone():
        _finish(outcome);
      case CheckoutStayed():
        break;
    }
  }

  void _finish(CheckoutDone done) {
    unawaited(HapticFeedback.mediumImpact());
    ref.read(cartControllerProvider.notifier).clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReceiptScreen(receipt: done.receipt, afterUncertain: done.afterUncertain, overridden: done.overridden),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cart = ref.watch(cartControllerProvider);
    final state = ref.watch(checkoutControllerProvider);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final s = CheckoutSummary(cart, state, user);
    final locked = state.locked;

    return PopScope(
      canPop: !locked,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                title: t.checkoutTitle,
                subtitle: '${t.linesCount(cart.lines.length)} · ${t.checkoutNotCreatedYet}',
                backLabel: t.backToCart,
                onBack: locked ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _OrderSummary(cart: cart, open: state.itemsOpen, locked: locked, onToggle: _controller.toggleItems),
                    const SizedBox(height: 14),
                    GroupLabel(t.saleModeLabel),
                    const SizedBox(height: 8),
                    OptionRow(
                      children: [
                        for (final (mode, label, icon, color) in [
                          (SaleMode.cash, t.modeCash, Icons.check_circle_outline_rounded, StatusTone.paid.fg),
                          (SaleMode.partial, t.modePartial, Icons.timelapse_rounded, StatusTone.partial.fg),
                          (SaleMode.credit, t.modeCredit, Icons.radio_button_unchecked_rounded, StatusTone.debt.fg),
                        ])
                          OptionButton(
                            key: Key('checkout.mode.${mode.name}'),
                            label: label,
                            icon: icon,
                            iconColor: color,
                            solid: true,
                            height: 48,
                            selected: state.mode == mode,
                            onTap: locked ? null : () => _controller.setMode(mode),
                          ),
                      ],
                    ),
                    if (state.mode == SaleMode.partial) ...[
                      const SizedBox(height: 14),
                      _PaidField(controller: _paid, state: state, total: s.total, onChanged: _controller.setPaid),
                    ],
                    if (s.paid.isPositive) ...[
                      const SizedBox(height: 14),
                      GroupLabel(t.paymentMethodLabel),
                      const SizedBox(height: 8),
                      for (var row = 0; row < 2; row++) ...[
                        if (row > 0) const SizedBox(height: 6),
                        OptionRow(
                          children: [
                            for (final method in paymentMethods.skip(row * 2).take(2))
                              OptionButton(
                                label: paymentMethodLabel(t, method),
                                selected: state.method == method,
                                showCheck: true,
                                onTap: locked ? null : () => _controller.setMethod(method),
                              ),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 14),
                    _CustomerSection(state: state, summary: s, locked: locked, onPick: () => _pickCustomer(state)),
                    if (s.debt.isPositive) ...[
                      const SizedBox(height: 14),
                      _DueSection(state: state, locked: locked, onPick: _controller.setDue),
                    ],
                    ..._warnings(t, s, state),
                    const SizedBox(height: 14),
                    _ConfirmSummary(summary: s, method: state.method),
                  ],
                ),
              ),
              ActionBar(child: _ConfirmBar(summary: s, state: state, onConfirm: () => _confirm(cart))),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _warnings(AppLocalizations t, CheckoutSummary s, CheckoutState state) {
    final cards = <Widget>[];
    final over = s.cart.overStockLines;
    if (over.isNotEmpty) {
      cards.add(
        ToneCard(
          key: const Key('checkout.negative'),
          tone: StatusTone.warning,
          icon: Icons.warning_amber_rounded,
          title: t.negativeStockTitle,
          strongBorder: false,
          children: [
            for (final line in over)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: HisbahColors.stockNote, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(child: Text(line.product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    Text(
                      t.negativeStockRow(
                        line.product.currentStock.format(line.product.unit),
                        line.quantity.format(line.product.unit),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            BodyText(t.negativeStockBody, size: 13),
          ],
        ),
      );
    }
    final customer = s.customer;
    if (s.limitBlocked) {
      cards.add(
        ToneCard(
          key: const Key('checkout.limitBlocked'),
          tone: StatusTone.error,
          icon: Icons.block_rounded,
          title: t.limitBlockedTitle,
          alert: true,
          strongBorder: true,
          children: [
            if (state.submit == SubmitState.limit)
              BodyText(t.limitServerBody(customer?.name ?? ''))
            else if (customer != null && customer.creditLimit != null)
              _AmountGrid(
                rows: [
                  (t.limitBalanceNowOf(customer.name), shekel(customer.balance), false),
                  (t.limitThisSaleDebt, shekel(s.debt), false),
                  (t.limitCeiling, shekel(customer.creditLimit!), false),
                  (t.limitOverBy, shekel(s.overBy), true),
                ],
                strongColor: StatusTone.error.fg,
              ),
            BodyText(t.limitBlockedHelp, size: 13),
          ],
        ),
      );
    } else if (s.limitWarning && customer != null && customer.creditLimit != null) {
      cards.add(
        ToneCard(
          key: const Key('checkout.limitWarning'),
          tone: StatusTone.warning,
          icon: Icons.warning_amber_rounded,
          title: t.limitWarnTitle(customer.name),
          strongBorder: true,
          children: [
            BodyText(t.limitWarnBody(shekel(s.balanceAfter), shekel(customer.creditLimit!), shekel(s.overBy))),
            BodyText(t.limitWarnHelp, size: 13),
          ],
        ),
      );
    }
    final outcome = switch (state.submit) {
      SubmitState.offline => (StatusTone.error, Icons.wifi_off_rounded, t.submitOfflineTitle, t.submitOfflineBody),
      SubmitState.uncertain => (StatusTone.info, Icons.schedule_rounded, t.submitUncertainTitle, t.submitUncertainBody),
      SubmitState.server => (StatusTone.error, Icons.warning_amber_rounded, t.submitServerTitle, t.submitServerBody),
      SubmitState.rejected => (
        StatusTone.error,
        Icons.warning_amber_rounded,
        t.submitRejectedTitle,
        state.serverMessage ?? t.serverError,
      ),
      _ => null,
    };
    if (outcome != null) {
      final (tone, icon, title, body) = outcome;
      cards.add(
        ToneCard(
          key: Key('checkout.submit.${state.submit.name}'),
          tone: tone,
          icon: icon,
          title: title,
          alert: true,
          strongBorder: true,
          children: [
            BodyText(body),
            if (state.submit == SubmitState.server && state.reference != null)
              BodyText(t.serverReference(state.reference!), size: 13, color: HisbahColors.inkMuted),
          ],
        ),
      );
    }
    return [for (final card in cards) ...[const SizedBox(height: 14), card]];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.subtitle, required this.backLabel, required this.onBack});

  final String title;
  final String subtitle;
  final String backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: HisbahColors.border))),
    child: Row(
      children: [
        IconButton(
          tooltip: backLabel,
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: HisbahColors.ink),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart, required this.open, required this.locked, required this.onToggle});

  final Cart cart;
  final bool open;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return LineCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.totalWord, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
                      Num(shekel(cart.total), key: const Key('checkout.total'), size: 32, weight: FontWeight.w700),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                  label: Text(open ? t.hideItems : t.showItems),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (open) ...[
              for (final line in cart.lines)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: HisbahColors.border))),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: line.product.name,
                            children: [
                              TextSpan(
                                text: ' · ${line.quantity.format(line.product.unit)} ${line.product.isWeighed ? t.kgShort : t.pieceWord}',
                                style: const TextStyle(color: HisbahColors.inkMuted),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Num(shekel(line.total)),
                    ],
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: locked ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                  child: Text(t.editCart),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaidField extends StatelessWidget {
  const _PaidField({required this.controller, required this.state, required this.total, required this.onChanged});

  final TextEditingController controller;
  final CheckoutState state;
  final Money total;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final error = switch (state.paidError) {
      PaidError.invalid => t.paidErrorInvalid,
      PaidError.notBelowTotal => t.paidErrorNotBelowTotal,
      null => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.paidNowLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          key: const Key('checkout.paid'),
          controller: controller,
          enabled: !state.locked,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
          decoration: InputDecoration(
            hintText: '0.00',
            filled: true,
            fillColor: error != null ? HisbahColors.raised : null,
            suffixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('₪', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: HisbahColors.inkMuted)),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            enabledBorder: error == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(HisbahRadius.field),
                    borderSide: BorderSide(color: StatusTone.error.fg, width: 2),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        if (error != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.error.fg),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(error, style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: StatusTone.error.fg)),
              ),
            ],
          )
        else
          Text(t.paidHint(shekel(total)), style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
      ],
    );
  }
}

class _CustomerSection extends StatelessWidget {
  const _CustomerSection({required this.state, required this.summary, required this.locked, required this.onPick});

  final CheckoutState state;
  final CheckoutSummary summary;
  final bool locked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cash = state.mode == SaleMode.cash;
    final customer = state.customer;
    final missing = state.customerMissing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupLabel(
          t.customerLabel,
          note: cash ? t.optionalWord : t.requiredWord,
          noteColor: cash ? HisbahColors.inkMuted : StatusTone.debt.fg,
        ),
        const SizedBox(height: 8),
        if (customer != null)
          LineCard(
            radius: 16,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  InitialAvatar(customer.initial),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Num(customer.phoneDisplay, size: 13, weight: FontWeight.w400, color: HisbahColors.inkMuted),
                        Text.rich(
                          TextSpan(
                            text: '${t.balanceWord} ',
                            children: [
                              TextSpan(
                                text: shekel(customer.balance),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: customer.balance.isPositive ? StatusTone.debt.fg : HisbahColors.ink,
                                ),
                              ),
                              TextSpan(
                                text: customer.creditLimit == null
                                    ? ' · ${t.noLimitLong}'
                                    : ' · ${t.limitWord} ${shekel(customer.creditLimit!)}',
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('checkout.changeCustomer'),
                    onPressed: locked ? null : onPick,
                    style: TextButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontWeight: FontWeight.w700)),
                    child: Text(t.changeWord),
                  ),
                ],
              ),
            ),
          )
        else if (!cash)
          Material(
            color: HisbahColors.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: missing
                  ? BorderSide(color: StatusTone.error.fg, width: 2)
                  : const BorderSide(color: HisbahColors.borderStrong, width: 1.5),
            ),
            child: InkWell(
              key: const Key('checkout.pickCustomer'),
              borderRadius: BorderRadius.circular(16),
              onTap: locked ? null : onPick,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 20, color: HisbahColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.pickCustomer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                    const Icon(Icons.chevron_left_rounded, size: 20, color: HisbahColors.inkMuted),
                  ],
                ),
              ),
            ),
          )
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('checkout.addCustomer'),
              onPressed: locked ? null : onPick,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(t.addCustomerToInvoice),
              style: TextButton.styleFrom(minimumSize: const Size(0, 44), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        if (missing) ...[
          const SizedBox(height: 8),
          Row(
            key: const Key('checkout.customerError'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.error.fg),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.mode == SaleMode.credit ? t.customerRequiredCredit : t.customerRequiredPartial,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.5, color: StatusTone.error.fg),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DueSection extends StatelessWidget {
  const _DueSection({required this.state, required this.locked, required this.onPick});

  final CheckoutState state;
  final bool locked;
  final ValueChanged<DueChoice> onPick;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final date = state.due.dateFrom(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: t.dueLabel,
            children: [TextSpan(text: ' ${t.optionalParen}', style: const TextStyle(fontWeight: FontWeight.w400, color: HisbahColors.inkMuted))],
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        OptionRow(
          children: [
            for (final (due, label) in [(DueChoice.none, t.dueNone), (DueChoice.week, t.dueWeek), (DueChoice.month, t.dueMonth)])
              OptionButton(
                label: label,
                fontSize: 13,
                selected: state.due == due,
                onTap: locked ? null : () => onPick(due),
              ),
          ],
        ),
        if (date != null) ...[
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(text: '${t.dueOn} ', children: [TextSpan(text: dayMonthYear(date))]),
            style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted),
          ),
        ],
      ],
    );
  }
}

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({required this.rows, required this.strongColor});

  /// (label, amount, bold).
  final List<(String, String, bool)> rows;
  final Color strongColor;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (label, amount, strong) in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 14, height: 1.6, fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
              ),
              Num(amount, size: 14, weight: strong ? FontWeight.w700 : FontWeight.w400, color: strong ? strongColor : HisbahColors.ink),
            ],
          ),
        ),
    ],
  );
}

class _ConfirmSummary extends StatelessWidget {
  const _ConfirmSummary({required this.summary, required this.method});

  final CheckoutSummary summary;
  final String method;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = summary;
    final (statusLabel, tone, icon) = s.debt.isZero
        ? (t.statusPaidFull, StatusTone.paid, Icons.check_circle_outline_rounded)
        : s.paid.isPositive
        ? (t.statusPartialDebt, StatusTone.partial, Icons.timelapse_rounded)
        : (t.statusFullDebt, StatusTone.debt, Icons.radio_button_unchecked_rounded);
    return LineCard(
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(
          children: [
            _SummaryRow(label: t.totalWord, value: shekel(s.total)),
            const Divider(height: 1, color: HisbahColors.border),
            _SummaryRow(
              label: s.paid.isPositive ? '${t.paidWord} · ${paymentMethodLabel(t, method)}' : t.paidWord,
              value: shekel(s.paid),
            ),
            const Divider(height: 1.5, thickness: 1.5, color: HisbahColors.ink),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.remainingWord, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 13, color: tone.fg),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone.fg)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Num(
                    shekel(s.debt),
                    key: const Key('checkout.debt'),
                    size: 28,
                    weight: FontWeight.w700,
                    color: s.debt.isPositive ? StatusTone.debt.fg : StatusTone.paid.fg,
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
        Num(value, size: 15),
      ],
    ),
  );
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.summary, required this.state, required this.onConfirm});

  final CheckoutSummary summary;
  final CheckoutState state;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final s = summary;
    final customer = state.customer;

    final (note, noteColor) = s.limitBlocked
        ? (t.barLimitBlocked, StatusTone.error.fg)
        : s.debt.isZero
        ? (t.barPaidFull, StatusTone.paid.fg)
        : customer != null
        ? (t.barDebtOn(shekel(s.debt), customer.name), StatusTone.debt.fg)
        : (t.barDebtNoCustomer(shekel(s.debt)), StatusTone.debt.fg);

    var label = t.confirmSale;
    String? amount = shekel(s.total);
    var disabled = state.busy;
    if (state.busy) {
      label = t.savingSale;
      amount = null;
    } else if (s.limitBlocked) {
      disabled = true;
    } else if (state.submit == SubmitState.uncertain) {
      label = t.verifyAndRetry;
      amount = null;
    } else if (s.limitWarning) {
      label = t.continueOverLimit;
      amount = null;
    } else if (state.submit == SubmitState.offline || state.submit == SubmitState.server) {
      label = t.retrySale;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          note,
          key: const Key('checkout.barNote'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: noteColor),
        ),
        const SizedBox(height: 6),
        FilledButton(
          key: const Key('checkout.confirm'),
          onPressed: disabled ? null : onConfirm,
          child: BusyLabel(busy: state.busy, label: label, amount: amount),
        ),
      ],
    );
  }
}

/// D-26 owner / manager override: the amounts, who will be recorded, «رجوع» first and no default
/// focus on the confirm. Pops with the finished sale, or nothing when closed.
class OverrideSheet extends ConsumerWidget {
  const OverrideSheet({super.key, required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(checkoutControllerProvider);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final s = CheckoutSummary(cart, state, user);
    final customer = s.customer;
    final limit = customer?.creditLimit;

    return PopScope(
      canPop: !state.busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: HisbahColors.sheetHandle, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: StatusTone.warning.bg, shape: BoxShape.circle),
                  child: Icon(Icons.warning_amber_rounded, size: 22, color: StatusTone.warning.fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(t.overrideTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LineCard(
              color: HisbahColors.raised,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    _OverrideRow(label: t.customerLabel, value: customer?.name ?? '', isText: true, first: true),
                    _OverrideRow(label: t.overrideBalanceNow, value: shekel(customer?.balance ?? Money.zero)),
                    _OverrideRow(label: t.limitThisSaleDebt, value: shekel(s.debt)),
                    _OverrideRow(label: t.overrideBalanceAfter, value: shekel(s.balanceAfter), bold: true),
                    _OverrideRow(label: t.limitCeiling, value: limit == null ? '' : shekel(limit)),
                    _OverrideRow(label: t.limitOverBy, value: shekel(s.overBy), bold: true, emphasis: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            BodyText(t.overrideNote(user?.name ?? '', _roleLabel(t, user)), color: HisbahColors.inkMuted),
            if (state.submit == SubmitState.forbidden) ...[
              const SizedBox(height: 12),
              ToneCard(
                key: const Key('override.forbidden'),
                tone: StatusTone.error,
                icon: Icons.block_rounded,
                title: t.overrideForbidden,
                alert: true,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('override.back'),
              onPressed: state.busy ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.overrideBack),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('override.confirm'),
              style: FilledButton.styleFrom(backgroundColor: StatusTone.warning.fg),
              onPressed: state.busy || state.submit == SubmitState.forbidden
                  ? null
                  : () async {
                      final outcome = await ref.read(checkoutControllerProvider.notifier).confirmOverride(cart);
                      if (outcome is CheckoutDone && context.mounted) Navigator.of(context).pop(outcome);
                    },
              child: BusyLabel(busy: state.busy, label: state.busy ? t.savingShort : t.overrideConfirm),
            ),
          ],
        ),
      ),
    );
  }

  static String _roleLabel(AppLocalizations t, AppUser? user) => switch (user?.role) {
    UserRole.owner => t.roleOwner,
    UserRole.manager => t.roleManager,
    _ => t.roleEmployee,
  };
}

class _OverrideRow extends StatelessWidget {
  const _OverrideRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.emphasis = false,
    this.isText = false,
    this.first = false,
  });

  final String label;
  final String value;
  final bool bold;
  final bool emphasis;
  final bool isText;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final color = emphasis ? StatusTone.warning.fg : HisbahColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: emphasis
              ? const BorderSide(color: HisbahColors.ink, width: 1.5)
              : (first ? BorderSide.none : const BorderSide(color: HisbahColors.border)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color)),
          ),
          if (isText)
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))
          else
            Num(value, size: 15, weight: bold ? FontWeight.w700 : FontWeight.w400, color: color),
        ],
      ),
    );
  }
}
