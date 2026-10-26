import 'package:flutter/material.dart';

import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/latin_digits.dart';
import '../../products/presentation/add_product_flow.dart' show FieldLabel;

/// Opens a «More» screen over the tabs (no bottom bar under a form).
Future<T?> pushScreen<T>(BuildContext context, Widget screen) =>
    Navigator.of(context, rootNavigator: true).push<T>(MaterialPageRoute(builder: (_) => screen));

/// A short confirmation at the bottom of the screen (saved, copied, deactivated).
void showNote(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// One entry of the «More» list: icon, title, one line of what it does, and a chevron.
class MoreTile extends StatelessWidget {
  const MoreTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: HisbahColors.primaryTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: HisbahColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(fontSize: 13, color: HisbahColors.inkMuted)),
              ],
            ),
          ),
          trailing ?? (onTap == null ? const SizedBox.shrink() : const Icon(Icons.chevron_left_rounded, color: HisbahColors.inkMuted)),
        ],
      ),
    ),
  );
}

/// A labelled text field in the «More» forms: label (with «*» when required), field, then the
/// error or the helper under it. Numbers and phones are LTR and read Arabic-keyboard digits.
class MoreField extends StatelessWidget {
  const MoreField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    this.required = false,
    this.error,
    this.helper,
    this.hint,
    this.keyboard = TextInputType.text,
    this.ltr = false,
    this.obscure = false,
    this.enabled = true,
    this.action = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.maxLines = 1,
  });

  /// More than one for a paragraph (it grows from one line up to this many).
  final int maxLines;

  final String fieldKey;
  final String label;
  final TextEditingController controller;
  final bool required;
  final String? error;
  final String? helper;
  final String? hint;
  final TextInputType keyboard;
  final bool ltr;
  final bool obscure;
  final bool enabled;
  final TextInputAction action;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label: label, required: required),
        const SizedBox(height: 6),
        TextField(
          key: Key(fieldKey),
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          minLines: maxLines > 1 ? 3 : null,
          maxLines: maxLines,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
          textInputAction: action,
          autofillHints: autofillHints,
          inputFormatters: ltr && !obscure ? const [LatinDigitsFormatter()] : null,
          textDirection: ltr ? TextDirection.ltr : null,
          textAlign: ltr ? TextAlign.left : TextAlign.start,
          onChanged: onChanged,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          decoration: InputDecoration(
            // What the field is for sits inside it, not as a note under it; only errors go below.
            hintText: helper ?? hint,
            hintMaxLines: 2,
            hintTextDirection: Directionality.of(context),
            errorText: error,
            errorMaxLines: 3,
            filled: true,
            fillColor: HisbahColors.raised,
          ),
        ),
      ],
    ),
  );
}

/// A form sheet: the header on top, the fields scrolling in between, and the one action pinned at
/// the bottom, so it stays reachable on a small phone and above the keyboard.
class FormSheet extends StatelessWidget {
  const FormSheet({super.key, required this.header, required this.children, this.action});

  final Widget header;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: header),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
      if (action != null)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: HisbahColors.border))),
          child: action,
        ),
    ],
  );
}

/// «Are you sure?» for an action that cannot be undone from the app (deactivate a person or a
/// product). True when confirmed.
Future<bool> confirmDanger(BuildContext context, {required String title, required String body, required String action}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          key: const Key('confirm.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        TextButton(
          key: const Key('confirm.ok'),
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: StatusTone.error.fg),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
