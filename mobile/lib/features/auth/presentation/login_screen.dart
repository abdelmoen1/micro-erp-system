import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/hisbah_logo.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session_controller.dart';
import '../domain/phone_number.dart';
import 'forgot_password_screen.dart';

/// SCR-M-01 (US-0205), hi-fi board US-1507 P2: the logo on the ivory ground, the form on a
/// surface rising from the bottom. States follow docs/design/ia.md §4.1.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.sessionExpired = false});

  final bool sessionExpired;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _submitting = false;
  ApiFailure? _failure;
  Map<String, List<String>> _serverFieldErrors = const {};
  int _waitSeconds = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _login.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _throttled => _waitSeconds > 0;

  Future<void> _submit() async {
    if (_submitting || _throttled) return;
    setState(() => _serverFieldErrors = const {});
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      final login = normalizePhone(_login.text) ?? _login.text;
      await ref.read(sessionProvider.notifier).login(login, _password.text);
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _failure = failure;
        if (failure is InvalidCredentials) _password.clear();
        if (failure is ValidationFailed) _serverFieldErrors = failure.fieldErrors;
        if (failure is TooManyRequests) _startCountdown(failure.retryAfter.inSeconds);
      });
      _formKey.currentState!.validate();
      if (failure is InvalidCredentials) _passwordFocus.requestFocus();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _waitSeconds = seconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _waitSeconds--;
        if (_waitSeconds <= 0) {
          timer.cancel();
          _failure = null;
        }
      });
    });
  }

  String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  /// Client-side validation in Arabic; known server field errors use the same Arabic text (DEF-19).
  String? _validateLogin(String? value, AppLocalizations t) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return t.phoneRequired;
    if (normalizePhone(v) == null || _serverFieldErrors.containsKey('login')) return t.phoneInvalid;
    return null;
  }

  Future<void> _forgot() async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
    if (done == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).resetDone)));
    }
  }

  String? _validatePassword(String? value, AppLocalizations t) {
    if ((value ?? '').isEmpty || _serverFieldErrors.containsKey('password')) return t.passwordRequired;
    return null;
  }

  Widget? _banner(AppLocalizations t, SessionState session) {
    if (_throttled) {
      return MessageBanner(
        icon: Icons.schedule,
        tone: StatusTone.pending,
        text: t.tooManyAttempts,
        trailing: _clock(_waitSeconds),
      );
    }
    final blocked = session is AccountBlocked ? session : null;
    return switch (_failure) {
      InvalidCredentials() => MessageBanner(icon: Icons.warning_amber_rounded, text: t.invalidCredentials),
      NetworkFailure() => MessageBanner(icon: Icons.warning_amber_rounded, text: t.networkError),
      UserInactive() => MessageBanner(icon: Icons.block, tone: StatusTone.voided, text: t.accountInactive),
      StoreRequired() => MessageBanner(icon: Icons.block, tone: StatusTone.voided, text: t.storeRequired),
      StoreSuspended() => MessageBanner(icon: Icons.block, tone: StatusTone.voided, text: t.storeSuspended),
      // Shown under the fields instead.
      ValidationFailed() => null,
      final ApiFailure other => MessageBanner(
        icon: Icons.warning_amber_rounded,
        text: t.serverError,
        detail: other.reference == null ? null : t.serverReference(other.reference!),
      ),
      null when blocked != null => MessageBanner(
        icon: Icons.block,
        tone: StatusTone.voided,
        text: blocked.storeSuspended
            ? t.storeSuspended
            : blocked.storeMissing
            ? t.storeRequired
            : t.accountInactive,
      ),
      null when widget.sessionExpired => MessageBanner(
        icon: Icons.info_outline,
        tone: StatusTone.info,
        text: t.sessionExpired,
      ),
      null => null,
    };
  }

  String _buttonLabel(AppLocalizations t) {
    if (_submitting) return t.loginSubmitting;
    if (_throttled) return t.loginButtonWait(_clock(_waitSeconds));
    if (_failure is NetworkFailure || _failure is ServerError) return t.retry;
    return t.loginButton;
  }

  Widget _errorLine(String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.warning_amber_rounded, size: 16, color: StatusTone.error.fg),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: StatusTone.error.fg, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final banner = _banner(t, session);
    final otp = ref.watch(authOptionsProvider).value?.otp ?? false;
    final scaled = MediaQuery.textScalerOf(context).scale(16) > 18;
    final label = theme.textTheme.labelMedium;

    // Reversed brand: the ivory mark on deep teal; the form keeps its ivory panel for legibility.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HisbahColors.primary,
        body: SafeArea(
          bottom: false,
          // At least one screen tall: the logo is centred above the panel, the panel sits at the
          // bottom (thumb zone). Taller content (130 % text, banners, keyboard) scrolls instead of clipping.
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox.shrink(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: HisbahLogo(markSize: scaled ? 76 : 104, color: HisbahColors.surface),
                      ),
                    ),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: HisbahColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(HisbahRadius.sheet)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + MediaQuery.paddingOf(context).bottom),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(t.loginTitle, style: theme.textTheme.headlineMedium),
                              Text(t.loginHelper, style: const TextStyle(fontSize: 16, color: HisbahColors.inkMuted)),
                              const SizedBox(height: 16),
                              if (banner != null) ...[banner, const SizedBox(height: 16)],
                              Text(t.loginPhoneLabel, style: label),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('login.id'),
                                controller: _login,
                                enabled: !_submitting,
                                keyboardType: TextInputType.phone,
                                // A number typed on an Arabic keyboard (٠٥٩…) is read as 059….
                                inputFormatters: const [LatinDigitsFormatter()],
                                autocorrect: false,
                                textDirection: TextDirection.ltr,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber],
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: t.phLoginPhone,
                                  hintTextDirection: Directionality.of(context),
                                ),
                                validator: (v) => _validateLogin(v, t),
                                errorBuilder: (_, error) => _errorLine(error),
                                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                              ),
                              const SizedBox(height: 16),
                              Text(t.passwordLabel, style: label),
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('login.password'),
                                controller: _password,
                                focusNode: _passwordFocus,
                                enabled: !_submitting,
                                obscureText: _obscure,
                                textDirection: TextDirection.ltr,
                                textInputAction: TextInputAction.go,
                                autofillHints: const [AutofillHints.password],
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: t.phLoginPw,
                                  hintTextDirection: Directionality.of(context),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsetsDirectional.only(end: 4),
                                    child: Semantics(
                                      button: true,
                                      toggled: !_obscure,
                                      label: _obscure ? t.showPasswordA11y : t.hidePasswordA11y,
                                      excludeSemantics: true,
                                      child: TextButton.icon(
                                        key: const Key('login.togglePassword'),
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(84, 48),
                                          foregroundColor: HisbahColors.primary,
                                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                        ),
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          size: 20,
                                        ),
                                        label: Text(_obscure ? t.showPassword : t.hidePassword),
                                      ),
                                    ),
                                  ),
                                ),
                                validator: (v) => _validatePassword(v, t),
                                errorBuilder: (_, error) => _errorLine(error),
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (otp)
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton(
                                    key: const Key('login.forgot'),
                                    onPressed: _submitting ? null : _forgot,
                                    child: Text(t.loginForgot),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              FilledButton(
                                key: const Key('login.submit'),
                                onPressed: _submitting || _throttled ? null : _submit,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_submitting) ...[
                                      const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: HisbahColors.disabledInk,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                    ],
                                    Flexible(child: Text(_buttonLabel(t), textAlign: TextAlign.center)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Wraps onto two lines on narrow phones and large text.
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(t.loginNoAccount, style: const TextStyle(color: HisbahColors.inkMuted)),
                                  TextButton(
                                    key: const Key('login.register'),
                                    onPressed: _submitting ? null : () => context.go(Routes.register),
                                    child: Text(t.loginCreateStore),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
