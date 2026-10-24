import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/hisbah_tokens.dart';
import '../../core/widgets/hisbah_logo.dart';
import '../../l10n/app_localizations.dart';

/// Shown while a stored session is checked with GET /me (hi-fi board: splash).
/// No actions; avoids a flash of the login screen. Reversed: ivory mark and text on deep teal.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: HisbahColors.primary,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    // Full width, so the column centres on the screen rather than on its widest line.
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height * 0.7,
                      minWidth: double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const HisbahLogo(markSize: 120, color: HisbahColors.surface),
                        const SizedBox(height: 28),
                        Text(
                          t.splashTagline,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: HisbahColors.onPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          t.splashSubline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: HisbahColors.onPrimaryMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56, top: 12),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 120,
                        child: ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            color: HisbahColors.surface,
                            backgroundColor: HisbahColors.onPrimaryLine,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(t.splashChecking, style: const TextStyle(fontSize: 13, color: HisbahColors.onPrimaryMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
