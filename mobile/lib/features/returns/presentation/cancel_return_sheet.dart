import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';

/// Cancels a return made by mistake: the effects first (stock, debt or balance, any cash to give
/// back), a required reason, and a red button that names the action. [cancel] runs the request;
/// the sheet pops `true` once the server confirmed. Locked while the request runs, so a second tap
/// sends nothing; the repository keeps one Idempotency-Key per return and reason.
///
/// A refusal (the returned goods were sold since, the sale was voided) shows the server's own
/// message, which names the product and what to correct.
class CancelReturnSheet extends ConsumerStatefulWidget {
  const CancelReturnSheet({super.key, required this.invoiceId, required this.effects, required this.cancel});

  final int invoiceId;
  final List<String> effects;
  final Future<void> Function(String reason) cancel;

  @override
  ConsumerState<CancelReturnSheet> createState() => _CancelReturnSheetState();
}

class _CancelReturnSheetState extends ConsumerState<CancelReturnSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  bool _reasonMissing = false;
  String? _problem;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_reason.text.trim().isEmpty) {
      setState(() => _reasonMissing = true);
      return;
    }
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await widget.cancel(_reason.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = switch (failure) {
          Forbidden() => t.cancelForbidden,
          NetworkFailure() || ServerError() || TooManyRequests() => t.cancelNetwork,
          _ => failure.message ?? t.cancelNetwork,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: t.cancelReturnTitle(widget.invoiceId), closeLabel: t.backWord, onClose: _busy ? null : () => Navigator.of(context).pop()),
            const SizedBox(height: 12),
            LineCard(
              color: HisbahColors.raised,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BodyText(t.cancelReturnEffectsTitle, weight: FontWeight.w700),
                    for (final effect in widget.effects) BodyText('• $effect'),
                    BodyText('• ${t.cancelReturnKept}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(t.cancelReasonLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              key: const Key('cancelReturn.reason'),
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
                errorText: _reasonMissing ? t.cancelReasonRequired : null,
              ),
            ),
            if (_problem != null) ...[
              const SizedBox(height: 12),
              ToneCard(key: const Key('cancelReturn.problem'), tone: StatusTone.error, icon: Icons.block_rounded, title: _problem!, alert: true),
            ],
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: Text(t.backWord),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const Key('cancelReturn.confirm'),
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: HisbahColors.dangerSolid),
              child: BusyLabel(busy: _busy, label: _busy ? t.voiding : t.cancelReturnAction),
            ),
          ],
        ),
      ),
    );
  }
}
