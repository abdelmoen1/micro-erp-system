import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/app_user.dart';
import 'checkout_screen.dart';

class SuspendedInvoicesScreen extends ConsumerStatefulWidget {
  const SuspendedInvoicesScreen({super.key});

  @override
  ConsumerState<SuspendedInvoicesScreen> createState() =>
      _SuspendedInvoicesScreenState();
}

class _SuspendedInvoicesScreenState
    extends ConsumerState<SuspendedInvoicesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int? _actingOn;
  String? _uncertainAction;
  int? _uncertainInvoiceId;
  String? _uncertainReason;

  bool get _canCancel {
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
      final data = await ref
          .read(moreRepositoryProvider)
          .suspendedInvoices('pending_transfer');
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
        if (_uncertainInvoiceId != null &&
            !data.any((item) => item['id'] == _uncertainInvoiceId)) {
          _uncertainAction = null;
          _uncertainInvoiceId = null;
          _uncertainReason = null;
        }
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = failure.message ?? 'تعذر تحميل الفواتير المعلقة.';
        _loading = false;
      });
    }
  }

  String _waitingSince(String? createdAt) {
    final created = DateTime.tryParse(createdAt ?? '')?.toUtc();
    if (created == null) {
      return 'وقت الانتظار غير متاح';
    }
    final elapsed = DateTime.now().toUtc().difference(created);
    if (elapsed.inDays > 0) {
      return 'منذ ${elapsed.inDays} يوم و${elapsed.inHours.remainder(24)} ساعة';
    }
    if (elapsed.inHours > 0) {
      return 'منذ ${elapsed.inHours} ساعة و${elapsed.inMinutes.remainder(60)} دقيقة';
    }
    return 'منذ ${elapsed.inMinutes.clamp(1, 59)} دقيقة';
  }

  Future<void> _act(int id, {required bool confirm}) async {
    if (_actingOn != null) return;
    setState(() {
      _actingOn = id;
      _error = null;
    });
    try {
      if (confirm) {
        await ref.read(moreRepositoryProvider).confirmSuspendedInvoice(id);
      } else {
        await ref
            .read(moreRepositoryProvider)
            .closeSuspendedInvoice(
              id,
              status: 'rejected',
              reason: 'رفض التحويل',
            );
      }
      if (mounted) {
        setState(() {
          _actingOn = null;
          _uncertainAction = null;
          _uncertainInvoiceId = null;
          _uncertainReason = null;
        });
        await _load();
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _actingOn = null;
        _error = failure.message ?? 'تعذر تنفيذ الإجراء. أعد المحاولة.';
        if (!MoreRepositoryFailurePolicy.isFinalAnswer(failure)) {
          _uncertainAction = confirm ? 'confirm' : 'reject';
          _uncertainInvoiceId = id;
        } else {
          _uncertainAction = null;
          _uncertainInvoiceId = null;
          _uncertainReason = null;
        }
      });
    }
  }

  Future<void> _cancel(int id) async {
    final retryingSameCancel =
        _uncertainAction == 'cancel' && _uncertainInvoiceId == id;
    final reasonController = TextEditingController(
      text: retryingSameCancel ? _uncertainReason : null,
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الفاتورة وإطلاق الحجز'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          readOnly: retryingSameCancel,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'سبب الإلغاء',
            hintText: 'أدخل سببًا للمراجعة لاحقًا',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted || _actingOn != null) return;

    setState(() {
      _actingOn = id;
      _error = null;
    });
    try {
      await ref
          .read(moreRepositoryProvider)
          .closeSuspendedInvoice(id, status: 'cancelled', reason: reason);
      if (mounted) {
        setState(() {
          _actingOn = null;
          _uncertainAction = null;
          _uncertainInvoiceId = null;
          _uncertainReason = null;
        });
        await _load();
      }
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _actingOn = null;
        _error =
            failure.message ?? 'تعذر إلغاء الفاتورة. أعد المحاولة بالسبب نفسه.';
        if (!MoreRepositoryFailurePolicy.isFinalAnswer(failure)) {
          _uncertainAction = 'cancel';
          _uncertainInvoiceId = id;
          _uncertainReason = reason;
        } else {
          _uncertainAction = null;
          _uncertainInvoiceId = null;
          _uncertainReason = null;
        }
      });
    }
  }

  Future<void> _resume(Map<String, dynamic> item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CheckoutScreen(suspendedInvoice: item)),
    );
    if (changed == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير المعلقة'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
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
                        leading: const Icon(Icons.error_outline),
                        title: Text(_error!),
                        subtitle: _uncertainAction != null
                            ? const Text(
                                'أعد المحاولة بالإجراء نفسه أو حدّث الحالة أولًا.',
                              )
                            : null,
                        trailing: IconButton(
                          tooltip: 'إعادة المحاولة',
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  if (_items.isEmpty && _error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('لا توجد فواتير معلقة')),
                    ),
                  for (final item in _items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '#${item['reference']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(_waitingSince(item['created_at'] as String?)),
                            Text(
                              '${(item['customer'] as Map<String, dynamic>?)?['name'] ?? 'بدون زبون'} · ${(item['cashier'] as Map<String, dynamic>?)?['name'] ?? ''}',
                            ),
                            Text(
                              '${item['account_snapshot_name']} · ${item['account_snapshot_identifier']}',
                              textDirection: TextDirection.ltr,
                            ),
                            Text('الإجمالي: ${item['total_amount']}'),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  _actingOn == null && _uncertainAction == null
                                  ? () => _resume(item)
                                  : null,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('استئناف ومراجعة الفاتورة'),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed:
                                        _actingOn == null &&
                                            (_uncertainAction == null ||
                                                _uncertainAction ==
                                                    'confirm') &&
                                            (_uncertainInvoiceId == null ||
                                                _uncertainInvoiceId ==
                                                    item['id'])
                                        ? () => _act(
                                            (item['id'] as num).toInt(),
                                            confirm: true,
                                          )
                                        : null,
                                    child:
                                        _actingOn == item['id'] &&
                                            _uncertainAction == 'confirm'
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _uncertainAction == 'confirm'
                                                ? 'إعادة تأكيد الاستلام'
                                                : 'تأكيد الاستلام',
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        _actingOn == null &&
                                            (_uncertainAction == null ||
                                                _uncertainAction == 'reject') &&
                                            (_uncertainInvoiceId == null ||
                                                _uncertainInvoiceId ==
                                                    item['id'])
                                        ? () => _act(
                                            (item['id'] as num).toInt(),
                                            confirm: false,
                                          )
                                        : null,
                                    child: Text(
                                      _uncertainAction == 'reject'
                                          ? 'إعادة رفض'
                                          : 'رفض',
                                    ),
                                  ),
                                ),
                                if (_canCancel) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'إلغاء مع سبب وإطلاق الحجز',
                                    onPressed:
                                        _actingOn == null &&
                                            (_uncertainAction == null ||
                                                _uncertainAction == 'cancel') &&
                                            (_uncertainInvoiceId == null ||
                                                _uncertainInvoiceId ==
                                                    item['id'])
                                        ? () => _cancel(
                                            (item['id'] as num).toInt(),
                                          )
                                        : null,
                                    icon: const Icon(Icons.cancel_outlined),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

abstract final class MoreRepositoryFailurePolicy {
  static bool isFinalAnswer(ApiFailure failure) => switch (failure) {
    NetworkFailure() ||
    ServerError() ||
    TooManyRequests() ||
    Unauthenticated() => false,
    _ => true,
  };
}
