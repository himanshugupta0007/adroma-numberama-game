import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Wires [AppColors] and [AppTextStyles] into a Material [ThemeData].
///
/// The primary CTA (amber→amberDeep gradient) isn't expressible through
/// [ButtonStyle] and lives in [GradientButton] instead - the
/// [elevatedButtonTheme] here is the flat "ghost"/secondary button style
/// (transparent background, subtle border).
class AppTheme {
  AppTheme._();

  static const _borderRadius = 12.0;
  static const _ghostBorderColor = Color(0x24FFFFFF); // rgba(255,255,255,0.14)

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.amber,
      brightness: Brightness.dark,
      primary: AppColors.amber,
      secondary: AppColors.teal,
      surface: AppColors.surface,
      error: AppColors.coral,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.bgNavy,
      textTheme: _textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textHi,
          shadowColor: Colors.transparent,
          elevation: 0,
          side: const BorderSide(color: _ghostBorderColor, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
          textStyle: AppTextStyles.display(14, weight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static TextTheme get _textTheme => TextTheme(
        displayLarge: AppTextStyles.display(57),
        displayMedium: AppTextStyles.display(45),
        displaySmall: AppTextStyles.display(36),
        headlineLarge: AppTextStyles.display(32),
        headlineMedium: AppTextStyles.display(28),
        headlineSmall: AppTextStyles.display(24),
        titleLarge: AppTextStyles.display(22),
        titleMedium: AppTextStyles.display(16, weight: FontWeight.w600),
        titleSmall: AppTextStyles.display(14, weight: FontWeight.w600),
        bodyLarge: AppTextStyles.display(16, weight: FontWeight.w400),
        bodyMedium: AppTextStyles.display(14, weight: FontWeight.w400),
        bodySmall: AppTextStyles.display(12, weight: FontWeight.w400),
        labelLarge: AppTextStyles.display(14, weight: FontWeight.w600),
        labelMedium: AppTextStyles.display(12, weight: FontWeight.w600),
        labelSmall: AppTextStyles.display(11, weight: FontWeight.w600),
      );
}
