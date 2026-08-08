import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../state/analytics_service.dart';

/// Thin wrapper around the AdMob SDK - GDPR/UMP consent gathering, plus
/// preloading and showing interstitial and rewarded ads. Same singleton
/// convention as [RateService]/[AudioService]: reachable via [AdService.
/// instance] without a Riverpod `ref`, since an ad's load/show lifecycle
/// isn't tied to any one widget's build. Banner ads aren't handled here -
/// see `AdBannerWidget`, which owns its own [BannerAd] tied to its widget
/// lifecycle instead, but still awaits [initialize] first (see that doc)
/// before requesting one.
///
/// Every ad unit ID below is Google's published *test* ID, safe to request
/// against during development - they always serve real (if generic) test
/// creatives, never real spend. Before release, swap these for the real
/// ad unit IDs from the AdMob console, alongside the app-level test App IDs
/// already flagged in `AndroidManifest.xml`/`Info.plist`.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  Future<void>? _initFuture;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  static String get bannerAdUnitId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';

  static String get _interstitialAdUnitId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  static String get _rewardedAdUnitId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  /// Gathers GDPR/UMP consent (showing the consent form if the player's
  /// region requires it), initializes the Mobile Ads SDK, and starts
  /// preloading one interstitial and one rewarded ad so the first "Play
  /// again"/power-up moment doesn't have to wait on a fresh network
  /// request. Called once from `main()`, before the app's first frame - not
  /// awaited there, so a slow/offline consent round-trip doesn't delay the
  /// app's first frame.
  ///
  /// Memoized: every caller (including a second call from `main()` on a hot
  /// restart, or [AdBannerWidget] awaiting readiness before its first ad
  /// request) shares the same underlying future rather than kicking off a
  /// redundant init - the Mobile Ads SDK only actually initializes once.
  Future<void> initialize() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    await _gatherConsent();
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  /// Requests the player's current consent state from Google's UMP SDK and
  /// shows the consent form if (and only if) their region requires one
  /// (EEA/UK, per GDPR). Resolves once that's settled either way - consent
  /// granted/not required, or the info request itself failed (e.g. no
  /// network at first launch), in which case ad loading proceeds anyway
  /// using whatever consent state, if any, was cached from a prior session.
  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!completer.isCompleted) completer.complete();
      },
      (_) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Re-opens the consent form's "privacy options" entry point - the
  /// Settings screen's "Manage Ad Preferences" row, which GDPR requires
  /// stays reachable for as long as a player's region required a consent
  /// form in the first place. A no-op if their region never required one
  /// (the row is deliberately left visible either way, rather than only
  /// appearing for EEA/UK players).
  Future<void> showPrivacyOptionsForm() async {
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    if (status != PrivacyOptionsRequirementStatus.required) return;
    final completer = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (_) =>
                AnalyticsService.instance.logAdShown('interstitial'),
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  /// Whether a preloaded interstitial is ready to show right now - call
  /// sites use this to decide *whether* to interrupt the player at all
  /// (e.g. skip it silently rather than block "Play again" on a slow load).
  bool get isInterstitialReady => _interstitialAd != null;

  /// Shows the preloaded interstitial, if one's ready, and starts loading
  /// the next one behind it either way. Returns `false` immediately with
  /// nothing shown if none is ready yet (e.g. right after a fresh install,
  /// before the first preload finishes) - callers should treat that as
  /// "skip the ad", not retry in a loop.
  bool showInterstitial() {
    final ad = _interstitialAd;
    if (ad == null) return false;
    _interstitialAd = null;
    ad.show();
    return true;
  }

  /// Fired once the currently-showing rewarded ad's full-screen content
  /// actually closes (dismissed by the player, or failed to show at all) -
  /// see [showRewarded]'s `onAdClosed`. Set fresh by every [showRewarded]
  /// call and cleared the moment it fires, since [fullScreenContentCallback]
  /// is wired once per *loaded ad instance* (in [_loadRewardedAd]) rather
  /// than per show call.
  void Function()? _onRewardedAdClosed;

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (_) =>
                AnalyticsService.instance.logAdShown('rewarded'),
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
              _onRewardedAdClosed?.call();
              _onRewardedAdClosed = null;
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
              _onRewardedAdClosed?.call();
              _onRewardedAdClosed = null;
            },
          );
        },
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }

  /// Whether a preloaded rewarded ad is ready to show right now - the power
  /// bar uses this to decide whether tapping an ad-gated slot can offer a
  /// watch at all.
  bool get isRewardedReady => _rewardedAd != null;

  /// Shows the preloaded rewarded ad, if one's ready, and starts loading
  /// the next one behind it either way. [onUserEarnedReward] only fires
  /// once the player watches to completion - closing or skipping early
  /// grants nothing, so call sites must gate the actual power-up on this
  /// callback firing, never on [showRewarded]'s return value alone (that
  /// only reports whether an ad was shown, not whether it was watched).
  /// [onAdClosed], if given, fires once the ad's full-screen content is
  /// gone - reward earned or not, closed normally or failed to show - so a
  /// caller that paused something (the Flame game engine, in [PowerBar])
  /// before calling this can reliably resume it exactly once. Returns
  /// `false` immediately with nothing shown if no ad is ready yet - in that
  /// case [onAdClosed] never fires, since nothing was ever shown to close.
  bool showRewarded({
    required void Function() onUserEarnedReward,
    void Function()? onAdClosed,
  }) {
    final ad = _rewardedAd;
    if (ad == null) return false;
    _rewardedAd = null;
    _onRewardedAdClosed = onAdClosed;
    ad.show(
      onUserEarnedReward: (_, __) => onUserEarnedReward(),
    );
    return true;
  }
}
