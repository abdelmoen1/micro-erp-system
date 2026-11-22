import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import 'more_widgets.dart';

class ReceivingAccountsScreen extends ConsumerStatefulWidget {
  const ReceivingAccountsScreen({super.key});

  @override
  ConsumerState<ReceivingAccountsScreen> createState() => _ReceivingAccountsScreenState();
}

class _ReceivingAccountsScreenState extends ConsumerState<ReceivingAccountsScreen> {
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ref.read(moreRepositoryProvider).receivingAccounts(includeInactive: true);
      if (!mounted) return;
      setState(() { _accounts = data; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
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
      appBar: AppBar(title: const Text('حسابات استقبال الحوالات')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [Padding(padding: const EdgeInsets.all(16), child: Text(_error!))])
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_accounts.isEmpty)
                        const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('لا توجد حسابات استقبال'))),
                      for (final account in _accounts)
                        Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(account['account_name'] as String? ?? ''),
                            subtitle: Text('${_providerLabel(account['provider'] as String? ?? '')}\n${account['account_identifier'] ?? ''}',
                                textDirection: TextDirection.ltr),
                            trailing: Text(account['active'] == true ? 'نشط' : 'مؤرشف',
                                style: TextStyle(color: account['active'] == true ? HisbahColors.primary : HisbahColors.inkMuted)),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}
