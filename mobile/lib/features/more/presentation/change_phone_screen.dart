import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/phone_number.dart';
import '../../auth/presentation/otp_widgets.dart';
import '../../sale/presentation/sale_widgets.dart';
import 'more_widgets.dart';

/// The mobile number this account signs in with. Accounts made with an e-mail add theirs here.
/// The current password guards it; with SMS codes on, the new number gets a code first.
class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
  late final _phone = TextEditingController(text: _user?.phone ?? '');
  final _password = TextEditingController();
  final _code = TextEditingController();

  /// With SMS codes on: the number the code went to.
  String? _sentTo;
  DateTime? _resendAt;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _banner;

  AppUser? get _user {
    final session = ref.read(sessionProvider);
    return session is SignedIn ? session.user : null;
  }

  @override
  void dispose() {
    for (final c in [_phone, _password, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final phone = normalizePhone(_phone.text);
    final otp = (await ref.read(authOptionsProvider.future)).otp;
    if (!mounted) return;
    final codeNeeded = otp && _sentTo == phone;
    final errors = {
      if (phone == null) 'phone': _phone.text.trim().isEmpty ? t.phoneRequired : t.phoneInvalid,
      if (_password.text.isEmpty) 'current_password': t.pwCurrentRequired,
      if (codeNeeded && !RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) 'otp_code': t.otpCodeInvalid,
    };
    setState(() {
      _errors = errors;
      _banner = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    final repository = ref.read(authRepositoryProvider);
    try {
      // With codes on, the first press sends the code to the new number; the second saves.
      if (otp && !codeNeeded) {
        final wait = await repository.sendOtp(phone!, 'change_phone');
        if (mounted) {
          setState(() {
            _sentTo = phone;
            _resendAt = DateTime.now().add(Duration(seconds: wait));
          });
        }
        return;
      }
      final user = await repository.changePhone(phone: phone!, currentPassword: _password.text, code: otp ? _code.text.trim() : null);
      ref.read(sessionProvider.notifier).updateUser(user);
      if (!mounted) return;
      showNote(context, t.phoneDone);
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
      if (mounted) setState(() => _banner = otpSendError(failure, t));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sentTo = _sentTo;
    return Scaffold(
      appBar: AppBar(title: Text(t.phoneTitle)),
      body: Column(
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
                BodyText(t.phoneHelper, color: HisbahColors.inkMuted),
                const SizedBox(height: 12),
                MoreField(
                  fieldKey: 'phone.number',
                  label: t.phoneNewLabel,
                  hint: t.phLoginPhone,
                  controller: _phone,
                  required: true,
                  keyboard: TextInputType.phone,
                  ltr: true,
                  error: _errors['phone'],
                  enabled: !_saving,
                  // A changed number needs its own code.
                  onChanged: (_) {
                    if (_sentTo != null) setState(() => _sentTo = null);
                  },
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                MoreField(
                  fieldKey: 'phone.password',
                  label: t.pwCurrent,
                  hint: t.phCurrentPw,
                  controller: _password,
                  required: true,
                  obscure: true,
                  ltr: true,
                  error: _errors['current_password'],
                  enabled: !_saving,
                  autofillHints: const [AutofillHints.password],
                ),
                if (sentTo != null) ...[
                  BodyText(t.otpSentTo(maskPhone(sentTo))),
                  const SizedBox(height: 12),
                  MoreField(
                    fieldKey: 'phone.code',
                    label: t.otpCodeLabel,
                    hint: t.phOtpCode,
                    controller: _code,
                    required: true,
                    keyboard: TextInputType.number,
                    ltr: true,
                    error: _errors['otp_code'],
                    enabled: !_saving,
                    action: TextInputAction.done,
                    onSubmitted: _save,
                    autofillHints: const [AutofillHints.oneTimeCode],
                  ),
                  OtpResendButton(
                    availableAt: _resendAt,
                    enabled: !_saving,
                    onResend: () {
                      setState(() => _sentTo = null);
                      _save();
                    },
                  ),
                ],
              ],
            ),
          ),
          ActionBar(
            bottomInset: MediaQuery.paddingOf(context).bottom,
            child: FilledButton(
              key: const Key('phone.save'),
              onPressed: _saving ? null : _save,
              child: BusyLabel(busy: _saving, label: t.phoneSave),
            ),
          ),
        ],
      ),
    );
  }
}
