import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Single source of truth for every text style used across the app. No raw
/// `TextStyle()` calls should appear anywhere outside this file - build on
/// [display] or [mono], or use one of the named presets below.
class AppTextStyles {
  AppTextStyles._();

  /// Headings, wordmark, buttons, general body UI.
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.textHi,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  /// Tile digits, scores, timers, HUD numbers, eyebrow/caption labels.
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.amber,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.08,
    );
  }

  static final TextStyle scoreDisplay = mono(32, color: AppColors.textHi);
  static final TextStyle tileDigit = mono(13, color: AppColors.textMid);
  static final TextStyle tileDigitSelected = mono(13, color: AppColors.bgNavy);
  static final TextStyle heading = display(20);
  static final TextStyle caption = mono(
    10,
    weight: FontWeight.w600,
    color: AppColors.textLow,
  );
}
