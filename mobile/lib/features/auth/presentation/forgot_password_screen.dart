import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../more/presentation/more_widgets.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../domain/phone_number.dart';
import 'otp_widgets.dart';

/// A forgotten password: the number, then the SMS code with the new password. Pops `true` when the
/// password changed (every device is signed out on the server).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  /// The number the code went to; null while the number is still being entered.
  String? _sentTo;
  DateTime? _resendAt;
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _banner;

  @override
  void dispose() {
    for (final c in [_phone, _code, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    final phone = normalizePhone(_sentTo ?? _phone.text);
    if (phone == null) {
      setState(() => _errors = {'phone': _phone.text.trim().isEmpty ? t.phoneRequired : t.phoneInvalid});
      return;
    }
    setState(() {
      _busy = true;
      _errors = const {};
      _banner = null;
    });
    try {
      final wait = await ref.read(authRepositoryProvider).sendOtp(phone, 'reset');
      if (!mounted) return;
      setState(() {
        _sentTo = phone;
        _resendAt = DateTime.now().add(Duration(seconds: wait));
      });
    } on ValidationFailed catch (failure) {
      if (mounted) setState(() => _errors = {'phone': failure.fieldErrors['phone']?.firstOrNull ?? t.phoneInvalid});
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _banner = otpSendError(failure, t));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final t = AppLocalizations.of(context);
    final errors = {
      if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) 'otp_code': t.otpCodeInvalid,
      if (_password.text.length < 8) 'password': t.pwShort,
      if (_password.text.length >= 8 && _password.text != _confirmation.text) 'password_confirmation': t.pwMismatch,
    };
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(phone: _sentTo!, code: _code.text.trim(), password: _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationFailed catch (failure) {
      if (mounted) {
        setState(() => _errors = {
          for (final e in failure.fieldErrors.entries)
            if (e.value.isNotEmpty) e.key: e.value.first,
        });
      }
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _banner = failure is NetworkFailure ? t.networkError : failure.message ?? t.serverError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(title: Text(t.resetTitle)),
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
                  if (sentTo == null) ...[
                    BodyText(t.resetHelper, color: HisbahColors.inkMuted),
                    const SizedBox(height: 12),
                    MoreField(
                      fieldKey: 'reset.phone',
                      label: t.loginPhoneLabel,
                      hint: t.phLoginPhone,
                      controller: _phone,
                      required: true,
                      keyboard: TextInputType.phone,
                      ltr: true,
                      error: _errors['phone'],
                      enabled: !_busy,
                      action: TextInputAction.done,
                      onSubmitted: _send,
                      autofillHints: const [AutofillHints.telephoneNumber],
                    ),
                  ] else ...[
                    BodyText(t.otpSentTo(maskPhone(sentTo))),
                    const SizedBox(height: 12),
                    MoreField(
                      fieldKey: 'reset.code',
                      label: t.otpCodeLabel,
                      hint: t.phOtpCode,
                      controller: _code,
                      required: true,
                      keyboard: TextInputType.number,
                      ltr: true,
                      error: _errors['otp_code'],
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.oneTimeCode],
                    ),
                    OtpResendButton(availableAt: _resendAt, onResend: _send, enabled: !_busy),
                    MoreField(
                      fieldKey: 'reset.password',
                      label: t.pwNew,
                      controller: _password,
                      required: true,
                      obscure: true,
                      ltr: true,
                      helper: t.pwHelp,
                      error: _errors['password'],
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    MoreField(
                      fieldKey: 'reset.confirm',
                      label: t.pwConfirm,
                      hint: t.phConfirmPw,
                      controller: _confirmation,
                      required: true,
                      obscure: true,
                      ltr: true,
                      error: _errors['password_confirmation'],
                      enabled: !_busy,
                      action: TextInputAction.done,
                      onSubmitted: _reset,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                  ],
                ],
              ),
            ),
            ActionBar(
              bottomInset: MediaQuery.paddingOf(context).bottom,
              child: FilledButton(
                key: const Key('reset.submit'),
                onPressed: _busy ? null : (sentTo == null ? _send : _reset),
                child: BusyLabel(busy: _busy, label: sentTo == null ? t.otpSend : t.resetSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
