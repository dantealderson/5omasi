import 'package:flutter/material.dart';
import 'package:admin/theme/app_colors.dart';
import 'package:admin/theme/app_text.dart';

/// Builds the Midnight Club [ThemeData] for both brightnesses from a single
/// [AppPalette]. Components read semantic colors via `context.palette`; the
/// standard Material widgets pick these up automatically.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static const double radiusCard = 18;
  static const double radiusButton = 14;
  static const double radiusField = 14;

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final textTheme = AppText.textTheme(p);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.emerald,
      brightness: brightness,
    ).copyWith(
      primary: p.emerald,
      onPrimary: p.onEmerald,
      secondary: p.gold,
      onSecondary: p.isDark ? AppColors.onBrand : Colors.white,
      surface: p.surface,
      onSurface: p.textHi,
      error: p.danger,
      onError: Colors.white,
      outline: p.line,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppText.body,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryColor: p.emerald,
      splashFactory: InkRipple.splashFactory,
      dividerColor: p.line,
      extensions: [p],

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textHi,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.kufi(size: 22, weight: 700, color: p.textHi),
        iconTheme: IconThemeData(color: p.textHi),
      ),

      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: p.line),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: p.line,
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: p.textMid),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.emerald,
          foregroundColor: p.onEmerald,
          disabledBackgroundColor: p.surfaceRaised,
          disabledForegroundColor: p.textLow,
          elevation: 0,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.emerald,
          textStyle: textTheme.labelLarge,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textHi,
          side: BorderSide(color: p.line),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        hintStyle: TextStyle(fontFamily: AppText.body, color: p.textLow),
        prefixIconColor: p.textMid,
        suffixIconColor: p.textMid,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: p.emerald, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: p.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: p.danger, width: 1.6),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.emeraldSoft,
        elevation: 0,
        height: 66,
        surfaceTintColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? p.emerald : p.textLow,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: AppText.body,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? p.emerald : p.textLow,
          );
        }),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.emerald,
        unselectedLabelColor: p.textMid,
        indicatorColor: p.emerald,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: const TextStyle(
          fontFamily: AppText.body,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: AppText.body,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceRaised,
        selectedColor: p.emeraldSoft,
        checkmarkColor: p.emerald,
        side: BorderSide(color: p.line),
        labelStyle: TextStyle(
          fontFamily: AppText.body,
          color: p.textMid,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppText.body,
          color: p.emerald,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.emerald,
        linearTrackColor: p.surfaceRaised,
        circularTrackColor: p.surfaceRaised,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.emerald,
        foregroundColor: p.onEmerald,
        elevation: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.onEmerald : p.textMid),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? p.emerald
                : p.surfaceRaised),
        trackOutlineColor: WidgetStateProperty.all(p.line),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(fontFamily: AppText.body, color: p.textHi),
        actionTextColor: p.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: p.line),
        ),
        titleTextStyle: AppText.kufi(size: 20, weight: 600, color: p.textHi),
        contentTextStyle: TextStyle(
          fontFamily: AppText.body,
          color: p.textMid,
          fontSize: 14,
          height: 1.45,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: p.line),
        ),
      ),
    );
  }
}
