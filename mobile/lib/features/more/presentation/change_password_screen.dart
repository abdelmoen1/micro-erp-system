import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import 'more_widgets.dart';

/// A new password for the signed-in account. The current one is required; this phone stays signed
/// in and every other device is signed out.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _banner;

  @override
  void dispose() {
    for (final c in [_current, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final errors = {
      if (_current.text.isEmpty) 'current_password': t.pwCurrentRequired,
      if (_password.text.length < 8) 'password': t.pwShort,
      if (_password.text.length >= 8 && _password.text != _confirmation.text) 'password_confirmation': t.pwMismatch,
    };
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(moreRepositoryProvider)
          .changePassword(current: _current.text, password: _password.text, confirmation: _confirmation.text);
      if (!mounted) return;
      showNote(context, t.pwDone);
      Navigator.of(context).pop();
    } on ValidationFailed catch (failure) {
      if (mounted) {
        setState(() {
          _errors = {
            for (final e in failure.fieldErrors.entries)
              if (e.value.isNotEmpty) e.key: e.value.first,
          };
          if (_errors.isEmpty) _banner = failure.message;
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _banner = failure.message ?? t.staffActionError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.pwTitle)),
      body: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (_banner != null) ...[
                    ToneCard(tone: StatusTone.error, icon: Icons.error_outline_rounded, title: _banner!, alert: true),
                    const SizedBox(height: 12),
                  ],
                  MoreField(
                    fieldKey: 'pw.current',
                    label: t.pwCurrent,
                    controller: _current,
                    required: true,
                    obscure: true,
                    ltr: true,
                    error: _errors['current_password'],
                    enabled: !_saving,
                    autofillHints: const [AutofillHints.password],
                  ),
                  MoreField(
                    fieldKey: 'pw.new',
                    label: t.pwNew,
                    controller: _password,
                    required: true,
                    obscure: true,
                    ltr: true,
                    helper: t.pwHelp,
                    error: _errors['password'],
                    enabled: !_saving,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  MoreField(
                    fieldKey: 'pw.confirm',
                    label: t.pwConfirm,
                    controller: _confirmation,
                    required: true,
                    obscure: true,
                    ltr: true,
                    error: _errors['password_confirmation'],
                    enabled: !_saving,
                    action: TextInputAction.done,
                    onSubmitted: _save,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                ],
              ),
            ),
            ActionBar(
              bottomInset: MediaQuery.paddingOf(context).bottom,
              child: FilledButton(
                key: const Key('pw.save'),
                onPressed: _saving ? null : _save,
                child: BusyLabel(busy: _saving, label: t.pwSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
