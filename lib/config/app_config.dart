import 'package:flutter/foundation.dart';

/// App-wide feature switches that aren't tied to a single player's device,
/// unlike [PreferencesService] settings - these are compiled into the build
/// itself and apply to every install.
class AppConfig {
  const AppConfig._();

  /// Master switch for AdMob. On for Android only - iOS has no real ad units
  /// yet, so it keeps shipping ad-free until those are set up. The "Remove
  /// Ads" purchase has its own switch on top of this,
  /// `FeatureFlags.iapEnabled`.
  ///
  /// When `false`: [AdService] and [PurchaseService] are never initialized,
  /// every ad call site short-circuits to its free/granted outcome (see
  /// [PreferencesService.removeAdsPurchased]), and the "Purchases & Ads"
  /// section is hidden from Settings.
  static bool get adsEnabled =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
