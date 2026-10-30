import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'subscription_expired_screen.dart' show externalLinkLauncherProvider;

/// «أرسل رمزاً جديداً», off with a countdown until [availableAt] (the server's `resend_in`).
class OtpResendButton extends StatefulWidget {
  const OtpResendButton({super.key, required this.availableAt, required this.onResend, this.enabled = true});

  final DateTime? availableAt;
  final VoidCallback onResend;
  final bool enabled;

  @override
  State<OtpResendButton> createState() => _OtpResendButtonState();
}

class _OtpResendButtonState extends State<OtpResendButton> {
  Timer? _tick;

  int get _left {
    final at = widget.availableAt;
    if (at == null) return 0;
    final left = at.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left + 1;
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(OtpResendButton old) {
    super.didUpdateWidget(old);
    if (old.availableAt != widget.availableAt) _start();
  }

  void _start() {
    _tick?.cancel();
    if (_left == 0) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_left == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final left = _left;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        key: const Key('otp.resend'),
        onPressed: widget.enabled && left == 0 ? widget.onResend : null,
        child: Text(left == 0 ? t.otpResend : t.otpResendIn(left)),
      ),
    );
  }
}

/// Why a code could not be sent, in the user's words (the server's Arabic message when it has one).
String otpSendError(ApiFailure failure, AppLocalizations t) => switch (failure) {
  NetworkFailure() => t.networkError,
  TooManyRequests(:final message) => message ?? t.tooManyAttempts,
  ServerError(:final message) => message ?? t.otpSendFailed,
  _ => failure.message ?? t.otpSendFailed,
};

/// When the SMS does not arrive: ask the team on WhatsApp, who read the code from the admin page.
class OtpWhatsappHelp extends ConsumerWidget {
  const OtpWhatsappHelp({super.key, required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final number = ref.watch(authOptionsProvider).value?.supportWhatsapp;
    if (number == null) return const SizedBox.shrink();
    return Container(
      key: const Key('otp.whatsapp'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: HisbahColors.raised, borderRadius: BorderRadius.circular(HisbahRadius.card)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.otpNoSmsTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(t.otpNoSmsBody, style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('otp.whatsapp.open'),
            icon: const Icon(Icons.chat_outlined),
            label: Text(t.otpNoSmsAction),
            onPressed: () => ref.read(externalLinkLauncherProvider)(
              Uri.https('wa.me', '/$number', {'text': t.otpWhatsappText(phone)}),
            ),
          ),
        ],
      ),
    );
  }
}
