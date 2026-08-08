import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';
import '../state/preferences_service.dart';

/// A fixed, compact (320x50) banner ad - collapses to nothing (zero height,
/// no reserved space) while purchased-out ([PreferencesService.
/// removeAdsPurchased]) or before the ad has actually loaded, so it never
/// leaves a blank gap in whatever layout it's dropped into. Deliberately the
/// classic standard size rather than an adaptive one - Google's current,
/// non-deprecated adaptive API (`getLargeAnchoredAdaptiveBannerAdSize`)
/// scales up to 15% of screen height, which read as oversized against this
/// game's compact UI. Unlike the interstitial/rewarded ads in [AdService],
/// a banner's lifecycle is tied to wherever it's mounted - each instance
/// loads its own [BannerAd] in [initState] and disposes it in [dispose],
/// rather than being preloaded and reused.
class AdBannerWidget extends ConsumerStatefulWidget {
  const AdBannerWidget({super.key});

  @override
  ConsumerState<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends ConsumerState<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _requested = false;

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBanner() async {
    // The Home screen is the very first thing built at cold start, often
    // before `main()`'s (deliberately un-awaited) `AdService.initialize()`
    // has actually finished - requesting a banner before the Mobile Ads SDK
    // itself is ready just fails silently (onAdFailedToLoad, no retry).
    // Awaiting the same memoized future here is cheap once init has already
    // completed (e.g. on the Results screen, reached well after) and
    // otherwise waits out the real race on Home.
    await AdService.instance.initialize();
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _bannerAd = ad as BannerAd);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    // Same "react to a write from anywhere" pattern as the home/results
    // screens' best-score cards - a purchase completing elsewhere in the
    // app (Settings' "Remove Ads" row, once wired up) should collapse this
    // widget immediately, not just on this screen's next fresh mount.
    ref.watch(preferencesRevisionProvider);
    final removeAdsPurchased =
        ref.watch(preferencesServiceProvider).removeAdsPurchased;
    if (removeAdsPurchased) return const SizedBox.shrink();

    if (!_requested) {
      _requested = true;
      _loadBanner();
    }

    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
