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
  static const _lastDailyPlayedDateKey = 'last_daily_played_date';
  static const _soundEnabledKey = 'sound_enabled';
  static const _hapticsEnabledKey = 'haptics_enabled';
  static const _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const _reduceMotionEnabledKey = 'reduce_motion_enabled';
  static const _colorblindPaletteEnabledKey = 'colorblind_palette_enabled';

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

  /// Whether the Daily Challenge board for [date]'s calendar day has
  /// already been played - win or loss both count, there's only one
  /// attempt per day, Wordle-style.
  bool hasPlayedDailyOn(DateTime date) =>
      _box.get(_lastDailyPlayedDateKey) == _dateKey(date);

  /// Records [date]'s calendar day as the daily round just played, so
  /// [hasPlayedDailyOn] locks out a retry for the rest of that day.
  Future<void> registerDailyPlayed(DateTime date) =>
      _box.put(_lastDailyPlayedDateKey, _dateKey(date));

  /// A calendar-day key (not wall-clock time) - two calls on the same date
  /// always compare equal regardless of what time of day each was made.
  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool get soundEnabled => (_box.get(_soundEnabledKey) as bool?) ?? true;
  Future<void> setSoundEnabled(bool value) => _box.put(_soundEnabledKey, value);

  bool get hapticsEnabled => (_box.get(_hapticsEnabledKey) as bool?) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _box.put(_hapticsEnabledKey, value);

  bool get dailyReminderEnabled =>
      (_box.get(_dailyReminderEnabledKey) as bool?) ?? false;
  Future<void> setDailyReminderEnabled(bool value) =>
      _box.put(_dailyReminderEnabledKey, value);

  bool get reduceMotionEnabled =>
      (_box.get(_reduceMotionEnabledKey) as bool?) ?? false;
  Future<void> setReduceMotionEnabled(bool value) =>
      _box.put(_reduceMotionEnabledKey, value);

  bool get colorblindPaletteEnabled =>
      (_box.get(_colorblindPaletteEnabledKey) as bool?) ?? false;
  Future<void> setColorblindPaletteEnabled(bool value) =>
      _box.put(_colorblindPaletteEnabledKey, value);

  /// Wipes every durable value this app keeps locally - score, streak gate,
  /// and every setting above - back to first-launch defaults. Used by
  /// Settings' "Reset Progress" action.
  Future<void> clearAll() => _box.clear();
}
