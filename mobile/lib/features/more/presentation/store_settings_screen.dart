import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../data/more_repository.dart';
import 'more_widgets.dart';

final storeProfileProvider = FutureProvider.autoDispose<StoreProfile>((ref) => ref.watch(moreRepositoryProvider).store());

/// The owner's store details: the name, phone, address and area printed on every receipt.
class StoreSettingsScreen extends ConsumerWidget {
  const StoreSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final profile = ref.watch(storeProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.storeTitle)),
      body: profile.when(
        loading: () => const LoadingView.detail(),
        error: (_, _) => ErrorView(message: t.storeLoadError, onRetry: () => ref.invalidate(storeProfileProvider)),
        data: (store) => _StoreForm(store: store),
      ),
    );
  }
}

class _StoreForm extends ConsumerStatefulWidget {
  const _StoreForm({required this.store});

  final StoreProfile store;

  @override
  ConsumerState<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends ConsumerState<_StoreForm> {
  late final _name = TextEditingController(text: widget.store.name);
  late final _phone = TextEditingController(text: widget.store.phone ?? '');
  late final _address = TextEditingController(text: widget.store.address ?? '');
  late final _area = TextEditingController(text: widget.store.area ?? '');
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _banner;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _area]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _errors = {'name': t.storeNameRequired});
      return;
    }
    setState(() {
      _saving = true;
      _errors = const {};
      _banner = null;
    });
    try {
      await ref
          .read(moreRepositoryProvider)
          .updateStore(name: _name.text, phone: _phone.text, address: _address.text, area: _area.text);
      // The receipt header reads the store from the signed-in user.
      await ref.read(sessionProvider.notifier).reloadUser();
      if (mounted) showNote(context, t.storeSaved);
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
      if (mounted) {
        setState(() => _banner = failure is Forbidden ? t.storeOwnerOnly : (failure.message ?? t.staffActionError));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
              MoreField(
                fieldKey: 'store.name',
                hint: t.phStoreName,
                label: t.storeName,
                controller: _name,
                required: true,
                error: _errors['name'],
                enabled: !_saving,
              ),
              MoreField(
                fieldKey: 'store.phone',
                label: t.storePhone,
                controller: _phone,
                keyboard: TextInputType.phone,
                ltr: true,
                hint: t.storePhoneHint,
                error: _errors['phone'],
                enabled: !_saving,
              ),
              MoreField(
                fieldKey: 'store.address',
                hint: t.phAddress,
                label: t.storeAddress,
                controller: _address,
                error: _errors['address'],
                enabled: !_saving,
              ),
              MoreField(
                fieldKey: 'store.area',
                hint: t.phArea,
                label: t.storeArea,
                controller: _area,
                error: _errors['area'],
                enabled: !_saving,
                action: TextInputAction.done,
                onSubmitted: _save,
              ),
            ],
          ),
        ),
        ActionBar(
          bottomInset: MediaQuery.paddingOf(context).bottom,
          child: FilledButton(
            key: const Key('store.save'),
            onPressed: _saving ? null : _save,
            child: BusyLabel(busy: _saving, label: t.storeSave),
          ),
        ),
      ],
    );
  }
}
