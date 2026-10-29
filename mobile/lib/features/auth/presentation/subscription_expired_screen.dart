import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/hisbah_logo.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../application/session_controller.dart';
import '../domain/app_user.dart';

/// Opens a link outside the app (WhatsApp). Overridden in tests.
final externalLinkLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

final _date = DateFormat('dd/MM/yyyy', 'en');

/// The renewal screen: the store's trial or paid subscription has ended. The session is kept and
/// the data untouched; the server refuses every business call (403 SUBSCRIPTION_EXPIRED) until the
/// platform admin activates the subscription. «تحقق من جديد» returns to the app once it is.
class SubscriptionExpiredScreen extends ConsumerStatefulWidget {
  const SubscriptionExpiredScreen({super.key});

  @override
  ConsumerState<SubscriptionExpiredScreen> createState() => _SubscriptionExpiredScreenState();
}

class _SubscriptionExpiredScreenState extends ConsumerState<SubscriptionExpiredScreen> {
  SubscriptionSummary? _summary;
  bool _checking = false;
  bool _stillInactive = false;
  bool _whatsappFailed = false;

  /// The first GET /subscription has answered (or failed), so a missing support number is real.
  bool _answered = false;
  ApiFailure? _failure;

  @override
  void initState() {
    super.initState();
    // The dates and the support number come from GET /subscription; also notices a renewal at once.
    Future.microtask(() => _check(userAsked: false));
  }

  Future<void> _check({required bool userAsked}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _failure = null;
      _stillInactive = false;
    });
    try {
      final summary = await ref.read(sessionProvider.notifier).recheckSubscription();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _stillInactive = userAsked && !summary.hasAccess;
      });
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
          _answered = true;
        });
      }
    }
  }

  Future<void> _openWhatsapp(String number, AppUser user, AppLocalizations t) async {
    final text = t.subscriptionWhatsappMessage(user.storeName, user.phone ?? '');
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}');
    var opened = false;
    try {
      opened = await ref.read(externalLinkLauncherProvider)(uri);
    } on Object {
      opened = false;
    }
    if (mounted) setState(() => _whatsappFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final lapsed = session is SubscriptionLapsed ? session : null;
    final user = lapsed?.user;
    final summary = _summary;
    final number = summary?.supportWhatsapp ?? lapsed?.supportWhatsapp;
    final paid = summary?.paidExpired ?? user?.subscriptionState == 'expired';
    final endedOn = paid ? summary?.subscriptionExpiresAt : (summary?.trialEndsAt ?? user?.trialEndsAt);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: HisbahLogo(markSize: 80, color: HisbahColors.surface)),
                    ),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: HisbahColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(HisbahRadius.sheet)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 32 + MediaQuery.paddingOf(context).bottom),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.lock_clock_outlined, size: 44, color: StatusTone.pending.fg),
                            const SizedBox(height: 12),
                            Text(
                              paid ? t.subscriptionPaidEndedTitle : t.subscriptionTrialEndedTitle,
                              key: const Key('subscription.title'),
                              style: theme.textTheme.headlineMedium,
                            ),
                            if (user != null && endedOn != null)
                              Text(
                                t.subscriptionEndedOn(user.storeName, _date.format(endedOn.toLocal())),
                                style: const TextStyle(fontSize: 15, color: HisbahColors.inkMuted),
                              ),
                            const SizedBox(height: 16),
                            if (_failure != null) ...[
                              MessageBanner(
                                icon: Icons.warning_amber_rounded,
                                text: _failure is NetworkFailure ? t.networkError : t.serverError,
                                detail: _failure!.reference == null ? null : t.serverReference(_failure!.reference!),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_stillInactive) ...[
                              MessageBanner(icon: Icons.schedule, tone: StatusTone.pending, text: t.subscriptionStillInactive),
                              const SizedBox(height: 12),
                            ],
                            MessageBanner(icon: Icons.verified_user_outlined, tone: StatusTone.paid, text: t.subscriptionDataSafe),
                            const SizedBox(height: 20),
                            if (number != null && user != null) ...[
                              FilledButton.icon(
                                key: const Key('subscription.whatsapp'),
                                onPressed: () => _openWhatsapp(number, user, t),
                                icon: const Icon(Icons.chat_outlined),
                                label: Text(t.subscriptionContactWhatsapp),
                              ),
                              if (_whatsappFailed)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: SelectableText(
                                    t.subscriptionWhatsappFailed(number),
                                    style: TextStyle(color: StatusTone.error.fg, fontWeight: FontWeight.w600),
                                  ),
                                ),
                            ] else if (_answered) ...[
                              // Only once the summary has answered: a support number may be on its way.
                              Text(
                                t.subscriptionContactNoNumber,
                                key: const Key('subscription.noNumber'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              // Without a support number the owner still needs to say which store
                              // to activate: the details, ready to copy into any message.
                              if (user != null) ...[
                                const SizedBox(height: 10),
                                _ContactDetails(user: user),
                              ],
                            ],
                            const SizedBox(height: 10),
                            Text(
                              t.subscriptionHowTo,
                              key: const Key('subscription.howTo'),
                              style: const TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const Key('subscription.checkAgain'),
                              onPressed: _checking ? null : () => _check(userAsked: true),
                              child: Text(_checking ? t.subscriptionChecking : t.subscriptionCheckAgain),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              key: const Key('subscription.logout'),
                              onPressed: _checking ? null : () => ref.read(sessionProvider.notifier).logout(),
                              child: Text(t.logout),
                            ),
                          ],
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

/// The store and the account's mobile number, selectable, with one button that copies both.
class _ContactDetails extends StatelessWidget {
  const _ContactDetails({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lines = [t.subscriptionStoreLine(user.storeName), t.subscriptionPhoneLine(user.phone ?? '')];
    return Container(
      key: const Key('subscription.details'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: HisbahColors.raised,
        borderRadius: BorderRadius.circular(HisbahRadius.field),
        border: Border.all(color: HisbahColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.subscriptionDetails, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
          const SizedBox(height: 4),
          SelectableText(lines.join('\n'), style: const TextStyle(fontSize: 15, height: 1.6, fontWeight: FontWeight.w600)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('subscription.copy'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: lines.join('\n')));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(t.subscriptionCopied)));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(t.subscriptionCopy),
            ),
          ),
        ],
      ),
    );
  }
}
