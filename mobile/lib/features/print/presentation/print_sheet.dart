import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../sale/presentation/sale_widgets.dart';
import '../application/printer_service.dart';
import '../domain/print_document.dart';

Future<void> openPrintSheet(BuildContext context, PrintDocument document) =>
    showSaleSheet<void>(context, builder: (_) => PrintSheet(document: document));

/// The print action on every invoice and return.
class PrintButton extends StatelessWidget {
  const PrintButton({super.key, required this.document});

  /// Built on tap, from the invoice as it stands then.
  final PrintDocument Function() document;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => openPrintSheet(context, document()),
    icon: const Icon(Icons.print_outlined, size: 20),
    label: Text(AppLocalizations.of(context).printAction),
  );
}

enum _Blocked { permission, bluetoothOff, noPrinters }

/// Bluetooth printers paired with the phone, the paper in them, and Android's print screen for any
/// other printer or a PDF. The last printer used comes up selected.
class PrintSheet extends ConsumerStatefulWidget {
  const PrintSheet({super.key, required this.document});

  final PrintDocument document;

  @override
  ConsumerState<PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends ConsumerState<PrintSheet> {
  List<BluetoothPrinter> _printers = const [];
  BluetoothPrinter? _printer;
  PaperWidth _paper = PaperWidth.mm58;
  _Blocked? _blocked;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final service = ref.read(printerServiceProvider);
    final port = service.port;
    final choice = await service.choice();
    _Blocked? blocked;
    var printers = const <BluetoothPrinter>[];
    if (!await port.requestBluetooth()) {
      blocked = _Blocked.permission;
    } else if (!await port.bluetoothOn()) {
      blocked = _Blocked.bluetoothOff;
    } else {
      printers = await port.paired();
      if (printers.isEmpty) blocked = _Blocked.noPrinters;
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _blocked = blocked;
      _printers = printers;
      _paper = choice.paper;
      _printer = printers.where((p) => p.address == choice.address).firstOrNull ?? printers.firstOrNull;
    });
  }

  Future<void> _print() async {
    final printer = _printer;
    if (printer == null || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _done = false;
    });
    try {
      await ref.read(printerServiceProvider).printBluetooth(widget.document, printer, _paper);
      if (mounted) setState(() => _done = true);
    } on PrintFailed {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printOther() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(printerServiceProvider).printSystem(widget.document);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final blocked = switch (_blocked) {
      _Blocked.permission => t.printNeedsPermission,
      _Blocked.bluetoothOff => t.printBluetoothOff,
      _Blocked.noPrinters => t.printNoPrinters,
      null => null,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: t.printTitle(widget.document.title, widget.document.number), closeLabel: t.backWord),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (blocked != null) ...[
            ToneCard(key: const Key('print.blocked'), tone: StatusTone.info, icon: Icons.bluetooth_disabled_rounded, title: blocked),
            const SizedBox(height: 12),
            OutlinedButton(key: const Key('print.retry'), onPressed: _load, child: Text(t.printRetry)),
          ] else ...[
            GroupLabel(t.printPrinter),
            const SizedBox(height: 8),
            LineCard(
              child: Column(
                children: [
                  for (var i = 0; i < _printers.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: HisbahColors.border),
                    _PrinterRow(
                      printer: _printers[i],
                      selected: _printers[i].address == _printer?.address,
                      onTap: _busy ? null : () => setState(() => _printer = _printers[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            GroupLabel(t.printPaper),
            const SizedBox(height: 8),
            OptionRow(
              children: [
                for (final (paper, label) in [(PaperWidth.mm58, t.printPaper58), (PaperWidth.mm80, t.printPaper80)])
                  OptionButton(
                    key: Key('print.paper.${paper.name}'),
                    label: label,
                    selected: _paper == paper,
                    onTap: () => setState(() => _paper = paper),
                  ),
              ],
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              ToneCard(key: const Key('print.failed'), tone: StatusTone.error, icon: Icons.print_disabled_outlined, title: t.printFailed, alert: true),
            ],
            if (_done) ...[
              const SizedBox(height: 12),
              ToneCard(key: const Key('print.done'), tone: StatusTone.success, icon: Icons.check_rounded, title: t.printDone, alert: true),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('print.send'),
              onPressed: _busy ? null : _print,
              icon: const Icon(Icons.print_rounded),
              label: BusyLabel(busy: _busy, label: _busy ? t.printing : t.printNow),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            key: const Key('print.other'),
            onPressed: _busy || _loading ? null : _printOther,
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(t.printOther),
          ),
        ],
      ),
    );
  }
}

class _PrinterRow extends StatelessWidget {
  const _PrinterRow({required this.printer, required this.selected, required this.onTap});

  final BluetoothPrinter printer;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('print.printer.${printer.address}'),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? HisbahColors.primary : HisbahColors.inkMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(printer.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        ],
      ),
    ),
  );
}
