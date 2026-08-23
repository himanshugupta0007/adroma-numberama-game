import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'difficulty.dart';
import 'player_progress.dart';

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

/// Ticks on every write to the preferences box - a `put` from any
/// [PreferencesService] method, or every key at once from [clearAll]
/// (Hive's `clear()` emits a deletion event per key, same as [Box.watch]
/// does for an individual delete). [PreferencesService]'s own getters are
/// synchronous, plain reads with no Riverpod state of their own to
/// invalidate - a screen that only ever mutates what it itself displays
/// (e.g. Settings' toggles, via [SettingsStateNotifier]) doesn't need
/// this, since its own rebuild already happens through that state. But a
/// screen showing a value that can change *outside* its own widget tree -
/// the home screen's best-score cards after a round played on the
/// gameplay screen, or after Settings' "Reset Progress" wipes them - has
/// nothing else to trigger its rebuild, so it should `ref.watch` this
/// alongside reading [preferencesServiceProvider].
final preferencesRevisionProvider = StreamProvider<void>((ref) {
  final box = ref.watch(preferencesBoxProvider);
  return box.watch().map((_) {});
});

/// Thin wrapper around a Hive [Box] for the handful of durable values this
/// app keeps locally. Centralizing key names here avoids typo'd string
/// literals scattered across the UI - as more get added (streak, ...) this
/// is where they'd live too.
///
/// This is also the app's one seam for a future cloud backend, so two
/// invariants matter beyond just "don't typo the key string":
///  1. Every score/streak/progress read or write goes through a method
///     here - nothing outside this file (or [preferencesServiceProvider])
///     touches [Box] or [Hive] directly. `grep`-checked: `package:hive` is
///     only imported here and in `main.dart` (which just opens the box).
///  2. Every value this class stores is a plain JSON-primitive - `int`,
///     `bool`, `String`, `List<String>` - and dates are already-formatted
///     period-key strings (`_dateKey`/`_monthKey`/`_yearKey`), never a raw
///     [DateTime]. That shape maps directly onto a cloud document's
///     fields with no translation layer.
///
/// When a cloud backend actually arrives, the lowest-friction shape is to
/// keep this class's public API exactly as-is (so no call site changes)
/// and treat Hive as a local cache: writes here also queue a push to the
/// cloud, and a separate sync layer pulls remote changes back into the
/// same Hive keys. That keeps every getter synchronous, which is the
/// entire reason UI code can call them straight from `build()` without
/// dealing with `Future`s or `AsyncValue`s - a directly cloud-backed
/// version of this class would have to give that up.
class PreferencesService {
  PreferencesService(this._box);

  final Box _box;

  /// Name of the single box this service reads/writes - opened once in
  /// `main()` and handed in via [preferencesBoxProvider].
  static const boxName = 'numberama_prefs';

  static const _hasSeenHowToPlayKey = 'has_seen_how_to_play';
  static const _bestScoreKey = 'best_score';
  static const _todayBestScoreKey = 'today_best_score';
  static const _todayBestScorePeriodKey = 'today_best_score_period';
  static const _monthBestScoreKey = 'month_best_score';
  static const _monthBestScorePeriodKey = 'month_best_score_period';
  static const _yearBestScoreKey = 'year_best_score';
  static const _yearBestScorePeriodKey = 'year_best_score_period';
  static const _lastDailyPlayedDateKey = 'last_daily_played_date';
  static const _dailyPlayedHistoryKey = 'daily_played_history';
  static const _lastDailyPlayedCycleKey = 'last_daily_played_cycle';
  static const _currentStreakKey = 'current_streak';
  static const _classicRoundsPlayedKey = 'classic_rounds_played';
  static const _soundEnabledKey = 'sound_enabled';
  static const _hapticsEnabledKey = 'haptics_enabled';
  static const _dailyReminderEnabledKey = 'daily_reminder_enabled';
  static const _reduceMotionEnabledKey = 'reduce_motion_enabled';
  static const _appOpenCountKey = 'app_open_count';
  static const _hasRatedKey = 'has_rated';
  static const _lastRatePromptDateKey = 'last_rate_prompt_date';
  static const _removeAdsPurchasedKey = 'remove_ads_purchased';
  static const _playerIdKey = 'player_id';
  static const _totalXpKey = 'total_xp';

  /// Whether the one-time "How to Play" dialog has already been shown.
  bool get hasSeenHowToPlay =>
      (_box.get(_hasSeenHowToPlayKey) as bool?) ?? false;

  Future<void> setHasSeenHowToPlay() =>
      _box.put(_hasSeenHowToPlayKey, true);

  /// The highest score ever reached across all rounds (Classic and Daily
  /// combined), `0` if none yet - "BEST EVER" on the home screen.
  int get bestScore => (_box.get(_bestScoreKey) as int?) ?? 0;

  /// Highest score reached today, `0` if none yet - see [_periodBest].
  int get todayBestScore => _periodBest(
        _todayBestScoreKey,
        _todayBestScorePeriodKey,
        _dateKey(DateTime.now()),
      );

  /// Highest score reached this calendar month, `0` if none yet - see
  /// [_periodBest].
  int get monthBestScore => _periodBest(
        _monthBestScoreKey,
        _monthBestScorePeriodKey,
        _monthKey(DateTime.now()),
      );

  /// Highest score reached this calendar year, `0` if none yet - see
  /// [_periodBest].
  int get yearBestScore => _periodBest(
        _yearBestScoreKey,
        _yearBestScorePeriodKey,
        _yearKey(DateTime.now()),
      );

  /// Reads a period-bucketed best: the value stored at [scoreKey] only
  /// counts if [periodKey] (stored at [periodKeyKey]) still matches
  /// [currentPeriodKey] - otherwise the bucket has rolled over (a new
  /// day/month/year started) and reads as `0`. Rollover is entirely
  /// lazy - nothing needs to run when a period actually turns over, since
  /// every read already recomputes "is the stored bucket still current".
  int _periodBest(String scoreKey, String periodKeyKey, String currentPeriodKey) {
    if ((_box.get(periodKeyKey) as String?) != currentPeriodKey) return 0;
    return (_box.get(scoreKey) as int?) ?? 0;
  }

  /// Records [score] from a just-finished round (Classic and Daily both
  /// feed the same buckets) against every best-score bucket this app
  /// tracks - all-time, and whichever day/month/year [date] (defaults to
  /// now) falls in. Returns whether [score] set a new all-time best, so
  /// callers (the results screen) can show "NEW BEST" honestly.
  bool registerRoundScore(int score, {DateTime? date}) {
    final now = date ?? DateTime.now();
    final isNewBest = score > bestScore;
    if (isNewBest) _box.put(_bestScoreKey, score);
    _updatePeriodBest(
        _todayBestScoreKey, _todayBestScorePeriodKey, _dateKey(now), score);
    _updatePeriodBest(
        _monthBestScoreKey, _monthBestScorePeriodKey, _monthKey(now), score);
    _updatePeriodBest(
        _yearBestScoreKey, _yearBestScorePeriodKey, _yearKey(now), score);
    return isNewBest;
  }

  /// Bumps a period bucket to [score] if it beats whatever's currently
  /// stored for [periodKey] (per [_periodBest] - a stale, rolled-over
  /// bucket reads as `0`, so the first score of a new period always
  /// qualifies). A no-op otherwise, including when the period has simply
  /// rolled over with nothing to record yet - the next [_periodBest] read
  /// already resolves that correctly without a write here.
  void _updatePeriodBest(
    String scoreKey,
    String periodKeyKey,
    String periodKey,
    int score,
  ) {
    if (score <= _periodBest(scoreKey, periodKeyKey, periodKey)) return;
    _box.put(scoreKey, score);
    _box.put(periodKeyKey, periodKey);
  }

  /// Whether the Daily Challenge board for [date]'s calendar day has
  /// already been played - win or loss both count. Superseded as the
  /// player-facing replay gate by [hasPlayedCurrentDailyCycle] (the board
  /// now resets every [dailyCycleDuration], not once per calendar day);
  /// this stays purely as an input to the calendar-day [currentStreak] via
  /// [registerDailyPlayed].
  bool hasPlayedDailyOn(DateTime date) =>
      _box.get(_lastDailyPlayedDateKey) == _dateKey(date);

  /// Whether the Daily Challenge board for [time]'s [dailyCycleIndex] has
  /// already been played - win or loss both count, there's only one
  /// attempt per cycle, Wordle-style. This is the actual replay gate the
  /// Daily screen shows/hides its start button on; [currentStreak] stays
  /// calendar-day based (see [registerDailyPlayed]) and is unaffected by
  /// how many cycles land within one day.
  bool hasPlayedCurrentDailyCycle(DateTime time) =>
      _box.get(_lastDailyPlayedCycleKey) == dailyCycleIndex(time);

  /// Records [time]'s cycle as played, so [hasPlayedCurrentDailyCycle]
  /// locks out a retry until the next cycle unlocks.
  void registerDailyCyclePlayed(DateTime time) =>
      _box.put(_lastDailyPlayedCycleKey, dailyCycleIndex(time));

  /// How long until [hasPlayedCurrentDailyCycle] unlocks again for [time],
  /// or [Duration.zero] if it's already unlocked (no round played this
  /// cycle, or none ever played).
  Duration timeUntilNextDailyCycle(DateTime time) {
    final lastCycle = _box.get(_lastDailyPlayedCycleKey) as int?;
    if (lastCycle == null || lastCycle != dailyCycleIndex(time)) {
      return Duration.zero;
    }
    final remaining = dailyCycleUnlockTime(lastCycle).difference(time);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  List<String> get _dailyPlayedHistory =>
      (_box.get(_dailyPlayedHistoryKey) as List?)?.cast<String>() ?? const [];

  /// Whether [date]'s calendar day has ever been played, per full history -
  /// this is what the calendar strip's per-day checkmarks are driven from
  /// (the replay gate itself is [hasPlayedCurrentDailyCycle]).
  bool hasEverPlayedDailyOn(DateTime date) =>
      _dailyPlayedHistory.contains(_dateKey(date));

  /// Consecutive calendar days the Daily Challenge has been played, `0` if
  /// none yet. Win or loss both keep it alive - it's a "showed up" streak,
  /// not a "won" streak. Deliberately still calendar-day based (not
  /// [dailyCycleIndex] based) even though the replay gate itself
  /// ([hasPlayedCurrentDailyCycle]) is - showing up once anywhere in a
  /// calendar day keeps the streak alive, however many cycles land in it.
  int get currentStreak => (_box.get(_currentStreakKey) as int?) ?? 0;

  /// Records [date]'s calendar day as the daily round just played, so
  /// [hasPlayedDailyOn] reflects it for the rest of that day, and
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

  /// A calendar-month key, e.g. `'2026-07'` - every date within the same
  /// month compares equal regardless of day.
  String _monthKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// A calendar-year key, e.g. `'2026'` - every date within the same year
  /// compares equal regardless of month or day.
  String _yearKey(DateTime date) => '${date.year}';

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

  /// Number of times the app has been cold-started, `0` before the very
  /// first launch has finished registering. Only ever incremented, once
  /// per launch, by [registerAppOpened] - drives the "Rate Numberama"
  /// prompt's first-trigger threshold in [shouldShowRatePrompt].
  int get appOpenCount => (_box.get(_appOpenCountKey) as int?) ?? 0;

  /// Bumps [appOpenCount] and returns the new count - called once from
  /// `main()` on every cold launch.
  int registerAppOpened() {
    final next = appOpenCount + 1;
    _box.put(_appOpenCountKey, next);
    return next;
  }

  /// Whether the player has already engaged with the native rating flow
  /// (automatic prompt or the manual Settings row) - once `true`,
  /// [shouldShowRatePrompt] never fires again.
  bool get hasRated => (_box.get(_hasRatedKey) as bool?) ?? false;

  Future<void> setHasRated() => _box.put(_hasRatedKey, true);

  /// Calendar day the "Rate Numberama" prompt was last shown, `null` if
  /// never - drives [shouldShowRatePrompt]'s 4-day cooldown between repeat
  /// prompts.
  DateTime? get lastRatePromptDate {
    final key = _box.get(_lastRatePromptDateKey) as String?;
    if (key == null) return null;
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  Future<void> setLastRatePromptDate(DateTime date) =>
      _box.put(_lastRatePromptDateKey, _dateKey(date));

  /// Whether the automatic "Rate Numberama" prompt should show right now:
  /// first on the app's 4th open ([lastRatePromptDate] still `null` at that
  /// point), then again every 4 calendar days after that - so it nags on a
  /// slow, day-based cadence rather than on every single launch - and never
  /// once [hasRated] is `true`.
  bool shouldShowRatePrompt({DateTime? now}) {
    if (hasRated) return false;
    if (appOpenCount < 4) return false;
    final last = lastRatePromptDate;
    if (last == null) return true;
    final today = now ?? DateTime.now();
    final elapsedDays = DateTime(today.year, today.month, today.day)
        .difference(DateTime(last.year, last.month, last.day))
        .inDays;
    return elapsedDays >= 4;
  }

  /// Whether the "Remove Ads" IAP has been bought - `false` until that
  /// purchase flow (still a Settings stub, see `SettingsRow` "Remove Ads")
  /// is wired up and verifies a real transaction. Every ad-showing call
  /// site (interstitials, banners, and the rewarded power-ups in
  /// [PowerBar]) checks this first and skips straight to the free/granted
  /// outcome instead of calling `AdService` at all.
  bool get removeAdsPurchased =>
      (_box.get(_removeAdsPurchasedKey) as bool?) ?? false;

  Future<void> setRemoveAdsPurchased(bool value) =>
      _box.put(_removeAdsPurchasedKey, value);

  /// Stable per-install identifier - generated via [Uuid.v4] the first time
  /// this is ever read, then persisted so every later read (this launch and
  /// every future one) returns the same value. This is the app's one seam
  /// for a future cloud backend (see class doc): the key a player's record
  /// would be stored under remotely.
  String get playerId {
    final existing = _box.get(_playerIdKey) as String?;
    if (existing != null) return existing;
    final generated = const Uuid().v4();
    _box.put(_playerIdKey, generated);
    return generated;
  }

  /// All-time XP total earned from Classic rounds - the Daily Challenge
  /// never contributes (see `GameStateNotifier.registerPairCleared`). `0`
  /// before the player's first Classic pair. A level is always derived from
  /// this via `calculateLevel` (`level_calculator.dart`), never stored
  /// separately - see [PlayerProgress]'s class doc for why.
  int get totalXp => (_box.get(_totalXpKey) as int?) ?? 0;

  Future<void> setTotalXp(int value) => _box.put(_totalXpKey, value);

  /// Convenience bundle of [playerId] and [totalXp] - see [PlayerProgress].
  PlayerProgress get playerProgress =>
      PlayerProgress(playerId: playerId, totalXp: totalXp);

  /// Wipes every durable value this app keeps locally - all-time and
  /// period-bucketed best scores, daily-played gate, daily play history,
  /// streak, Classic round count, XP, the "Rate Numberama" prompt's own
  /// tracking, and every setting above - back to first-launch defaults.
  /// Used by Settings' "Reset Progress" action.
  ///
  /// [playerId] alone survives - it identifies this install for a future
  /// cloud backend, not in-game progress, so a progress reset shouldn't
  /// change it.
  Future<void> clearAll() async {
    final id = _box.get(_playerIdKey) as String?;
    await _box.clear();
    if (id != null) await _box.put(_playerIdKey, id);
  }
}
