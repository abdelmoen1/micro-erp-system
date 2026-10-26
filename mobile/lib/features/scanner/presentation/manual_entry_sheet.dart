import 'package:flutter/material.dart';

import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../../l10n/app_localizations.dart';
import 'scan_sheets.dart';

/// G · manual barcode entry, above the system numeric keypad. The non-camera path is always
/// available (scanner, not found, permission denied).
class ManualEntrySheet extends StatefulWidget {
  const ManualEntrySheet({super.key, required this.busy, required this.onSubmit, required this.onCancel});

  /// A lookup for the typed code is running: «عرض المنتج» shows progress and is disabled.
  final bool busy;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  @override
  State<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<ManualEntrySheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _emptyError = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.busy) return;
    // TODO(U-3): manual entry rules (digits only? EAN-13/8, UPC-A, internal codes?). Today only
    // empty input is refused; the API accepts any string up to 64 characters.
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _emptyError = true);
      _focus.requestFocus();
      return;
    }
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final error = StatusTone.error.fg;

    return ScanSheet(
      key: const Key('scan.sheet.manual'),
      actions: [
        FilledButton(
          key: const Key('manual.submit'),
          onPressed: widget.busy ? null : _submit,
          child: widget.busy
              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(t.manualSubmit),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    t.scanManual,
                    style: const TextStyle(fontSize: 20, height: 1.45, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: t.manualCancelA11y,
                excludeSemantics: true,
                child: Material(
                  color: HisbahColors.ground,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('manual.cancel'),
                    customBorder: const CircleBorder(),
                    onTap: widget.onCancel,
                    child: const SizedBox.square(
                      dimension: HisbahSize.touchMin,
                      child: Icon(Icons.close_rounded, size: 22, color: HisbahColors.ink),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(t.manualLabel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          TextField(
            key: const Key('manual.field'),
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            enabled: !widget.busy,
            keyboardType: TextInputType.number,
            inputFormatters: const [LatinDigitsFormatter()],
            textInputAction: TextInputAction.search,
            // Barcodes are LTR, typed exactly as printed under the bars.
            textDirection: TextDirection.ltr,
            maxLength: 64,
            style: const TextStyle(fontSize: 18, letterSpacing: 0.5),
            onChanged: (_) {
              if (_emptyError) setState(() => _emptyError = false);
            },
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: t.manualHint,
              hintTextDirection: TextDirection.rtl,
              counterText: '',
              helperText: _emptyError ? null : t.manualHelper,
              helperMaxLines: 3,
              helperStyle: const TextStyle(fontSize: 13, height: 1.5, color: HisbahColors.inkMuted),
              error: _emptyError
                  ? Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            t.manualEmpty,
                            style: TextStyle(color: error, fontSize: 14, height: 1.4, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
