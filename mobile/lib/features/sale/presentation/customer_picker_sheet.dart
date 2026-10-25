import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../l10n/app_localizations.dart';
import '../../customers/domain/customer.dart';
import 'product_search_sheet.dart';
import 'sale_widgets.dart';

/// What the picker returned: a customer, or «متابعة بدون زبون» (cash sales only, D-07).
class CustomerPick {
  const CustomerPick.customer(Customer this.customer);
  const CustomerPick.none() : customer = null;

  final Customer? customer;
}

/// SCR-M-05 · customer picker over checkout. One tap picks and closes.
Future<CustomerPick?> showCustomerPicker(
  BuildContext context, {
  required bool customerRequired,
  required bool canSkip,
  Customer? selected,
  bool startCreating = false,
}) => showSaleSheet<CustomerPick>(
  context,
  builder: (_) => CustomerPickerSheet(
    customerRequired: customerRequired,
    canSkip: canSkip,
    selected: selected,
    startCreating: startCreating,
  ),
);

enum _Mode { list, create }

class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({
    super.key,
    required this.customerRequired,
    required this.canSkip,
    this.selected,
    this.startCreating = false,
  });

  /// Partial or credit sale: the note explains why a customer is needed.
  final bool customerRequired;

  /// Cash sale: «متابعة بدون زبون» is offered.
  final bool canSkip;
  final Customer? selected;

  /// M-07 «+ زبون»: open on the quick-create form.
  final bool startCreating;

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  Timer? _debounce;
  int _generation = 0;

  _Mode _mode = _Mode.list;
  List<Customer> _results = const [];
  bool _loading = true;
  bool _failed = false;

  bool _saving = false;
  String? _nameError;
  String? _phoneError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    if (widget.startCreating) _mode = _Mode.create;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

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
      final results = await ref.read(customerRepositoryProvider).search(_query.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
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

  void _startCreate() => setState(() {
    _mode = _Mode.create;
    _name.text = _query.text.trim();
    _phone.clear();
    _nameError = null;
    _phoneError = null;
    _saveError = null;
  });

  Future<void> _save(AppLocalizations t) async {
    if (_saving) return;
    final name = _name.text.trim();
    final phone = _phone.text.replaceAll(RegExp(r'\s'), '');
    setState(() {
      _nameError = name.isEmpty ? t.newCustomerNameRequired : null;
      _phoneError = RegExp(r'^0\d{9}$').hasMatch(phone) ? null : t.newCustomerPhoneInvalid;
      _saveError = null;
    });
    if (_nameError != null || _phoneError != null) return;

    setState(() => _saving = true);
    try {
      final customer = await ref.read(customerRepositoryProvider).create(name: name, phone: phone);
      if (!mounted) return;
      Navigator.of(context).pop(CustomerPick.customer(customer));
    } on ValidationFailed catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _nameError = failure.fieldErrors['name']?.firstOrNull;
        _phoneError = failure.fieldErrors['phone']?.firstOrNull;
        if (_nameError == null && _phoneError == null) _saveError = failure.message;
      });
    } on ApiFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = failure is NetworkFailure ? t.networkError : (failure.message ?? t.serverError);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final creating = _mode == _Mode.create;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height - 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetHeader(title: creating ? t.newCustomerTitle : t.pickerTitle, closeLabel: t.pickerCancel),
                if (!creating) ...[
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('picker.query'),
                    controller: _query,
                    onChanged: _onQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: t.pickerSearchHint,
                      prefixIcon: const Icon(Icons.search, color: HisbahColors.inkMuted),
                      filled: true,
                      fillColor: HisbahColors.raised,
                    ),
                  ),
                  if (widget.customerRequired) ...[
                    const SizedBox(height: 8),
                    Text(t.pickerNeedsCustomer, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
                  ],
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: creating ? [_createForm(t)] : _listContent(t),
            ),
          ),
          if (widget.canSkip && !creating)
            ActionBar(
              child: OutlinedButton(
                key: const Key('picker.skip'),
                onPressed: () => Navigator.of(context).pop(const CustomerPick.none()),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(t.pickerSkip),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _listContent(AppLocalizations t) {
    if (_loading) {
      return [
        Semantics(
          label: t.pickerLoading,
          child: LineCard(
            color: HisbahColors.raised,
            radius: 16,
            child: Column(
              children: [
                for (final (i, w) in const [.62, .48, .7, .55].indexed) SkeletonRow(widthFactor: w, divider: i > 0, avatar: true),
              ],
            ),
          ),
        ),
      ];
    }
    if (_failed) {
      return [
        CenteredStateCard(
          icon: Icons.warning_amber_rounded,
          iconColor: StatusTone.error.fg,
          title: t.pickerError,
          body: t.pickerErrorBody,
          action: OutlinedButton(onPressed: _load, child: Text(t.retry)),
        ),
      ];
    }
    if (_results.isEmpty) {
      final q = _query.text.trim();
      return [
        CenteredStateCard(
          icon: Icons.search,
          iconColor: HisbahColors.inkMuted,
          title: t.pickerEmpty,
          body: t.pickerEmptyBody,
          action: OutlinedButton(
            key: const Key('picker.createFromEmpty'),
            onPressed: _startCreate,
            child: Text(q.isEmpty ? t.pickerNewCustomer : t.pickerAddNamed(q)),
          ),
        ),
      ];
    }
    return [
      LineCard(
        color: HisbahColors.raised,
        radius: 16,
        child: Column(
          children: [
            for (final (i, customer) in _results.indexed)
              _CustomerRow(
                customer: customer,
                selected: customer.id == widget.selected?.id,
                divider: i > 0,
                onTap: () => Navigator.of(context).pop(CustomerPick.customer(customer)),
              ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      _DashedButton(key: const Key('picker.create'), label: t.pickerNewCustomer, onTap: _startCreate),
    ];
  }

  Widget _createForm(AppLocalizations t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 4),
      _Field(
        label: t.newCustomerName,
        child: TextField(
          key: const Key('picker.newName'),
          controller: _name,
          enabled: !_saving,
          autocorrect: false,
          onChanged: (_) => setState(() => _nameError = null),
          decoration: InputDecoration(filled: true, fillColor: HisbahColors.raised, errorText: _nameError),
        ),
      ),
      const SizedBox(height: 14),
      _Field(
        label: t.newCustomerPhone,
        child: TextField(
          key: const Key('picker.newPhone'),
          controller: _phone,
          enabled: !_saving,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            const LatinDigitsFormatter(),
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) => setState(() => _phoneError = null),
          decoration: InputDecoration(
            filled: true,
            fillColor: HisbahColors.raised,
            hintText: '05XXXXXXXX',
            errorText: _phoneError,
            helperText: _phoneError == null ? t.newCustomerPhoneHint : null,
          ),
        ),
      ),
      if (_saveError != null) ...[
        const SizedBox(height: 12),
        Text(_saveError!, style: TextStyle(color: StatusTone.error.fg, fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 14),
      FilledButton(
        key: const Key('picker.save'),
        onPressed: _saving ? null : () => _save(t),
        child: BusyLabel(busy: _saving, label: t.newCustomerSave),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: _saving ? null : () => setState(() => _mode = _Mode.list),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        child: Text(t.newCustomerBack),
      ),
    ],
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      child,
    ],
  );
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.selected, required this.divider, required this.onTap});

  final Customer customer;
  final bool selected;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final owes = customer.balance.isPositive;
    final limit = customer.creditLimit;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        key: Key('picker.customer.${customer.id}'),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? HisbahColors.highlightRow : HisbahColors.raised,
            border: divider ? const Border(top: BorderSide(color: HisbahColors.border)) : null,
          ),
          child: Row(
            children: [
              InitialAvatar(customer.initial, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Num(customer.phoneDisplay, size: 13, weight: FontWeight.w400, color: HisbahColors.inkMuted),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      text: owes ? '${t.owesWord} ' : t.noDebtWord,
                      children: [if (owes) TextSpan(text: shekel(customer.balance))],
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: owes ? StatusTone.debt.fg : HisbahColors.inkMuted,
                    ),
                  ),
                  Text(
                    limit == null ? t.noLimitShort : '${t.limitWord} ${shekel(limit)}',
                    style: const TextStyle(fontSize: 12, color: HisbahColors.inkMuted),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_rounded, size: 20, color: HisbahColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedButton extends StatelessWidget {
  const _DashedButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add_rounded, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      side: const BorderSide(color: HisbahColors.borderStrong, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
