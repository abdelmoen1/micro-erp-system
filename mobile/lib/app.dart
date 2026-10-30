import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/guide/coach_tour.dart';
import 'l10n/app_localizations.dart';

class SmartShopApp extends ConsumerWidget {
  const SmartShopApp({super.key, this.locale = const Locale('ar')});

  /// Arabic first (SRS §9.4); layout direction follows the locale (RTL for ar).
  final Locale locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.directionA(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => CoachOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
