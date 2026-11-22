import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';

class SuspendedInvoicesScreen extends ConsumerStatefulWidget {
  const SuspendedInvoicesScreen({super.key});

  @override
  ConsumerState<SuspendedInvoicesScreen> createState() => _SuspendedInvoicesScreenState();
}

class _SuspendedInvoicesScreenState extends ConsumerState<SuspendedInvoicesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await ref.read(moreRepositoryProvider).suspendedInvoices('pending_transfer');
    if (!mounted) return;
    setState(() { _items = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الفواتير المعلقة')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(child: Text('لا توجد فواتير معلقة'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final customer = item['customer'] as Map<String, dynamic>?;
                      final cashier = item['cashier'] as Map<String, dynamic>?;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('#${item['reference']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Text('${customer?['name'] ?? 'بدون زبون'} · ${cashier?['name'] ?? ''}'),
                              Text('${item['account_snapshot_name']} · ${item['account_snapshot_identifier']}',
                                  textDirection: TextDirection.ltr),
                              Text('الإجمالي: ${item['total_amount']}'),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        await ref.read(moreRepositoryProvider).confirmSuspendedInvoice((item['id'] as num).toInt());
                                        await _load();
                                      },
                                      child: const Text('تأكيد الاستلام'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        await ref.read(moreRepositoryProvider).closeSuspendedInvoice(
                                          (item['id'] as num).toInt(),
                                          status: 'rejected',
                                          reason: 'رفض التحويل',
                                        );
                                        await _load();
                                      },
                                      child: const Text('رفض'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
