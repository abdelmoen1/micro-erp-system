import 'package:flutter/material.dart';

import '../theme/hisbah_tokens.dart';

/// Form-level message (invalid credentials, throttling, network, session expired).
/// Carries an icon, text and a status tone; colour is never the only carrier.
class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.icon,
    required this.text,
    this.tone = StatusTone.error,
    this.trailing,
    this.detail,
  });

  final IconData icon;
  final String text;
  final StatusTone tone;

  /// Bold LTR value appended to [text] (e.g. the throttle countdown).
  final String? trailing;

  /// Smaller second line (e.g. the support reference).
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: tone.fg, fontSize: 15, height: 1.6, fontWeight: FontWeight.w600);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(HisbahRadius.field),
          border: Border.all(color: tone.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 22, color: tone.fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: text,
                      children: [
                        if (trailing != null)
                          TextSpan(
                            text: ' $trailing',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    style: style,
                  ),
                  if (detail != null) Text(detail!, style: style.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
