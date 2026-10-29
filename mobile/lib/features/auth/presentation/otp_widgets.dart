import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api/api_failure.dart';
import '../../../l10n/app_localizations.dart';

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
