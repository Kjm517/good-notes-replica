import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the "annotation studio" look.
///
/// Everything visual reads from here rather than hard-coding colours at the
/// call site, so light/dark stay in step and a palette change is one edit.
/// Semantic names (surface / surfaceAlt / fill / line) rather than literal
/// ones (white / grey100), because the same slot is a near-white on light and
/// a near-black on dark.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.accent,
    required this.accentText,
    required this.accentSoft,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.fill,
    required this.line,
    required this.lineStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.pdfBadge,
    required this.star,
    required this.premium,
    required this.premiumText,
    required this.premiumSoft,
    required this.premiumOn,
    required this.success,
    required this.shadow,
  });

  /// Brand accent — buttons, selection, the active tool.
  final Color accent;

  /// Accent tuned for *text and icons* on the current background. On dark the
  /// fill accent is too low-contrast to read as a label, so it lifts.
  final Color accentText;

  /// Tinted accent background for selected nav rows and soft chips.
  final Color accentSoft;

  /// The page-behind-the-app colour (scaffold, reader gutter).
  final Color canvas;

  /// Cards, sheets, floating panels.
  final Color surface;

  /// Chrome that sits beside content: sidebars, toolbars, title bars.
  final Color surfaceAlt;

  /// Recessed control backgrounds: search fields, segmented tracks.
  final Color fill;

  /// Hairline dividers and card outlines.
  final Color line;

  /// Slightly heavier separators (toolbar pipes, input borders).
  final Color lineStrong;

  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color textFaint;

  /// File-type badge on document covers.
  final Color pdfBadge;
  final Color star;

  /// Gold used only on premium surfaces (quiz). The rest of the app stays indigo.
  final Color premium;

  /// Gold tuned for icons and labels on chrome (toolbar quiz glyph).
  final Color premiumText;

  /// Soft gold wash behind premium chips and selected length cards.
  final Color premiumSoft;

  /// Text/icons sitting on a [premium] fill.
  final Color premiumOn;

  /// Confirmed-ok chrome: a finished cloud sync, and similar success marks.
  final Color success;

  /// Base colour for the large soft drop shadows under cards and sheets.
  final Color shadow;

  static const AppTokens light = AppTokens(
    accent: Color(0xFF5257D4),
    accentText: Color(0xFF5257D4),
    accentSoft: Color(0xFFEEF0FD),
    canvas: Color(0xFFEEF0F3),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBFBFD),
    fill: Color(0xFFF4F5F8),
    line: Color(0xFFEEF0F4),
    lineStrong: Color(0xFFE0E2EA),
    text: Color(0xFF1C1E26),
    textSecondary: Color(0xFF5B6070),
    textMuted: Color(0xFF8A8FA0),
    textFaint: Color(0xFFA8ACBA),
    pdfBadge: Color(0xFFE0574F),
    star: Color(0xFFE7B34C),
    premium: Color(0xFFD9A94E),
    premiumText: Color(0xFF8A6A1B),
    premiumSoft: Color(0xFFF8EFDA),
    premiumOn: Color(0xFF3A2C07),
    success: Color(0xFF2F9E6B),
    shadow: Color(0xFF141632),
  );

  static const AppTokens dark = AppTokens(
    accent: Color(0xFF5257D4),
    accentText: Color(0xFF8B90FF),
    accentSoft: Color(0xFF232741),
    canvas: Color(0xFF0F1119),
    surface: Color(0xFF171B24),
    surfaceAlt: Color(0xFF131520),
    fill: Color(0xFF1A1E28),
    line: Color(0xFF21252F),
    lineStrong: Color(0xFF2F3442),
    text: Color(0xFFF2F3F8),
    textSecondary: Color(0xFFC2C6D2),
    textMuted: Color(0xFF9BA0B0),
    textFaint: Color(0xFF7B8090),
    pdfBadge: Color(0xFFE0574F),
    star: Color(0xFFE7B34C),
    premium: Color(0xFFD9A94E),
    premiumText: Color(0xFFE8C56A),
    premiumSoft: Color(0xFF2A2416),
    premiumOn: Color(0xFF3A2C07),
    success: Color(0xFF5FCF96),
    shadow: Color(0xFF05060C),
  );

  /// Convenience: `context.tokens` instead of the full lookup at every use.
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? light;

  /// Space Mono — used for anything numeric or label-like (page counts, file
  /// sizes, section captions). Mixing a mono face into a humanist UI font is
  /// what gives the design its "studio" character.
  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
  }) => GoogleFonts.spaceMono(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.2,
  );

  /// The small uppercase caption that heads a settings section.
  static TextStyle sectionLabel(Color color) => GoogleFonts.spaceMono(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: color,
    letterSpacing: 1.3,
    height: 1.2,
  );

  /// Soft, wide drop shadow used on cards, sheets and floating clusters.
  static List<BoxShadow> elevation(
    Color shadow, {
    double y = 18,
    double blur = 40,
    double opacity = 0.18,
  }) => [
    BoxShadow(
      color: shadow.withValues(alpha: opacity),
      blurRadius: blur,
      offset: Offset(0, y),
      spreadRadius: -blur / 3,
    ),
  ];

  @override
  AppTokens copyWith({
    Color? accent,
    Color? accentText,
    Color? accentSoft,
    Color? canvas,
    Color? surface,
    Color? surfaceAlt,
    Color? fill,
    Color? line,
    Color? lineStrong,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? pdfBadge,
    Color? star,
    Color? premium,
    Color? premiumText,
    Color? premiumSoft,
    Color? premiumOn,
    Color? success,
    Color? shadow,
  }) {
    return AppTokens(
      accent: accent ?? this.accent,
      accentText: accentText ?? this.accentText,
      accentSoft: accentSoft ?? this.accentSoft,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      fill: fill ?? this.fill,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      pdfBadge: pdfBadge ?? this.pdfBadge,
      star: star ?? this.star,
      premium: premium ?? this.premium,
      premiumText: premiumText ?? this.premiumText,
      premiumSoft: premiumSoft ?? this.premiumSoft,
      premiumOn: premiumOn ?? this.premiumOn,
      success: success ?? this.success,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      accent: c(accent, other.accent),
      accentText: c(accentText, other.accentText),
      accentSoft: c(accentSoft, other.accentSoft),
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      fill: c(fill, other.fill),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      textFaint: c(textFaint, other.textFaint),
      pdfBadge: c(pdfBadge, other.pdfBadge),
      star: c(star, other.star),
      premium: c(premium, other.premium),
      premiumText: c(premiumText, other.premiumText),
      premiumSoft: c(premiumSoft, other.premiumSoft),
      premiumOn: c(premiumOn, other.premiumOn),
      success: c(success, other.success),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// Corner radii, kept in one place so cards, sheets and controls agree.
abstract final class Radii {
  /// Cards and document covers.
  static const double card = 16;

  /// Buttons, search fields, segmented tracks.
  static const double control = 12;

  /// Small pills inside a control (a selected segment, a tool button).
  static const double inner = 9;

  /// Bottom sheets and large dialogs.
  static const double sheet = 26;
}

/// Shared width thresholds so library, editor, and sheets pick the same form
/// factor. Matches the Annotate redesign: phone dock, tablet tool rail,
/// desktop single chrome.
abstract final class AppBreakpoints {
  /// Bottom tool dock + compact library chrome (phones, narrow windows).
  static const double phone = 760;

  /// Persistent library sidebar beside the document grid.
  static const double librarySidebar = 900;

  /// Editor pages/outline sidebar default-open threshold.
  static const double editorSidebar = 820;

  /// Single-row desktop editor toolbar (and end of tablet stacked/rail).
  static const double desktop = 1240;

  /// Shortest side at/above this is treated as tablet-class (iPad / Android
  /// tablets), even in a phone-width split view.
  static const double tabletShortest = 600;
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => AppTokens.of(this);
}

/// The app's brand mark — a rounded accent tile with the draw glyph — shared
/// by the launch splash and the sign-in hero so they always match.
class AppMark extends StatelessWidget {
  const AppMark({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: t.accent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: t.accent.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 14),
            spreadRadius: -10,
          ),
        ],
      ),
      child: const Icon(Icons.draw_rounded, size: 34, color: Colors.white),
    );
  }
}
