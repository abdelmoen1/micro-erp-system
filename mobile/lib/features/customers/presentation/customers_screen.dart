import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../sale/presentation/customer_picker_sheet.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../../shell/tab_screens.dart';
import '../domain/customer.dart';
import 'customer_detail_screen.dart';

/// SCR-M-07 · customers tab: search from 2 characters, balance and overdue badge, quick-create
/// (US-0304). Inactive customers are listed too: they stay payable (US-0301 AC4).
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  List<Customer> _customers = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  String get _term => _query.text.trim().length >= 2 ? _query.text.trim() : '';

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await ref.read(customerRepositoryProvider).search(_term, all: true);
      if (!mounted || generation != _generation) return;
      setState(() {
        _customers = rows;
        _loading = false;
      });
    } on ApiFailure {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _create() async {
    final pick = await showCustomerPicker(context, customerRequired: false, canSkip: false, startCreating: true);
    final customer = pick?.customer;
    if (customer == null || !mounted) return;
    await _load();
    if (mounted) await _open(customer);
  }

  Future<void> _open(Customer customer) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CustomerDetailScreen(customer: customer)));
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    final storeName = session is SignedIn ? session.user.storeName : '';
    final typed = _query.text.trim();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 10, 16, 20 + MediaQuery.paddingOf(context).bottom),
            children: [
              TabHeader(title: t.tabCustomers, storeName: storeName),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('customers.query'),
                      controller: _query,
                      onChanged: _onQuery,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: t.custSearchHint,
                        prefixIcon: const Icon(Icons.search, color: HisbahColors.inkMuted),
                        filled: true,
                        fillColor: HisbahColors.raised,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    key: const Key('customers.add'),
                    onPressed: _create,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
                    child: Text(t.custAdd),
                  ),
                ],
              ),
              if (typed.length == 1) ...[
                const SizedBox(height: 6),
                Text(t.custSearchMin, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
              ],
              const SizedBox(height: 12),
              ..._content(t),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(AppLocalizations t) {
    if (_loading && _customers.isEmpty) {
      return const [Padding(padding: EdgeInsets.only(top: 4), child: LoadingView(padding: EdgeInsets.zero))];
    }
    if (_failed) return [ErrorView(message: t.custLoadError, onRetry: _load)];
    if (_customers.isEmpty) {
      final searching = _term.isNotEmpty;
      return [
        EmptyView(
          icon: searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
          title: searching ? t.custNoResults(_term) : t.custEmptyTitle,
          body: searching ? t.custNoResultsBody : t.custEmptyBody,
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _create, child: Text(searching ? t.custAddNamed(_term) : t.custAdd)),
      ];
    }
    return [
      LineCard(
        child: Column(
          children: [
            for (var i = 0; i < _customers.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: HisbahColors.border),
              _CustomerRow(customer: _customers[i], onTap: () => _open(_customers[i])),
            ],
          ],
        ),
      ),
    ];
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final owes = customer.balance.isPositive;
    return InkWell(
      key: Key('customers.row.${customer.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            InitialAvatar(customer.initial, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  LtrValue(customer.phoneDisplay, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(
                  customer.balance.toApi(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: owes ? StatusTone.debt.fg : HisbahColors.inkMuted,
                  ),
                ),
                if (!customer.isActive)
                  _Badge(text: t.custInactive, tone: StatusTone.voided)
                else if (customer.overdue.isPositive)
                  _Badge(text: t.custOverdue, tone: StatusTone.error),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.tone});

  final String text;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 2),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
    decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tone.fg),
    ),
  );
}
