import 'package:flutter/material.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/theme/camera_tokens.dart';
import '../../../core/theme/hisbah_tokens.dart';
import '../../../core/widgets/ltr_value.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../products/domain/product.dart';

/// Bottom sheet frame shared by D, E, G and H: top radius 28, 40 × 5 handle, at most 62% of
/// the screen (74% at large text). The content scrolls; the actions always stay visible.
class ScanSheet extends StatelessWidget {
  const ScanSheet({super.key, required this.child, this.actions = const []});

  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final largeText = media.textScaler.scale(16) / 16 > 1.15;
    final fraction = largeText ? CameraTokens.sheetMaxHeightLargeText : CameraTokens.sheetMaxHeight;
    final available = media.size.height - media.viewInsets.bottom - media.padding.top - 8;
    final maxHeight = (media.size.height * fraction).clamp(0.0, available);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Material(
          color: HisbahColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(HisbahRadius.sheet)),
          ),
          child: SafeArea(
            top: false,
            bottom: media.viewInsets.bottom == 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: HisbahColors.sheetHandle, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 0), child: child),
                ),
                if (actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(height: 10), actions[i]],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «الباركود 6 221007 012345»: label, then the code as an isolated LTR run.
class BarcodeLine extends StatelessWidget {
  const BarcodeLine({super.key, required this.barcode, this.suffix});

  final String barcode;

  /// Text after the code (H: «محفوظ لإعادة المحاولة.»).
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    const muted = TextStyle(fontSize: 14, height: 1.6, color: HisbahColors.inkMuted);
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          TextSpan(text: '${t.scanBarcodeLabel} '),
          // An isolated LTR run, so the digit groups never reorder inside the Arabic line.
          TextSpan(
            text: isolateLtr(formatBarcode(barcode)),
            style: const TextStyle(fontWeight: FontWeight.w700, color: HisbahColors.ink),
          ),
          if (suffix != null) TextSpan(text: ' $suffix'),
        ],
      ),
    );
  }
}

/// D · product found: name, selling_price, current_stock only. No cart, sale or stock action.
class ProductFoundSheet extends StatelessWidget {
  const ProductFoundSheet({
    super.key,
    required this.barcode,
    required this.product,
    required this.onScanAnother,
    required this.onBack,
  });

  final String barcode;
  final Product product;
  final VoidCallback onScanAnother;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final paid = StatusTone.paid;
    return ScanSheet(
      key: const Key('scan.sheet.found'),
      actions: [
        FilledButton(key: const Key('scan.another'), onPressed: onScanAnother, child: Text(t.scanAnother)),
        OutlinedButton(key: const Key('scan.backToSale'), onPressed: onBack, child: Text(t.scanBackToSale)),
      ],
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 20, color: paid.fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    t.scanFound,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: paid.fg),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              key: const Key('scan.product.name'),
              style: const TextStyle(fontSize: 22, height: 1.45, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ValueCard(
                      label: t.scanPrice,
                      value: MoneyText(
                        product.sellingPrice,
                        key: const Key('scan.product.price'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: HisbahColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _ValueCard(
                      icon: Icons.inventory_2_outlined,
                      label: t.scanStock,
                      // TODO(U-6): stock display rules (0 shown as-is; no low-stock badge yet,
                      // although the lookup does return `is_low_stock`).
                      value: LtrValue(
                        '${product.currentStock}',
                        key: const Key('scan.product.stock'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: HisbahColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BarcodeLine(barcode: barcode),
          ],
        ),
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.label, required this.value, this.icon});

  final String label;
  final Widget value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: HisbahColors.raised,
      borderRadius: BorderRadius.circular(HisbahRadius.button),
      border: Border.all(color: HisbahColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, size: 16, color: HisbahColors.inkMuted),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 14, height: 1.5, color: HisbahColors.inkMuted)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        value,
      ],
    ),
  );
}

/// E · not found. HTTP 404 and an inactive product look the same; no code or status is shown.
class NotFoundSheet extends StatelessWidget {
  const NotFoundSheet({super.key, required this.barcode, required this.onScanAgain, required this.onManual});

  final String barcode;
  final VoidCallback onScanAgain;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final debt = StatusTone.debt;
    return ScanSheet(
      key: const Key('scan.sheet.notFound'),
      actions: [
        FilledButton(key: const Key('scan.again'), onPressed: onScanAgain, child: Text(t.scanAgain)),
        OutlinedButton(key: const Key('scan.notFound.manual'), onPressed: onManual, child: Text(t.scanManual)),
      ],
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: debt.bg, borderRadius: BorderRadius.circular(HisbahRadius.field)),
              child: Icon(Icons.search_off, size: 26, color: debt.fg),
            ),
            const SizedBox(height: 12),
            Text(t.scanNotFoundTitle, style: const TextStyle(fontSize: 22, height: 1.45, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            BarcodeLine(barcode: barcode),
            const SizedBox(height: 6),
            Text(t.scanNotFoundBody, style: const TextStyle(fontSize: 15, height: 1.6, color: HisbahColors.inkMuted)),
          ],
        ),
      ),
    );
  }
}

/// H · the lookup failed (network, 5xx with «رمز المرجع», or another refusal). 401 never gets
/// here: the global session handler shows M-01 «انتهت الجلسة» instead.
class LookupErrorSheet extends StatelessWidget {
  const LookupErrorSheet({
    super.key,
    required this.barcode,
    required this.failure,
    required this.retrying,
    required this.onRetry,
    required this.onBack,
  });

  final String barcode;
  final ApiFailure failure;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final text = switch (failure) {
      NetworkFailure() => t.networkError,
      ServerError() => t.serverError,
      Forbidden() => t.forbidden,
      _ => failure.message ?? t.serverError,
    };
    final reference = failure is NetworkFailure ? null : failure.reference;

    return ScanSheet(
      key: const Key('scan.sheet.error'),
      actions: [
        FilledButton(
          key: const Key('scan.retry'),
          onPressed: retrying ? null : onRetry,
          child: retrying
              ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(t.retry),
        ),
        OutlinedButton(key: const Key('scan.error.back'), onPressed: onBack, child: Text(t.scanBackToSale)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.lookupFailedTitle, style: const TextStyle(fontSize: 20, height: 1.45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          MessageBanner(
            icon: Icons.warning_amber_rounded,
            text: text,
            detail: reference == null ? null : t.serverReference(reference),
          ),
          const SizedBox(height: 10),
          BarcodeLine(barcode: barcode, suffix: t.lookupSavedForRetry),
        ],
      ),
    );
  }
}
