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
  static const _dailyPlayedHistoryKey = 'daily_played_history';
  static const _currentStreakKey = 'current_streak';
  static const _classicRoundsPlayedKey = 'classic_rounds_played';
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

  List<String> get _dailyPlayedHistory =>
      (_box.get(_dailyPlayedHistoryKey) as List?)?.cast<String>() ?? const [];

  /// Whether [date]'s calendar day has ever been played, per full history -
  /// unlike [hasPlayedDailyOn] (which only gates *today's* one attempt),
  /// this is what the calendar strip's per-day checkmarks are driven from.
  bool hasEverPlayedDailyOn(DateTime date) =>
      _dailyPlayedHistory.contains(_dateKey(date));

  /// Consecutive calendar days the Daily Challenge has been played, `0` if
  /// none yet. Win or loss both keep it alive, matching [hasPlayedDailyOn]
  /// - it's a "showed up" streak, not a "won" streak.
  int get currentStreak => (_box.get(_currentStreakKey) as int?) ?? 0;

  /// Records [date]'s calendar day as the daily round just played, so
  /// [hasPlayedDailyOn] locks out a retry for the rest of that day, and
  /// updates [currentStreak]: incremented if [date] is the calendar day
  /// right after the last played date, restarted at 1 if a day was
  /// skipped (or this is the first daily round ever). A repeat call for a
  /// date already recorded as played is a no-op, so this stays safe to
  /// call more than once for the same day.
  ///
  /// Returns whether [date] actually extended the streak by one (a
  /// consecutive day) - `false` if a day was skipped and the streak
  /// restarted at 1, or if [date] was already recorded. The results
  /// screen uses this to show its "+1" streak badge only when it's true,
  /// rather than unconditionally.
  bool registerDailyPlayed(DateTime date) {
    final todayKey = _dateKey(date);
    final previousKey = _box.get(_lastDailyPlayedDateKey) as String?;
    if (previousKey == todayKey) return false;

    final yesterdayKey = _dateKey(date.subtract(const Duration(days: 1)));
    final isConsecutive = previousKey == yesterdayKey;
    _box.put(_currentStreakKey, isConsecutive ? currentStreak + 1 : 1);
    _box.put(_lastDailyPlayedDateKey, todayKey);

    final history = _dailyPlayedHistory;
    if (!history.contains(todayKey)) {
      _box.put(_dailyPlayedHistoryKey, [...history, todayKey]);
    }
    return isConsecutive;
  }

  /// Total Classic rounds played (win or loss), `0` if none yet. Classic
  /// has no daily puzzle index of its own, unlike the Daily Challenge -
  /// the results screen's share card uses this as a Wordle-style round
  /// number ("Numberama #N") instead of a hardcoded placeholder.
  int get classicRoundsPlayed =>
      (_box.get(_classicRoundsPlayedKey) as int?) ?? 0;

  /// Records another Classic round as played and returns the new count,
  /// synchronously - mirrors [registerDailyPlayed]'s pattern so the
  /// results screen can use the just-incremented number immediately.
  int registerClassicRoundPlayed() {
    final next = classicRoundsPlayed + 1;
    _box.put(_classicRoundsPlayedKey, next);
    return next;
  }

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

  /// Wipes every durable value this app keeps locally - score, daily-played
  /// gate, daily play history, streak, Classic round count, and every
  /// setting above - back to first-launch defaults. Used by Settings'
  /// "Reset Progress" action.
  Future<void> clearAll() => _box.clear();
}
