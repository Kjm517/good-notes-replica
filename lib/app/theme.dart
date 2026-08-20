import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design.dart';

/// App-wide theming, driven by [AppTokens].
///
/// The colour scheme is written out explicitly rather than generated from a
/// seed: `ColorScheme.fromSeed` harmonises every slot towards the seed hue,
/// which pulled the near-neutral greys of this design towards indigo and
/// muddied the surfaces.
class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppTokens.light);
  static ThemeData dark() => _build(Brightness.dark, AppTokens.dark);

  static ThemeData _build(Brightness brightness, AppTokens t) {
    final isLight = brightness == Brightness.light;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: Colors.white,
      primaryContainer: t.accentSoft,
      onPrimaryContainer: t.accentText,
      secondary: t.accent,
      onSecondary: Colors.white,
      secondaryContainer: t.accentSoft,
      onSecondaryContainer: t.accentText,
      surface: t.surface,
      onSurface: t.text,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surfaceAlt,
      surfaceContainer: t.surfaceAlt,
      surfaceContainerHigh: t.fill,
      surfaceContainerHighest: t.fill,
      onSurfaceVariant: t.textSecondary,
      outline: t.lineStrong,
      outlineVariant: t.line,
      error: const Color(0xFFE0574F),
      onError: Colors.white,
      errorContainer: isLight ? const Color(0xFFFDECEA) : const Color(0xFF3A1D1B),
      onErrorContainer: const Color(0xFFE0574F),
      inverseSurface: isLight ? t.text : t.surface,
      onInverseSurface: isLight ? Colors.white : t.text,
      shadow: t.shadow,
      scrim: t.shadow,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: t.canvas,
      splashFactory: InkSparkle.splashFactory,
    );

    // Figtree for the UI; numerals and captions opt into Space Mono locally
    // via AppTokens.mono.
    final text = GoogleFonts.figtreeTextTheme(base.textTheme).apply(
      bodyColor: t.text,
      displayColor: t.text,
    );

    return base.copyWith(
      extensions: [t],
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.9,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      canvasColor: t.surface,
      dividerColor: t.line,
      hintColor: t.textMuted,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: t.line),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surfaceAlt,
        foregroundColor: t.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: t.text,
        ),
        iconTheme: IconThemeData(color: t.textSecondary, size: 22),
        actionsIconTheme: IconThemeData(color: t.textSecondary, size: 22),
      ),
      iconTheme: IconThemeData(color: t.textSecondary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          side: BorderSide(color: t.lineStrong),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accentText,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.fill,
        hintStyle: TextStyle(color: t.textMuted, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: t.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: t.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: t.accent, width: 1.6),
        ),
        prefixIconColor: t.textMuted,
        suffixIconColor: t.textMuted,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: t.lineStrong,
        dragHandleSize: const Size(40, 5),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: text.titleLarge?.copyWith(color: t.text),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: t.shadow.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: t.line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.fill,
        selectedColor: t.accentSoft,
        side: BorderSide(color: t.line),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: t.textSecondary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? Colors.white
                : (isLight ? Colors.white : t.textFaint)),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.accent : t.fill),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.accent : t.lineStrong),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.lineStrong,
        thumbColor: t.accent,
        overlayColor: t.accent.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.textSecondary,
        textColor: t.text,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.accent,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 6,
        highlightElevation: 6,
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surfaceAlt,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.accentSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? t.accentText
                : t.textFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected)
                ? t.accentText
                : t.textFaint,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight ? t.text : t.fill,
        contentTextStyle:
            TextStyle(color: isLight ? Colors.white : t.text, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isLight ? t.text : t.fill,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          color: isLight ? Colors.white : t.text,
          fontSize: 12,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.fill,
        circularTrackColor: t.fill,
      ),
    );
  }
}
