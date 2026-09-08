/// App-wide feature switches that aren't tied to a single player's device,
/// unlike [PreferencesService] settings - these are compiled into the build
/// itself and apply to every install.
class AppConfig {
  const AppConfig._();

  /// Master switch for AdMob and the "Remove Ads" in-app purchase. Off for
  /// the initial public launch (no ads, no purchase flow); flip to `true`
  /// once the store listing and ad units are ready to go live.
  ///
  /// When `false`: [AdService] and [PurchaseService] are never initialized,
  /// every ad call site short-circuits to its free/granted outcome (see
  /// [PreferencesService.removeAdsPurchased]), and the "Purchases & Ads"
  /// section is hidden from Settings.
  static const bool adsAndPurchasesEnabled = false;
}
