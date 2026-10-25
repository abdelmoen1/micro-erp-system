import 'dart:async';
import 'dart:math' as math;

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
import '../domain/registration_form.dart';

/// Store-owner registration: the web /join form's three steps, fields, rules and request
/// (POST /register). On success the server starts the store's free trial and the owner is signed in;
/// the router then lands on the owner's home.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

enum _Outcome { taken, validation, network, server }

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static final _takenPattern = RegExp('taken|مستخدم|مسجّل', caseSensitive: false);

  final _draft = RegistrationDraft();
  final _controllers = {
    for (final f in RegistrationField.values)
      if (f != RegistrationField.city) f: TextEditingController(),
  };

  /// After a refused step, focus moves to the first field that needs fixing.
  final _focus = {for (final f in RegistrationField.values) f: FocusNode()};

  int _step = 0;
  bool _submitting = false;
  bool _obscure = true;
  Map<RegistrationField, String> _errors = const {};
  _Outcome? _outcome;
  String? _reference;
  int _waitSeconds = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _throttled => _waitSeconds > 0;

  void _syncDraft() {
    _draft
      ..storeName = _controllers[RegistrationField.storeName]!.text
      ..ownerName = _controllers[RegistrationField.ownerName]!.text
      ..phone = _controllers[RegistrationField.phone]!.text
      ..street = _controllers[RegistrationField.street]!.text
      ..email = _controllers[RegistrationField.email]!.text
      ..password = _controllers[RegistrationField.password]!.text
      ..passwordConfirmation = _controllers[RegistrationField.passwordConfirmation]!.text;
  }

  String _message(RegistrationError e, AppLocalizations t) => switch (e) {
    RegistrationError.storeNameRequired => t.storeNameRequired,
    RegistrationError.ownerNameRequired => t.ownerNameRequired,
    RegistrationError.phoneRequired => t.phoneRequired,
    RegistrationError.phoneInvalid => t.phoneInvalid,
    RegistrationError.cityRequired => t.cityRequired,
    RegistrationError.streetRequired => t.streetRequired,
    RegistrationError.emailRequired => t.registerEmailRequired,
    RegistrationError.emailInvalid => t.registerEmailInvalid,
    RegistrationError.passwordTooShort => t.passwordTooShort,
    RegistrationError.passwordMismatch => t.passwordMismatch,
  };

  Future<void> _next(AppLocalizations t) async {
    if (_submitting || _throttled) return;
    _syncDraft();
    final errors = _draft.validateStep(_step);
    setState(() {
      _errors = errors.map((field, e) => MapEntry(field, _message(e, t)));
      _outcome = null;
    });
    if (errors.isNotEmpty) {
      _focusFirstError();
      return;
    }
    if (_step < registrationSteps.length - 1) {
      setState(() => _step++);
      // The next step's first field is ready for typing.
      WidgetsBinding.instance.addPostFrameCallback((_) => _focus[registrationSteps[_step].first]?.requestFocus());
      return;
    }
    await _submit(t);
  }

  /// Focus the first field (in the step's order) that has an error; it also scrolls it into view.
  void _focusFirstError() {
    final first = registrationSteps[_step].where(_errors.containsKey).firstOrNull;
    if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => _focus[first]?.requestFocus());
  }

  Future<void> _submit(AppLocalizations t) async {
    setState(() => _submitting = true);
    try {
      await ref.read(sessionProvider.notifier).register(_draft.toRequest());
      // Signed in: the router leaves /register for the owner's home.
    } on ValidationFailed catch (failure) {
      _showServerErrors(failure.fieldErrors, t);
    } on TooManyRequests catch (failure) {
      _startCountdown(failure.retryAfter.inSeconds);
    } on NetworkFailure {
      setState(() => _outcome = _Outcome.network);
    } on ApiFailure catch (failure) {
      setState(() {
        _outcome = _Outcome.server;
        _reference = failure.reference;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// API field errors on our fields (address → street); «email taken» gets its own wording, and the
  /// form goes back to the first step that has an error.
  void _showServerErrors(Map<String, List<String>> fieldErrors, AppLocalizations t) {
    final errors = <RegistrationField, String>{};
    registrationApiFields.forEach((key, field) {
      final message = fieldErrors[key]?.firstOrNull;
      if (message != null) errors[field] = message;
    });
    final email = errors[RegistrationField.email];
    if (email != null && _takenPattern.hasMatch(email)) errors[RegistrationField.email] = t.emailTaken;
    setState(() {
      _errors = errors;
      if (errors.isNotEmpty) _step = errors.keys.map(stepOf).reduce(math.min);
      _outcome = errors.length == 1 && errors.containsKey(RegistrationField.email)
          ? _Outcome.taken
          : _Outcome.validation;
    });
    _focusFirstError();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _waitSeconds = seconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {
        _waitSeconds--;
        if (_waitSeconds <= 0) timer.cancel();
      });
    });
  }

  String _clock(int seconds) => '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget? _banner(AppLocalizations t) {
    if (_throttled) {
      return MessageBanner(
        icon: Icons.schedule,
        tone: StatusTone.pending,
        text: t.tooManyAttempts,
        trailing: _clock(_waitSeconds),
      );
    }
    return switch (_outcome) {
      _Outcome.taken => MessageBanner(icon: Icons.warning_amber_rounded, text: t.registerFailedTaken),
      _Outcome.validation => MessageBanner(icon: Icons.warning_amber_rounded, text: t.registerFailedValidation),
      _Outcome.network => MessageBanner(icon: Icons.warning_amber_rounded, text: t.registerNetworkError),
      _Outcome.server => MessageBanner(
        icon: Icons.warning_amber_rounded,
        text: t.registerServerError,
        detail: _reference == null ? null : t.serverReference(_reference!),
      ),
      null => null,
    };
  }

  /// Announced when it appears; read together with the field it belongs to.
  Widget _errorLine(String text) => Semantics(
    liveRegion: true,
    child: Padding(
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
    ),
  );

  Widget _field(
    RegistrationField field,
    String label, {
    TextInputType? keyboard,
    bool ltr = false,
    bool secret = false,
    String? hint,
    List<String>? autofill,
    TextInputAction action = TextInputAction.next,
    VoidCallback? onDone,
  }) {
    final error = _errors[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      // The visible label, the field and its error are one node for screen readers.
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              key: Key('register.${field.name}'),
              controller: _controllers[field],
              focusNode: _focus[field],
              onSubmitted: onDone == null ? null : (_) => onDone(),
              enabled: !_submitting,
              keyboardType: keyboard,
              // A phone typed on an Arabic keyboard (٠٥٩…) is read as 059….
              inputFormatters: keyboard == TextInputType.phone ? const [LatinDigitsFormatter()] : null,
              obscureText: secret && _obscure,
              autocorrect: !ltr,
              textDirection: ltr ? TextDirection.ltr : null,
              textInputAction: action,
              autofillHints: autofill,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintTextDirection: ltr ? TextDirection.ltr : null,
                enabledBorder: error == null
                    ? null
                    : OutlineInputBorder(
                        borderRadius: BorderRadius.circular(HisbahRadius.field),
                        borderSide: BorderSide(color: StatusTone.error.fg, width: 2),
                      ),
              ),
              onChanged: (_) {
                if (_errors.containsKey(field)) setState(() => _errors = {..._errors}..remove(field));
              },
            ),
            if (error != null) _errorLine(error),
          ],
        ),
      ),
    );
  }

  Widget _cityField(AppLocalizations t) {
    final error = _errors[RegistrationField.city];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.cityLabel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('register.city'),
            focusNode: _focus[RegistrationField.city],
            initialValue: _draft.city,
            isExpanded: true,
            hint: Text(t.cityHint),
            items: [for (final c in registrationCities) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                    _draft.city = value;
                    _errors = {..._errors}..remove(RegistrationField.city);
                  }),
          ),
          if (error != null) _errorLine(error),
        ],
      ),
    );
  }

  List<Widget> _stepFields(AppLocalizations t) => switch (_step) {
    0 => [
      _field(RegistrationField.storeName, t.storeNameLabel),
      _field(RegistrationField.ownerName, t.ownerNameLabel, autofill: const [AutofillHints.name]),
    ],
    1 => [
      _field(
        RegistrationField.phone,
        t.storePhoneLabel,
        keyboard: TextInputType.phone,
        ltr: true,
        hint: '0599123456',
        autofill: const [AutofillHints.telephoneNumber],
      ),
      _cityField(t),
      _field(RegistrationField.street, t.streetLabel, autofill: const [AutofillHints.streetAddressLine1]),
    ],
    _ => [
      _field(
        RegistrationField.email,
        t.emailLabel,
        keyboard: TextInputType.emailAddress,
        ltr: true,
        hint: 'name@store.ps',
        autofill: const [AutofillHints.email],
      ),
      _field(
        RegistrationField.password,
        t.passwordLabel,
        ltr: true,
        secret: true,
        hint: t.passwordMinHint,
        autofill: const [AutofillHints.newPassword],
      ),
      _field(
        RegistrationField.passwordConfirmation,
        t.passwordConfirmLabel,
        ltr: true,
        secret: true,
        action: TextInputAction.done,
        autofill: const [AutofillHints.newPassword],
        onDone: () => _next(t),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const Key('register.togglePassword'),
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
          label: Text(_obscure ? t.showPasswordA11y : t.hidePasswordA11y),
        ),
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final banner = _banner(t);
    final last = _step == registrationSteps.length - 1;
    final headings = [
      (t.registerStepStore, t.registerStepStoreSub),
      (t.registerStepContact, t.registerStepContactSub),
      (t.registerStepAccount, t.registerStepAccountSub),
    ];
    final (heading, sub) = headings[_step];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HisbahColors.primary,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, viewport) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                // The form panel starts under the compact mark and fills the rest of the screen
                // (no empty brand band above a short step); longer steps scroll.
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: HisbahLogo(markSize: 40, color: HisbahColors.surface)),
                      ),
                      Expanded(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: HisbahColors.surface,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(HisbahRadius.sheet)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.paddingOf(context).bottom),
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(t.registerTitle, style: theme.textTheme.headlineMedium),
                                  ),
                                  Text(
                                    t.registerHelper,
                                    style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted),
                                  ),
                                  const SizedBox(height: 20),
                                  // One line names the step and where it sits: «الخطوة 1 من 3: المتجر».
                                  _StepBar(
                                    step: _step,
                                    total: registrationSteps.length,
                                    label: '${t.registerStepOf(_step + 1, registrationSteps.length)}: $heading',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(sub, style: const TextStyle(fontSize: 14, color: HisbahColors.inkMuted)),
                                  const SizedBox(height: 20),
                                  if (banner != null) ...[banner, const SizedBox(height: 16)],
                                  ..._stepFields(t),
                                  const SizedBox(height: 4),
                                  FilledButton(
                                    key: Key(last ? 'register.submit' : 'register.next'),
                                    onPressed: _submitting || _throttled ? null : () => _next(t),
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
                                        Flexible(
                                          child: Text(
                                            _submitting
                                                ? t.registerSubmitting
                                                : _throttled
                                                ? t.loginButtonWait(_clock(_waitSeconds))
                                                : last
                                                ? t.registerSubmit
                                                : t.registerNext,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_step > 0) ...[
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      key: const Key('register.back'),
                                      onPressed: _submitting ? null : () => setState(() => _step--),
                                      child: Text(t.registerBack),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(t.registerHaveAccount, style: const TextStyle(color: HisbahColors.inkMuted)),
                                      TextButton(
                                        key: const Key('register.toLogin'),
                                        onPressed: _submitting ? null : () => context.go(Routes.login),
                                        child: Text(t.registerSignIn),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
      ),
    );
  }
}

/// «الخطوة 2 من 3» with a three-part bar (text and fill, never colour alone).
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.total, required this.label});

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    excludeSemantics: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: HisbahColors.ink),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? HisbahColors.primary : HisbahColors.progressTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}
