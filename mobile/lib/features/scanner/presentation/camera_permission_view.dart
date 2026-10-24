import 'package:flutter/material.dart';

import '../../../core/theme/hisbah_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// F · the camera is not allowed. Never a dead end: allow / settings, manual entry, back.
class CameraPermissionView extends StatelessWidget {
  const CameraPermissionView({
    super.key,
    required this.blocked,
    required this.onAllow,
    required this.onManual,
    required this.onBack,
  });

  /// Denied permanently: only the app settings can grant it.
  final bool blocked;

  /// Shows the system dialog again (denied once) or opens the app settings (blocked).
  final VoidCallback onAllow;
  final VoidCallback onManual;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tone = StatusTone.pending;
    const body = TextStyle(fontSize: 16, height: 1.7, color: HisbahColors.inkMuted);

    return ColoredBox(
      color: HisbahColors.ground,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        key: const Key('permission.back'),
                        tooltip: t.scanBackToSale,
                        constraints: const BoxConstraints.tightFor(
                          width: HisbahSize.touchMin,
                          height: HisbahSize.touchMin,
                        ),
                        icon: const Icon(Icons.arrow_forward, color: HisbahColors.ink),
                        onPressed: onBack,
                      ),
                    ),
                    const Spacer(),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: tone.bg,
                          borderRadius: BorderRadius.circular(HisbahRadius.card),
                        ),
                        child: Icon(Icons.no_photography_outlined, size: 30, color: tone.fg),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        t.scanDeniedTitle,
                        key: Key(blocked ? 'permission.blocked' : 'permission.denied'),
                        style: const TextStyle(fontSize: 24, height: 1.45, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(blocked ? t.scanBlockedBody : t.scanDeniedBody, style: body),
                    if (blocked) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: HisbahColors.surface,
                          borderRadius: BorderRadius.circular(HisbahRadius.field),
                          border: Border.all(color: HisbahColors.border),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '${t.scanBlockedPath} '),
                              TextSpan(
                                text: t.scanBlockedPathCamera,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: ' ${t.scanBlockedPathAllow}'),
                            ],
                          ),
                          style: const TextStyle(fontSize: 14, height: 1.7, color: HisbahColors.ink),
                        ),
                      ),
                    ],
                    const Spacer(flex: 2),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('permission.allow'),
                      onPressed: onAllow,
                      child: Text(blocked ? t.scanOpenSettings : t.scanAllowCamera),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(key: const Key('permission.manual'), onPressed: onManual, child: Text(t.scanManual)),
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('permission.backToSale'),
                      style: TextButton.styleFrom(
                        foregroundColor: HisbahColors.ink,
                        minimumSize: const Size.fromHeight(HisbahSize.touchMin),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onPressed: onBack,
                      child: Text(t.scanBackToSale),
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
