import 'package:in_app_review/in_app_review.dart';

/// Thin wrapper around the native "Rate Numberama" flow - Android's Play
/// In-App Review API, iOS/macOS's `SKStoreReviewController`. UI-independent,
/// same convention as `NotificationService`/`AudioService`, so both the
/// automatic prompt (see `PreferencesService.shouldShowRatePrompt`) and the
/// manual "Rate Numberama" settings row call straight into it.
class RateService {
  RateService._();

  static final RateService instance = RateService._();

  final InAppReview _review = InAppReview.instance;

  /// Requests the native in-app review flow if the platform reports it's
  /// available. Both platforms silently cap how often this can actually
  /// surface UI (Apple: at most 3 times per 365 days; Play: an opaque
  /// internal quota) - this only ever asks, it never guarantees a prompt
  /// actually appears.
  Future<void> requestReview() async {
    if (await _review.isAvailable()) {
      await _review.requestReview();
    }
  }
}
