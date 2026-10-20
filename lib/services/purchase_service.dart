import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../state/analytics_service.dart';
import '../state/preferences_service.dart';

/// Outcome of [PurchaseService.restorePurchases], for the Settings screen's
/// "Restore Purchases" confirmation message.
enum RestoreResult { restored, notFound, unavailable }

/// Thin wrapper around `in_app_purchase` for the one product this app
/// sells - the "Remove Ads" non-consumable. Same singleton convention as
/// [RateService]/`AudioService`: reachable via [PurchaseService.instance]
/// without a Riverpod `ref`, since the purchase stream listener needs to be
/// alive for the whole app lifetime, not tied to any one widget's build.
///
/// Unlike those other singletons, this one does need to *write* a
/// preference (`PreferencesService.removeAdsPurchased`) from inside its own
/// async purchase-stream callback, where no `ref` is in scope - so
/// [initialize] takes the already-opened [PreferencesService] directly,
/// threaded in from `main()` the same way `NotificationService` already is.
class PurchaseService {
  PurchaseService._();

  static final PurchaseService instance = PurchaseService._();

  static const removeAdsProductId = 'remove_ads';

  /// How long [restorePurchases] waits for the store to report a restored
  /// purchase before concluding there isn't one - the store sends *no*
  /// stream event at all for an account that never bought anything.
  static const _restoreTimeout = Duration(seconds: 8);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  PreferencesService? _prefs;

  /// Set while a [restorePurchases] call is waiting on the purchase stream;
  /// completed `true` by [_onPurchaseUpdate] the moment "Remove Ads" comes
  /// back as restored/purchased.
  Completer<bool>? _restoreCompleter;

  final _purchaseErrors = StreamController<void>.broadcast();

  /// The "Remove Ads" product's price/metadata, or null until the store
  /// query returns. A [ValueListenable] so the Settings screen updates the
  /// moment it loads, even if it was opened first.
  final ValueNotifier<ProductDetails?> removeAdsProduct = ValueNotifier(null);

  /// Fires when a purchase attempt fails at the store (not when the player
  /// cancels it themselves) - Settings shows an error message for it.
  Stream<void> get purchaseErrors => _purchaseErrors.stream;

  /// Starts listening for purchase updates (so a restored purchase from a
  /// previous install is caught as soon as the store reports it) and loads
  /// [removeAdsProduct]'s price/metadata for the Settings screen. Called
  /// once from `main()`, deferred via `addPostFrameCallback` the same way
  /// `AdService.initialize` is - a store round-trip shouldn't block the
  /// first frame.
  Future<void> initialize(PreferencesService prefs) async {
    _prefs = prefs;
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
    );
    await loadProduct();
  }

  /// Queries [removeAdsProduct] if it hasn't loaded yet. Called by
  /// [initialize], and again whenever Settings opens - so a store that was
  /// unreachable at launch (offline, signed out) gets another chance
  /// instead of leaving "Remove Ads" disabled for the whole session.
  Future<void> loadProduct() async {
    if (removeAdsProduct.value != null) return;
    if (!await _iap.isAvailable()) return;
    final response = await _iap.queryProductDetails({removeAdsProductId});
    if (response.productDetails.isNotEmpty) {
      removeAdsProduct.value = response.productDetails.first;
    }
  }

  /// Starts the native purchase flow. A no-op if the product hasn't loaded
  /// yet (store unavailable, or [initialize]'s query hasn't returned) -
  /// callers should keep the "Remove Ads" row disabled until
  /// [removeAdsProduct] is non-null so this can't be tapped in that state.
  Future<void> buyRemoveAds() async {
    final product = removeAdsProduct.value;
    if (product == null) return;
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (_) {
      // e.g. StoreKit refusing a second buy while one is still pending.
      _purchaseErrors.add(null);
    }
  }

  /// Re-queries past purchases (App Store/Play account-linked, not
  /// device-linked). The restored purchase itself arrives later through
  /// [_onPurchaseUpdate], not as this call's result - so this waits on that
  /// stream (up to [_restoreTimeout]) before reporting the outcome.
  Future<RestoreResult> restorePurchases() async {
    if (_prefs == null || !await _iap.isAvailable()) {
      return RestoreResult.unavailable;
    }
    if (_prefs!.removeAdsPurchased) return RestoreResult.restored;

    final completer = _restoreCompleter ??= Completer<bool>();
    try {
      await _iap.restorePurchases();
    } catch (_) {
      if (identical(_restoreCompleter, completer)) _restoreCompleter = null;
      return RestoreResult.unavailable;
    }
    final found =
        await completer.future.timeout(_restoreTimeout, onTimeout: () => false);
    if (identical(_restoreCompleter, completer)) _restoreCompleter = null;
    return found ? RestoreResult.restored : RestoreResult.notFound;
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Not final yet (e.g. awaiting parental approval or a cash
          // payment) - the store sends another update once it settles.
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.productID == removeAdsProductId) {
            await _grantRemoveAds(purchase);
            final restore = _restoreCompleter;
            if (restore != null && !restore.isCompleted) restore.complete(true);
          }
        case PurchaseStatus.error:
          _purchaseErrors.add(null);
        case PurchaseStatus.canceled:
          // The player backed out of the store sheet - nothing to grant
          // and nothing to report.
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _grantRemoveAds(PurchaseDetails purchase) async {
    final prefs = _prefs;
    if (prefs == null || prefs.removeAdsPurchased) return;
    await prefs.setRemoveAdsPurchased(true);
    // Only log revenue for a fresh buy - a restore is a purchase that was
    // already counted on the device it was originally made on.
    if (purchase.status != PurchaseStatus.purchased) return;
    final product = removeAdsProduct.value;
    await AnalyticsService.instance.logIapPurchase(
      productId: purchase.productID,
      value: product?.rawPrice ?? 0,
      currency: product?.currencyCode ?? 'USD',
    );
  }

  void dispose() {
    _subscription?.cancel();
    _purchaseErrors.close();
  }
}
