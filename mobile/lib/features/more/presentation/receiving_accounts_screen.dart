import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';

class ReceivingAccountsScreen extends ConsumerStatefulWidget {
  const ReceivingAccountsScreen({super.key});

  @override
  ConsumerState<ReceivingAccountsScreen> createState() => _ReceivingAccountsScreenState();
}

class _ReceivingAccountsScreenState extends ConsumerState<ReceivingAccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool get _canManage {
    final session = ref.read(sessionProvider);
    return session is SignedIn && session.user.role != UserRole.employee;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(moreRepositoryProvider).receivingAccounts(includeInactive: _canManage);
      if (!mounted) return;
      setState(() {
        _accounts = data;
        _loading = false;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message ?? 'تعذر تحميل حسابات الاستقبال.';
        _loading = false;
      });
    }
  }

  Future<void> _editAccount([Map<String, dynamic>? account]) async {
    final name = TextEditingController(text: account?['account_name'] as String? ?? '');
    final identifier = TextEditingController(text: account?['account_identifier'] as String? ?? '');
    var provider = account?['provider'] as String? ?? 'palpay';
    var active = account?['active'] as bool? ?? true;
    var saving = false;
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(account == null ? 'إضافة حساب استقبال' : 'تعديل حساب الاستقبال'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: provider,
                  decoration: const InputDecoration(labelText: 'مزود التحويل'),
                  items: const [
                    DropdownMenuItem(value: 'palpay', child: Text('بال بي')),
                    DropdownMenuItem(value: 'jawwal_pay', child: Text('جوال بي')),
                    DropdownMenuItem(value: 'bank_of_palestine', child: Text('بنك فلسطين')),
                  ],
                  onChanged: saving ? null : (value) => setDialogState(() => provider = value ?? provider),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'اسم الحساب'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: identifier,
                  enabled: !saving,
                  decoration: const InputDecoration(labelText: 'رقم الحساب أو الهاتف'),
                  textDirection: TextDirection.ltr,
                ),
                if (account != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الحساب نشط'),
                    value: active,
                    onChanged: saving ? null : (value) => setDialogState(() => active = value),
                  ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty || identifier.text.trim().isEmpty) {
                        setDialogState(() => error = 'أدخل اسم الحساب ومعرّفه.');
                        return;
                      }
                      setDialogState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await ref.read(moreRepositoryProvider).saveReceivingAccount(
                          id: (account?['id'] as num?)?.toInt(),
                          provider: provider,
                          name: name.text.trim(),
                          identifier: identifier.text.trim(),
                          active: active,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      } on ApiFailure catch (failure) {
                        setDialogState(() {
                          saving = false;
                          error = failure.message ?? 'تعذر حفظ الحساب.';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    identifier.dispose();
    if (saved == true && mounted) await _load();
  }

  Future<void> _archive(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أرشفة الحساب'),
        content: const Text('سيبقى الحساب محفوظًا في سجلات الفواتير السابقة ولن يظهر للاختيار.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إبقاء الحساب')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('أرشفة')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(moreRepositoryProvider).archiveReceivingAccount((account['id'] as num).toInt());
      await _load();
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() => _error = failure.message ?? 'تعذر أرشفة الحساب.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _providerLabel(String provider) => switch (provider) {
    'palpay' => 'بال بي',
    'jawwal_pay' => 'جوال بي',
    'bank_of_palestine' => 'بنك فلسطين',
    _ => provider,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابات استقبال الحوالات'),
        actions: [
          if (_canManage)
            IconButton(
              tooltip: 'إضافة حساب',
              onPressed: _saving ? null : () => _editAccount(),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: HisbahColors.danger),
                        title: Text(_error!),
                        trailing: IconButton(
                          tooltip: 'إعادة المحاولة',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  if (_accounts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('لا توجد حسابات استقبال نشطة')),
                    ),
                  for (final account in _accounts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(account['account_name'] as String? ?? ''),
                        subtitle: Text(
                          '${_providerLabel(account['provider'] as String? ?? '')}\n${account['account_identifier'] ?? ''}',
                          textDirection: TextDirection.ltr,
                        ),
                        trailing: _canManage
                            ? PopupMenuButton<String>(
                                tooltip: 'إجراءات الحساب',
                                onSelected: (action) {
                                  if (action == 'edit') _editAccount(account);
                                  if (action == 'archive') _archive(account);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                  const PopupMenuItem(value: 'archive', child: Text('أرشفة')),
                                ],
                              )
                            : Text(
                                account['active'] == true ? 'نشط' : 'مؤرشف',
                                style: TextStyle(color: account['active'] == true ? HisbahColors.primary : HisbahColors.inkMuted),
                              ),
                        onTap: _canManage ? () => _editAccount(account) : null,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
