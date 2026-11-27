import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../motion/motion.dart';
import '../theme/hisbah_tokens.dart';
import 'skeleton.dart';

/// Shared loading / empty / error views (every screen has these states, 06 §1).
///
/// Loading is a skeleton of the page's shape: rows for a list ([LoadingView.new]), a summary and
/// rows for one item ([LoadingView.detail]). Screen readers hear «جارٍ التحميل…».
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.rows = 5, this.padding = const EdgeInsets.all(16)}) : detail = false;

  const LoadingView.detail({super.key, this.padding = const EdgeInsets.all(16)}) : detail = true, rows = 0;

  final bool detail;
  final int rows;

  /// Inside a list that already has its own side padding, pass [EdgeInsets.zero].
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).loading,
    liveRegion: true,
    child: ExcludeSemantics(
      child: Align(
        alignment: Alignment.topCenter,
        child: ClipRect(
          child: Padding(
            padding: padding,
            child: detail ? const SkeletonDetail() : SkeletonCard(rows: rows),
          ),
        ),
      ),
    ),
  );
}

/// Nothing here yet: what this place is for, and (with [actionLabel]) the one step that fills it.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.body, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? body;

  /// The button under the text, e.g. «إضافة منتج». Shown only with [onAction].
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: EntranceFade(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconDisc(icon: icon, fg: HisbahColors.primary, bg: HisbahColors.primaryTint),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 4),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, height: 1.6, color: HisbahColors.inkMuted),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(160, HisbahSize.touchMin)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Loading failed: what went wrong and a retry, in the error tone so it is not read as «empty».
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: EntranceFade(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconDisc(icon: Icons.cloud_off_rounded, fg: StatusTone.error.fg, bg: StatusTone.error.bg),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, HisbahSize.touchMin)),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.fg, required this.bg});

  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
    width: 72,
    height: 72,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: Icon(icon, size: 34, color: fg),
  );
}
