import 'package:flutter/material.dart';

/// Midnight Club palette.
///
/// Five-a-side under floodlights, rendered like a premium matchday ticket:
/// a blue-green night, one confident emerald, and gold used sparingly like
/// metal trim on a bezel.
///
/// Two ways to reach these colors:
///   * [AppColors] — fixed brand constants for quick, theme-agnostic use
///     (the emerald accent reads the same in light and dark).
///   * [AppPalette] — a [ThemeExtension] with the full semantic set that
///     flips with the active theme. Read it with `context.palette`.
class AppColors {
  AppColors._();

  /// The one color. Used as the theme-agnostic brand accent.
  static const Color brand = Color(0xFF12B886); // emerald
  static const Color brandDeep = Color(0xFF0E9E74); // emerald, light-mode text
  static const Color brandPressed = Color(0xFF0FA378);
  static const Color brandTint = Color(0xFFD9F1E6); // pale emerald wash

  /// Metal trim.
  static const Color gold = Color(0xFFC9A24B);
  static const Color goldLight = Color(0xFFA9822E);

  /// Text that sits on top of an emerald fill (dark ink, not white — reads
  /// crisp and premium, like ink on a bright kit).
  static const Color onBrand = Color(0xFF06100E);

  static const Color danger = Color(0xFFE5644E);
  static const Color dangerLight = Color(0xFFC6472F);

  // --- Dark (the star) ---
  static const Color dNight = Color(0xFF0C1416);
  static const Color dSurface = Color(0xFF111C1E);
  static const Color dRaised = Color(0xFF17272B);
  static const Color dLine = Color(0xFF24373B);
  static const Color dBone = Color(0xFFECF1EC);
  static const Color dMist = Color(0xFF93A6A2);
  static const Color dFaint = Color(0xFF5E706D);

  // --- Light ---
  static const Color lPaper = Color(0xFFEFF3EF);
  static const Color lSurface = Color(0xFFFFFFFF);
  static const Color lRaised = Color(0xFFF6F9F6);
  static const Color lLine = Color(0xFFE1E7E2);
  static const Color lInk = Color(0xFF0C1416);
  static const Color lSlate = Color(0xFF55635F);
  static const Color lFaint = Color(0xFF8A9793);
}

/// Semantic, theme-aware colors. Read via `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.line,
    required this.emerald,
    required this.emeraldPressed,
    required this.emeraldSoft,
    required this.gold,
    required this.goldSoft,
    required this.onEmerald,
    required this.textHi,
    required this.textMid,
    required this.textLow,
    required this.danger,
    required this.dangerSoft,
    required this.isDark,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color line;
  final Color emerald;
  final Color emeraldPressed;
  final Color emeraldSoft;
  final Color gold;
  final Color goldSoft;
  final Color onEmerald;
  final Color textHi;
  final Color textMid;
  final Color textLow;
  final Color danger;
  final Color dangerSoft;
  final bool isDark;

  static const AppPalette dark = AppPalette(
    background: AppColors.dNight,
    surface: AppColors.dSurface,
    surfaceRaised: AppColors.dRaised,
    line: AppColors.dLine,
    emerald: AppColors.brand,
    emeraldPressed: AppColors.brandPressed,
    emeraldSoft: Color(0x2212B886), // ~13%
    gold: AppColors.gold,
    goldSoft: Color(0x22C9A24B),
    onEmerald: AppColors.onBrand,
    textHi: AppColors.dBone,
    textMid: AppColors.dMist,
    textLow: AppColors.dFaint,
    danger: AppColors.danger,
    dangerSoft: Color(0x22E5644E),
    isDark: true,
  );

  static const AppPalette light = AppPalette(
    background: AppColors.lPaper,
    surface: AppColors.lSurface,
    surfaceRaised: AppColors.lRaised,
    line: AppColors.lLine,
    emerald: AppColors.brandDeep,
    emeraldPressed: Color(0xFF0C8A64),
    emeraldSoft: Color(0x1A0E9E74), // ~10%
    gold: AppColors.goldLight,
    goldSoft: Color(0x1FA9822E),
    onEmerald: Colors.white,
    textHi: AppColors.lInk,
    textMid: AppColors.lSlate,
    textLow: AppColors.lFaint,
    danger: AppColors.dangerLight,
    dangerSoft: Color(0x1AC6472F),
    isDark: false,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? line,
    Color? emerald,
    Color? emeraldPressed,
    Color? emeraldSoft,
    Color? gold,
    Color? goldSoft,
    Color? onEmerald,
    Color? textHi,
    Color? textMid,
    Color? textLow,
    Color? danger,
    Color? dangerSoft,
    bool? isDark,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      line: line ?? this.line,
      emerald: emerald ?? this.emerald,
      emeraldPressed: emeraldPressed ?? this.emeraldPressed,
      emeraldSoft: emeraldSoft ?? this.emeraldSoft,
      gold: gold ?? this.gold,
      goldSoft: goldSoft ?? this.goldSoft,
      onEmerald: onEmerald ?? this.onEmerald,
      textHi: textHi ?? this.textHi,
      textMid: textMid ?? this.textMid,
      textLow: textLow ?? this.textLow,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      line: Color.lerp(line, other.line, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      emeraldPressed: Color.lerp(emeraldPressed, other.emeraldPressed, t)!,
      emeraldSoft: Color.lerp(emeraldSoft, other.emeraldSoft, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldSoft: Color.lerp(goldSoft, other.goldSoft, t)!,
      onEmerald: Color.lerp(onEmerald, other.onEmerald, t)!,
      textHi: Color.lerp(textHi, other.textHi, t)!,
      textMid: Color.lerp(textMid, other.textMid, t)!,
      textLow: Color.lerp(textLow, other.textLow, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

/// `context.palette` — the ergonomic way to read semantic colors.
extension AppPaletteX on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
