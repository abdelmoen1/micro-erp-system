import 'package:flutter/material.dart';

import 'hisbah_tokens.dart';

/// Theme from the Direction A tokens ([HisbahColors]): selected at DR-2 part 1, final sign-off pending.
/// IBM Plex Sans Arabic has no 800 weight, so 700 is the heaviest.
abstract final class AppTheme {
  static const fontFamily = 'IBMPlexSansArabic';

  static ThemeData directionA() {
    final scheme = ColorScheme.fromSeed(seedColor: HisbahColors.primary).copyWith(
      primary: HisbahColors.primary,
      onPrimary: HisbahColors.onPrimary,
      primaryContainer: HisbahColors.primaryTint,
      onPrimaryContainer: HisbahColors.primaryPressed,
      surface: HisbahColors.surface,
      onSurface: HisbahColors.ink,
      onSurfaceVariant: HisbahColors.inkMuted,
      outline: HisbahColors.borderStrong,
      outlineVariant: HisbahColors.border,
      error: StatusTone.error.fg,
      scrim: HisbahColors.scrim,
    );

    const ink = HisbahColors.ink;
    final textTheme = const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, height: 38 / 28, fontWeight: FontWeight.w700, color: ink),
      titleLarge: TextStyle(fontSize: 22, height: 32 / 22, fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontSize: 19, height: 1.4, fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(fontSize: 16, height: 26 / 16, color: ink),
      bodyMedium: TextStyle(fontSize: 16, height: 26 / 16, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 20 / 13, color: HisbahColors.inkMuted),
      labelLarge: TextStyle(fontSize: 18, height: 26 / 18, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 14, height: 22 / 14, fontWeight: FontWeight.w600, color: ink),
    ).apply(fontFamily: fontFamily);

    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(HisbahRadius.button));
    OutlineInputBorder fieldBorder(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(HisbahRadius.field),
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: HisbahColors.ground,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: HisbahColors.ground,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
      ),
      // Rest fields are tinted; focused and error fields turn white with a 2 px border (hi-fi M-01).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? HisbahColors.disabledBg
              : states.contains(WidgetState.focused) || states.contains(WidgetState.error)
              ? HisbahColors.raised
              : HisbahColors.ground,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: HisbahColors.inkSubtle, fontSize: 16),
        errorStyle: TextStyle(color: StatusTone.error.fg, fontSize: 14, height: 1.4),
        errorMaxLines: 3,
        enabledBorder: fieldBorder(HisbahColors.borderStrong, 1.5),
        focusedBorder: fieldBorder(HisbahColors.primary, 2),
        errorBorder: fieldBorder(StatusTone.error.fg, 2),
        focusedErrorBorder: fieldBorder(StatusTone.error.fg, 2),
        disabledBorder: fieldBorder(HisbahColors.border, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HisbahColors.primary,
          foregroundColor: HisbahColors.onPrimary,
          disabledBackgroundColor: HisbahColors.disabledBg,
          disabledForegroundColor: HisbahColors.disabledInk,
          minimumSize: const Size.fromHeight(HisbahSize.button),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HisbahColors.primary,
          minimumSize: const Size.fromHeight(HisbahSize.button),
          shape: buttonShape,
          side: const BorderSide(color: HisbahColors.primary, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HisbahColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: HisbahColors.scrim,
        dragHandleColor: HisbahColors.sheetHandle,
        dragHandleSize: Size(40, 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(HisbahRadius.sheet))),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HisbahColors.primary,
        linearTrackColor: HisbahColors.progressTrack,
      ),
      dividerTheme: const DividerThemeData(color: HisbahColors.border, thickness: 1, space: 1),
    );
  }
}
