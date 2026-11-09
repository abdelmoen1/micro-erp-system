import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../sync/application/sync_engine.dart';
import 'more_widgets.dart';

final _deletionInfoProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(authRepositoryProvider).deletionInfo(),
);

final _day = DateFormat('dd/MM/yyyy', 'en');

/// Settings → Account → Delete account (Google Play: deletion must be reachable in the app).
/// Staff: the account is anonymised at once; the shop's records stay. Owner: the store is closed now
/// and deleted with all its data after a grace period (cancellable on the website). Reachable after
/// the subscription ends too. Unsynced sales on this phone must be sent first.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _storeName = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _banner;

  @override
  void dispose() {
    _password.dispose();
    _storeName.dispose();
    super.dispose();
  }

  Future<void> _delete(bool store) async {
    final t = AppLocalizations.of(context);
    if (ref.read(syncEngineProvider).pending > 0) {
      setState(() => _banner = t.deleteAccountPending);
      return;
    }
    setState(() {
      _errors = {
        if (_password.text.isEmpty) 'password': t.deleteAccountPasswordRequired,
        if (store && _storeName.text.trim().isEmpty) 'confirm_store_name': t.deleteAccountStoreRequired,
      };
      _banner = null;
    });
    if (_errors.isNotEmpty) return;
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .requestDeletion(password: _password.text, storeName: store ? _storeName.text.trim() : null);
      final offline = ref.read(offlineStoreProvider);
      if (await offline.available) await offline.clearCatalog();
      if (!mounted) return;
      final when = DateTime.tryParse(result['scheduled_for'] as String? ?? '');
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(t.deleteAccountDoneTitle),
          content: Text(
            result['status'] == 'scheduled' && when != null
                ? t.deleteAccountScheduled(_day.format(when.toLocal()))
                : t.deleteAccountDone,
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialog).pop(), child: Text(t.deleteAccountOk))],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      await ref.read(sessionProvider.notifier).logout();
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
      if (mounted) setState(() => _banner = failure.message ?? t.serverError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final info = ref.watch(_deletionInfoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.deleteAccountTitle)),
      body: info.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ToneCard(
            tone: StatusTone.error,
            icon: Icons.error_outline_rounded,
            title: error is NetworkFailure ? t.networkError : t.serverError,
            alert: true,
          ),
        ),
        data: (data) {
          final store = data['type'] == 'store';
          final storeName = data['store_name'] as String? ?? '';
          final request = data['request'] as Map<String, dynamic>?;
          final scheduled = request?['status'] == 'scheduled';
          final days = (data['grace_days'] as num?)?.toInt() ?? 14;
          return Column(
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
                    Text(
                      store ? t.deleteAccountOwnerBody(storeName, days) : t.deleteAccountStaffBody,
                      key: const Key('delete.explain'),
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                    const SizedBox(height: 16),
                    if (scheduled)
                      ToneCard(tone: StatusTone.pending, icon: Icons.schedule, title: t.deleteAccountAlreadyScheduled)
                    else ...[
                      MoreField(
                        fieldKey: 'delete.password',
                        label: t.pwCurrent,
                        controller: _password,
                        required: true,
                        obscure: true,
                        ltr: true,
                        error: _errors['password'],
                        enabled: !_busy,
                        autofillHints: const [AutofillHints.password],
                      ),
                      if (store)
                        MoreField(
                          fieldKey: 'delete.storeName',
                          label: t.deleteAccountStoreLabel(storeName),
                          controller: _storeName,
                          required: true,
                          error: _errors['confirm_store_name'],
                          enabled: !_busy,
                        ),
                    ],
                  ],
                ),
              ),
              if (!scheduled)
                ActionBar(
                  bottomInset: MediaQuery.paddingOf(context).bottom,
                  child: FilledButton(
                    key: const Key('delete.confirm'),
                    style: FilledButton.styleFrom(backgroundColor: HisbahColors.danger),
                    onPressed: _busy ? null : () => _delete(store),
                    child: BusyLabel(busy: _busy, label: store ? t.deleteAccountOwnerConfirm : t.deleteAccountStaffConfirm),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
