import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../state/analytics_service.dart';
import '../state/preferences_service.dart';

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

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  PreferencesService? _prefs;
  ProductDetails? _removeAdsProduct;

  ProductDetails? get removeAdsProduct => _removeAdsProduct;

  /// Starts listening for purchase updates (so a restored purchase from a
  /// previous install is caught as soon as the store reports it) and loads
  /// [removeAdsProduct]'s price/metadata for the Settings screen. Called
  /// once from `main()`, deferred via `addPostFrameCallback` the same way
  /// `AdService.initialize` is - a store round-trip shouldn't block the
  /// first frame.
  Future<void> initialize(PreferencesService prefs) async {
    _prefs = prefs;
    if (!await _iap.isAvailable()) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
    );

    final response = await _iap.queryProductDetails({removeAdsProductId});
    if (response.productDetails.isNotEmpty) {
      _removeAdsProduct = response.productDetails.first;
    }
  }

  /// Starts the native purchase flow. A no-op if the product hasn't loaded
  /// yet (store unavailable, or [initialize]'s query hasn't returned) -
  /// callers should keep the "Remove Ads" row disabled until
  /// [removeAdsProduct] is non-null so this can't be tapped in that state.
  Future<void> buyRemoveAds() async {
    final product = _removeAdsProduct;
    if (product == null) return;
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// Re-queries past purchases (App Store/Play account-linked, not
  /// device-linked) - the result arrives through the same [_onPurchaseUpdate]
  /// stream as a fresh buy, with [PurchaseDetails.status] restored rather
  /// than purchased.
  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.status == PurchaseStatus.error) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      // Purchased or restored - both mean "grant it".
      if (purchase.productID == removeAdsProductId) {
        await _grantRemoveAds(purchase);
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
    final product = _removeAdsProduct;
    await AnalyticsService.instance.logIapPurchase(
      productId: purchase.productID,
      value: product?.rawPrice ?? 0,
      currency: product?.currencyCode ?? 'USD',
    );
  }

  void dispose() => _subscription?.cancel();
}
