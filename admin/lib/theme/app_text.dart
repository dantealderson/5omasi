import 'package:flutter/material.dart';
import 'package:admin/theme/app_colors.dart';

/// The Midnight Club type system — a deliberate bilingual trio.
///
///   * [kufi]  — Reem Kufi. Display & the "خماسي" wordmark. Architectural,
///     unmistakably Arabic-first. (Variable font; weight via [FontVariation].)
///   * body    — IBM Plex Sans Arabic. All UI and running text, one voice
///     across both scripts. The default family for the whole app.
///   * [mono]  — IBM Plex Mono. The "fixtures-board" data voice, reserved for
///     headline numbers only: prices, ranks, scores, countdowns.
class AppText {
  AppText._();

  static const String display = 'ReemKufi';
  static const String body = 'PlexSansArabic';
  static const String data = 'PlexMono';

  /// Reem Kufi at a chosen weight (variable-font axis).
  static TextStyle kufi({
    required double size,
    int weight = 600,
    Color? color,
    double? letterSpacing,
    double height = 1.15,
  }) {
    return TextStyle(
      fontFamily: display,
      fontFamilyFallback: const [body],
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: _weightOf(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
    );
  }

  /// IBM Plex Mono — headline numerals only. Tabular figures for a steady,
  /// scoreboard-like read.
  static TextStyle mono({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double? letterSpacing = -0.5,
    double height = 1.0,
  }) {
    return TextStyle(
      fontFamily: data,
      fontSize: size,
      height: height,
      color: color,
      letterSpacing: letterSpacing,
      fontWeight: weight,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  static FontWeight _weightOf(int w) {
    switch (w) {
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 700:
        return FontWeight.w700;
      default:
        return FontWeight.w600;
    }
  }

  /// The base [TextTheme]. Display/headline slots are Reem Kufi; everything
  /// else is Plex Sans Arabic. Numerals opt in to mono explicitly via [mono].
  static TextTheme textTheme(AppPalette p) {
    final hi = p.textHi;
    final mid = p.textMid;
    return TextTheme(
      displayLarge: kufi(size: 40, weight: 700, color: hi, height: 1.1),
      displayMedium: kufi(size: 32, weight: 700, color: hi, height: 1.1),
      displaySmall: kufi(size: 28, weight: 600, color: hi),
      headlineLarge: kufi(size: 26, weight: 700, color: hi),
      headlineMedium: kufi(size: 22, weight: 600, color: hi),
      headlineSmall: kufi(size: 19, weight: 600, color: hi),
      titleLarge: TextStyle(
        fontFamily: body,
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: hi,
      ),
      titleMedium: TextStyle(
        fontFamily: body,
        fontSize: 15,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: hi,
      ),
      titleSmall: TextStyle(
        fontFamily: body,
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: mid,
      ),
      bodyLarge: TextStyle(
        fontFamily: body,
        fontSize: 16,
        height: 1.45,
        color: hi,
      ),
      bodyMedium: TextStyle(
        fontFamily: body,
        fontSize: 14,
        height: 1.45,
        color: hi,
      ),
      bodySmall: TextStyle(
        fontFamily: body,
        fontSize: 12,
        height: 1.4,
        color: mid,
      ),
      labelLarge: TextStyle(
        fontFamily: body,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: hi,
      ),
      labelMedium: TextStyle(
        fontFamily: body,
        fontSize: 12,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: mid,
      ),
      labelSmall: TextStyle(
        fontFamily: body,
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: mid,
      ),
    );
  }
}
