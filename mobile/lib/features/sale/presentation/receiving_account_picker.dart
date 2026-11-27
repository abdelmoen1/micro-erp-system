import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../more/presentation/more_widgets.dart' show FormSheet, MoreField, pushScreen;
import '../../more/presentation/receiving_accounts_screen.dart';
import 'sale_widgets.dart';

/// The account a transfer sale waits on, picked like a customer: the provider's accounts, and a
/// new one added right here (owners and managers). Returns the chosen account, or null.
Future<Map<String, dynamic>?> showReceivingAccountPicker(
  BuildContext context, {
  required String provider,
  required String providerLabel,
  int? selectedId,
}) => showSaleSheet<Map<String, dynamic>>(
  context,
  builder: (_) => _ReceivingAccountSheet(provider: provider, providerLabel: providerLabel, selectedId: selectedId),
);

class _ReceivingAccountSheet extends ConsumerStatefulWidget {
  const _ReceivingAccountSheet({required this.provider, required this.providerLabel, this.selectedId});

  final String provider;
  final String providerLabel;
  final int? selectedId;

  @override
  ConsumerState<_ReceivingAccountSheet> createState() => _ReceivingAccountSheetState();
}

class _ReceivingAccountSheetState extends ConsumerState<_ReceivingAccountSheet> {
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  List<Map<String, dynamic>>? _accounts;
  bool _failed = false;
  bool _adding = false;
  bool _saving = false;
  String? _error;

  bool get _canManage {
    final session = ref.read(sessionProvider);
    return session is SignedIn && session.user.canOverride;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final accounts = await ref.read(saleRepositoryProvider).receivingAccounts(widget.provider);
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        // No account yet: the add form is what the owner came for.
        _adding = accounts.isEmpty && _canManage;
      });
    } on ApiFailure {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save(AppLocalizations t) async {
    final name = _name.text.trim();
    final identifier = _identifier.text.trim();
    if (name.isEmpty || identifier.isEmpty) {
      setState(() => _error = t.rxRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final account = await ref
          .read(moreRepositoryProvider)
          .saveReceivingAccount(provider: widget.provider, name: name, identifier: identifier, active: true);
      if (mounted) Navigator.of(context).pop(account);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = switch (failure) {
          ValidationFailed(:final fieldErrors) => fieldErrors.values.expand((e) => e).firstOrNull ?? failure.message,
          NetworkFailure() => t.rxSaveError,
          _ => failure.message ?? t.rxSaveError,
        };
      });
    }
  }

  Future<void> _manage() async {
    await pushScreen<void>(context, const ReceivingAccountsScreen());
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final accounts = _accounts;
    final manage = _canManage;

    return FormSheet(
      header: SheetHeader(
        title: t.rxTitle(widget.providerLabel),
        subtitle: Text(t.rxPick, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
        closeLabel: t.cancel,
        onClose: _saving ? null : () => Navigator.of(context).pop(),
      ),
      action: _adding
          ? FilledButton(
              key: const Key('rx.save'),
              onPressed: _saving ? null : () => _save(t),
              child: BusyLabel(busy: _saving, label: t.rxSave),
            )
          : null,
      children: [
        if (_failed)
          ToneCard(
            tone: StatusTone.error,
            icon: Icons.wifi_off_rounded,
            title: t.rxLoadError,
            alert: true,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(onPressed: _load, child: Text(t.retry)),
              ),
            ],
          )
        else if (accounts == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else ...[
          if (accounts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                manage ? t.rxEmpty(widget.providerLabel) : t.rxEmptyEmployee(widget.providerLabel),
                style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted),
              ),
            ),
          if (accounts.isNotEmpty)
            LineCard(
              child: Column(
                children: [
                  for (final (i, account) in accounts.indexed) ...[
                    if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                    _AccountRow(
                      account: account,
                      selected: (account['id'] as num?)?.toInt() == widget.selectedId,
                      onTap: _saving ? null : () => Navigator.of(context).pop(account),
                    ),
                  ],
                ],
              ),
            ),
          if (manage && !_adding)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('rx.add'),
                  onPressed: () => setState(() => _adding = true),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(t.rxAdd),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          if (manage && _adding) ...[
            const SizedBox(height: 14),
            GroupLabel(t.rxAdd),
            const SizedBox(height: 8),
            MoreField(
              fieldKey: 'rx.name',
              label: t.rxName,
              hint: t.rxNameHint,
              controller: _name,
              required: true,
              enabled: !_saving,
            ),
            MoreField(
              fieldKey: 'rx.identifier',
              label: t.rxIdentifier,
              hint: t.rxIdentifierHint,
              controller: _identifier,
              required: true,
              ltr: true,
              keyboard: TextInputType.phone,
              enabled: !_saving,
              action: TextInputAction.done,
              onSubmitted: () => _save(t),
            ),
            if (_error != null)
              ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _error!, alert: true),
          ],
          if (manage && accounts.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('rx.manage'),
                onPressed: _saving ? null : _manage,
                style: TextButton.styleFrom(foregroundColor: HisbahColors.inkMuted),
                child: Text(t.rxManage),
              ),
            ),
        ],
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.selected, required this.onTap});

  final Map<String, dynamic> account;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('rx.account.${account['id']}'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: HisbahColors.primaryTint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_wallet_outlined, color: HisbahColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account['account_name'] as String? ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Num(
                  account['account_identifier'] as String? ?? '',
                  size: 13,
                  weight: FontWeight.w400,
                  color: HisbahColors.inkMuted,
                ),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle_rounded, color: HisbahColors.primary),
        ],
      ),
    ),
  );
}
