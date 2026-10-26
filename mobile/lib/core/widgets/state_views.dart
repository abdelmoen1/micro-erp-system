import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
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

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[const SizedBox(height: 4), Text(body!, textAlign: TextAlign.center)],
        ],
      ),
    ),
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).retry)),
        ],
      ),
    ),
  );
}
