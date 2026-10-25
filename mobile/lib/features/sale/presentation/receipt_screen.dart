import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';
import '../data/sale_repository.dart';
import 'checkout_screen.dart';
import 'sale_widgets.dart';

/// SCR-M-06 · receipt. The invoice is final (D-06): «بيع جديد» for everyone, «إلغاء الفاتورة…»
/// as a secondary text action for owners and managers only.
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.receipt, this.afterUncertain = false, this.overridden = false});

  final SaleReceipt receipt;

  /// The sale went through on a retry after an uncertain outcome (same key: no duplicate).
  final bool afterUncertain;

  /// An owner / manager confirmed a credit-limit override for this sale.
  final bool overridden;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  late SaleReceipt _receipt = widget.receipt;

  Future<void> _openVoid() async {
    final voided = await showSaleSheet<SaleReceipt>(context, builder: (_) => VoidSheet(receipt: _receipt));
    if (voided != null && mounted) setState(() => _receipt = voided.withWarningsFrom(_receipt));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final user = session is SignedIn ? session.user : null;
    final r = _receipt;
    final voided = r.isVoided;
    final strike = voided ? TextDecoration.lineThrough : TextDecoration.none;

    final (circle, icon, title, sub, amount, tail) = voided
        ? (HisbahColors.voidStamp, Icons.block_rounded, t.receiptVoidedTitle, t.receiptInvoiceWord, '#${r.id}', t.receiptVoidedTail)
        : r.debt.isZero
        ? (StatusTone.paid.fg, Icons.check_rounded, t.receiptDoneTitle, t.receiptPaidWord, shekel(r.total), t.receiptPaidTail)
        : (StatusTone.paid.fg, Icons.check_rounded, t.receiptDoneTitle, t.receiptDebtWord, shekel(r.debt), t.receiptDebtTail(r.customerName ?? ''));

    final notes = <(String, IconData, StatusTone)>[
      if (!voided && r.warnings.isNotEmpty)
        (t.receiptNegativeNote(r.warnings.map((w) => w.name).join('، ')), Icons.warning_amber_rounded, StatusTone.warning),
      if (!voided && widget.overridden)
        (t.receiptOverrideNote(r.customerName ?? '', user?.name ?? ''), Icons.shield_outlined, StatusTone.warning),
      if (!voided && widget.afterUncertain) (t.receiptReplayNote, Icons.info_outline_rounded, StatusTone.info),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(color: circle, shape: BoxShape.circle),
                            child: Icon(icon, size: 26, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, key: const Key('receipt.title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                Text.rich(
                                  TextSpan(
                                    text: '$sub ',
                                    children: [
                                      TextSpan(
                                        text: amount,
                                        style: const TextStyle(color: HisbahColors.ink, fontWeight: FontWeight.w700),
                                      ),
                                      TextSpan(text: ' $tail'),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Paper(receipt: r, user: user, strike: strike),
                    if (voided) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: StatusTone.voided.bg, borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.receiptVoidedBy(r.voidedByName ?? user?.name ?? '', r.voidedAt == null ? '' : _time(r.voidedAt!)),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.6, color: StatusTone.voided.fg),
                            ),
                            BodyText(t.receiptVoidReason(r.voidReason ?? ''), color: StatusTone.voided.fg),
                            BodyText(t.receiptVoidEffect, color: StatusTone.voided.fg),
                          ],
                        ),
                      ),
                    ],
                    for (final (text, icon, tone) in notes) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(padding: const EdgeInsets.only(top: 3), child: Icon(icon, size: 16, color: tone.fg)),
                            const SizedBox(width: 8),
                            Expanded(child: BodyText(text, size: 13)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ActionBar(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      key: const Key('receipt.newSale'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t.newSale),
                    ),
                    if ((user?.canOverride ?? false) && !voided)
                      TextButton(
                        key: const Key('receipt.void'),
                        onPressed: _openVoid,
                        style: TextButton.styleFrom(
                          foregroundColor: HisbahColors.dangerSolid,
                          minimumSize: const Size.fromHeight(44),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        child: Text(t.voidInvoiceEllipsis),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `0599123456` → `059 912 3456` (hi-fi M-06).
String _phone(String p) => p.length == 10 ? '${p.substring(0, 3)} ${p.substring(3, 6)} ${p.substring(6)}' : p;

String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// The printed part: store, invoice facts, lines, totals. Notes about the sale stay outside it.
class _Paper extends StatelessWidget {
  const _Paper({required this.receipt, required this.user, required this.strike});

  final SaleReceipt receipt;
  final AppUser? user;
  final TextDecoration strike;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final r = receipt;
    final voided = r.isVoided;
    const muted = TextStyle(fontSize: 13, color: HisbahColors.inkMuted);
    final created = r.createdAt;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: HisbahColors.raised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HisbahColors.border),
            boxShadow: const [BoxShadow(color: Color(0x0F14262E), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(user?.storeName ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if ((user?.storePhone ?? '').isNotEmpty) Center(child: Num(user!.storePhone!, size: 13, weight: FontWeight.w400, color: HisbahColors.inkMuted)),
              if ((user?.storeAddress ?? '').isNotEmpty) Text(user!.storeAddress!, textAlign: TextAlign.center, style: muted),
              const _Rule(),
              _Fact(label: t.receiptNumber, value: Num('#${r.id}', size: 13, weight: FontWeight.w700)),
              if (created != null) _Fact(label: t.receiptDate, value: Num('${dayMonthYear(created)} · ${_time(created)}', size: 13, weight: FontWeight.w400)),
              _Fact(label: t.receiptSeller, value: Text(r.sellerName ?? user?.name ?? '', style: const TextStyle(fontSize: 13))),
              if (r.customerName != null)
                _Fact(
                  label: t.customerLabel,
                  value: Text.rich(
                    TextSpan(text: r.customerName, children: [if (r.customerPhone != null) TextSpan(text: ' · ${_phone(r.customerPhone!)}')]),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              const _Rule(),
              for (final line in r.lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(line.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(
                              '${line.quantity.format(line.unit)} ${_unitWord(t, line)} × ${shekel(line.unitPrice)}',
                              style: muted,
                            ),
                            if (line.isPack)
                              Text(t.packEquals(line.baseQuantity.format(ProductUnit.piece)), style: muted),
                          ],
                        ),
                      ),
                      Text(
                        shekel(line.lineTotal),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, decoration: strike),
                      ),
                    ],
                  ),
                ),
              const _Rule(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(child: Text(t.totalWord, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  Text(
                    shekel(r.total),
                    key: const Key('receipt.total'),
                    textDirection: TextDirection.ltr,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, decoration: strike),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: Text('${t.paidWord} · ${paymentMethodLabel(t, r.paid.isPositive ? r.paymentMethod : null)}', style: const TextStyle(fontSize: 14))),
                  Text(shekel(r.paid), textDirection: TextDirection.ltr, style: TextStyle(fontSize: 14, decoration: strike)),
                ],
              ),
              if (r.debt.isPositive) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: voided ? StatusTone.voided.bg : StatusTone.debt.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.remainingAsDebt,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: voided ? HisbahColors.voidStamp : StatusTone.debt.fg),
                        ),
                      ),
                      Text(
                        shekel(r.debt),
                        key: const Key('receipt.debt'),
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: strike,
                          color: voided ? HisbahColors.voidStamp : StatusTone.debt.fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (r.debt.isPositive && r.dueDate != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Text(t.dueLabel, style: muted)),
                    Num(isoToDayMonthYear(r.dueDate!), size: 13, weight: FontWeight.w400, color: HisbahColors.inkMuted),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (voided)
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            child: ExcludeSemantics(
              child: Center(
                child: Transform.rotate(
                  angle: -0.21,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xD9FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: HisbahColors.voidStamp, width: 3),
                    ),
                    child: Text(
                      t.voidedStamp,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: HisbahColors.voidStamp),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static String _unitWord(AppLocalizations t, SaleLine line) => line.isPack
      ? t.packWord
      : line.unit == ProductUnit.kg
      ? t.kgShort
      : (line.quantity == Quantity.one ? t.pieceWord : t.piecesWord);
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: LayoutBuilder(
      builder: (_, box) => Row(
        children: [
          for (var i = 0; i < (box.maxWidth / 7).floor(); i++)
            Container(width: 4, height: 1.5, margin: const EdgeInsets.only(right: 3), color: HisbahColors.receiptRule),
        ],
      ),
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
        const SizedBox(width: 12),
        // A long customer name with the phone wraps instead of overflowing.
        Expanded(child: Align(alignment: AlignmentDirectional.centerEnd, child: value)),
      ],
    ),
  );
}

/// US-0503 void: the effect first, a required reason, a red button that names the action.
class VoidSheet extends ConsumerStatefulWidget {
  const VoidSheet({super.key, required this.receipt});

  final SaleReceipt receipt;

  @override
  ConsumerState<VoidSheet> createState() => _VoidSheetState();
}

enum _VoidProblem { blocked, forbidden, network }

class _VoidSheetState extends ConsumerState<VoidSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  bool _reasonMissing = false;
  _VoidProblem? _problem;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _void() async {
    if (_busy) return;
    if (_reason.text.trim().isEmpty) {
      setState(() => _reasonMissing = true);
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final voided = await ref.read(saleRepositoryProvider).voidSale(widget.receipt.id, reason: _reason.text);
      if (mounted) Navigator.of(context).pop(voided);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = switch (failure) {
          Forbidden() => _VoidProblem.forbidden,
          NetworkFailure() || ServerError() || TooManyRequests() => _VoidProblem.network,
          _ => _VoidProblem.blocked,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final r = widget.receipt;
    final problem = switch (_problem) {
      _VoidProblem.blocked => (t.voidBlocked, Icons.block_rounded),
      _VoidProblem.forbidden => (t.voidForbidden, Icons.block_rounded),
      _VoidProblem.network => (t.voidNetwork, Icons.wifi_off_rounded),
      null => null,
    };

    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: t.voidTitle(r.id), closeLabel: t.backWord, onClose: _busy ? null : () => Navigator.of(context).pop()),
            const SizedBox(height: 12),
            LineCard(
              color: HisbahColors.raised,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BodyText(t.voidEffectsTitle, weight: FontWeight.w700),
                    BodyText('• ${t.voidEffectStock}'),
                    if (r.debt.isPositive) BodyText('• ${t.voidEffectDebt(shekel(r.debt), r.customerName ?? '')}'),
                    BodyText('• ${t.voidEffectKept}'),
                    BodyText('• ${t.voidEffectFinal}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(t.voidReasonLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('void.reason'),
              controller: _reason,
              enabled: !_busy,
              minLines: 2,
              maxLines: 3,
              maxLength: 500,
              onChanged: (_) {
                if (_reasonMissing) setState(() => _reasonMissing = false);
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: HisbahColors.raised,
                counterText: '',
                errorText: _reasonMissing ? t.voidReasonRequired : null,
              ),
            ),
            if (problem != null) ...[
              const SizedBox(height: 12),
              ToneCard(key: const Key('void.problem'), tone: StatusTone.error, icon: problem.$2, title: problem.$1, alert: true),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.backWord),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('void.confirm'),
              onPressed: _busy ? null : _void,
              style: FilledButton.styleFrom(backgroundColor: HisbahColors.dangerSolid),
              child: BusyLabel(busy: _busy, label: _busy ? t.voiding : t.voidConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
