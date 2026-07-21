import 'package:flutter/material.dart';

/// Single source of truth for every color used across the app - both
/// Flutter widgets (via [AppTheme]) and Flame components, which can't read
/// `Theme.of(context)` and import this class directly instead. No hex
/// literals should appear anywhere outside this file.
class AppColors {
  AppColors._();

  // Backgrounds.
  static const Color bgDeep = Color(0xFF0D1024);
  static const Color bgNavy = Color(0xFF161B36);
  static const Color surface = Color(0xFF1F2547);
  static const Color surfaceRaised = Color(0xFF272E56);
  static const Color gridLine = Color(0x0BFFFFFF);

  // Accents.
  static const Color amber = Color(0xFFFFB84D);
  static const Color amberDeep = Color(0xFFE89A2C);
  static const Color teal = Color(0xFF33D9C2);
  static const Color tealDeep = Color(0xFF22B5A1);
  static const Color coral = Color(0xFFFF6B6A);

  /// Near-black label color for text sitting directly on [amber]/[amberDeep]
  /// gradients, where [bgNavy] doesn't have enough contrast.
  static const Color onAmber = Color(0xFF241705);

  // Text.
  static const Color textHi = Color(0xFFF5F1E6);
  static const Color textMid = Color(0xFFABB1D6);
  static const Color textLow = Color(0xFF656B93);
}
