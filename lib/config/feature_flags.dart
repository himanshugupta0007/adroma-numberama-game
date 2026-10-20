/// Compile-time feature switches, set per build with `--dart-define`.
class FeatureFlags {
  const FeatureFlags._();

  /// The "Remove Ads" in-app purchase. Off by default while we track player
  /// behavior with ads only; build with `--dart-define=IAP_ENABLED=true` to
  /// bring back the Remove Ads / Restore Purchases rows and the purchase
  /// service. Players who already own Remove Ads still see no ads either
  /// way - that's gated on [PreferencesService.removeAdsPurchased], not this.
  static const bool iapEnabled =
      bool.fromEnvironment('IAP_ENABLED', defaultValue: false);
}
