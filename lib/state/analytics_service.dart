import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around this app's handful of custom Firebase Analytics
/// events. Framework-agnostic (no Flame/widget imports) so it can be called
/// from both Flame components (e.g. [SelectionManager]) and Flutter widgets
/// alike - same shape as [AudioService], and for the same reason: a plain
/// singleton reachable without a Riverpod `ref`, plus [analyticsServiceProvider]
/// for call sites that do have one.
///
/// `session_start` and (once AdMob is linked to Firebase in the console)
/// `ad_impression` are both collected automatically the moment Firebase
/// Analytics initializes - neither needs a method here.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// A Classic or Rush round was started.
  Future<void> logModePlayed(String mode) =>
      _analytics.logEvent(name: 'mode_played', parameters: {'mode': mode});

  /// A Daily Challenge round ended (win or loss), after the streak has
  /// already been updated - callers should read the fresh streak value and
  /// pass it here, not the pre-round one.
  Future<void> logDailyChallengeComplete({
    required int streak,
    required int score,
    required bool success,
  }) =>
      _analytics.logEvent(
        name: 'daily_challenge_complete',
        parameters: {
          'streak': streak,
          'score': score,
          'success': success,
        },
      );

  /// An in-app purchase was verified (not the initial "pending" state).
  Future<void> logIapPurchase({
    required String productId,
    required double value,
    required String currency,
  }) =>
      _analytics.logPurchase(
        currency: currency,
        value: value,
        items: [AnalyticsEventItem(itemId: productId)],
      );

  /// An ad was actually shown - only needed if not relying on the
  /// AdMob-linked `ad_impression` event for this ad type.
  Future<void> logAdShown(String adType) =>
      _analytics.logEvent(name: 'ad_shown', parameters: {'ad_type': adType});
}

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService.instance;
});
