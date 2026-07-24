import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// The real Hive box backing every durable value this app keeps locally -
/// opened once in `main()` (before [ProviderScope] is even built) and
/// injected via an override, since opening a box is inherently async but
/// every other provider in the app expects to read state synchronously.
final preferencesBoxProvider = Provider<Box>((ref) {
  throw UnimplementedError(
    'preferencesBoxProvider must be overridden in main() with an opened '
    'Hive box before the app is run.',
  );
});

final preferencesServiceProvider = Provider<PreferencesService>((ref) {
  return PreferencesService(ref.watch(preferencesBoxProvider));
});

/// Thin wrapper around a Hive [Box] for the handful of durable values this
/// app keeps locally. Centralizing key names here avoids typo'd string
/// literals scattered across the UI - as more get added (streak, ...) this
/// is where they'd live too.
class PreferencesService {
  PreferencesService(this._box);

  final Box _box;

  /// Name of the single box this service reads/writes - opened once in
  /// `main()` and handed in via [preferencesBoxProvider].
  static const boxName = 'numberama_prefs';

  static const _hasSeenHowToPlayKey = 'has_seen_how_to_play';
  static const _bestScoreKey = 'best_score';

  /// Whether the one-time "How to Play" dialog has already been shown.
  bool get hasSeenHowToPlay =>
      (_box.get(_hasSeenHowToPlayKey) as bool?) ?? false;

  Future<void> setHasSeenHowToPlay() =>
      _box.put(_hasSeenHowToPlayKey, true);

  /// The highest score ever reached across all rounds, `0` if none yet.
  int get bestScore => (_box.get(_bestScoreKey) as int?) ?? 0;

  /// Records [score] as the new best if it beats the current one. Returns
  /// whether it actually was a new best, so callers (the results screen)
  /// can show "NEW BEST" honestly instead of unconditionally.
  Future<bool> registerScore(int score) async {
    if (score <= bestScore) return false;
    await _box.put(_bestScoreKey, score);
    return true;
  }
}
