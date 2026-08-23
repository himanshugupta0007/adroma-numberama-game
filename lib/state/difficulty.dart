/// Length of one Daily Challenge cycle - a fresh board unlocks every time
/// this elapses (see [dailyCycleIndex]), replacing a plain once-per-calendar
/// day gate so players get more than one shot at a new board across a day.
const dailyCycleDuration = Duration(hours: 10);

/// Which [dailyCycleDuration]-long cycle [time] falls into, counted from the
/// Unix epoch - the same cycle for every player on Earth regardless of local
/// timezone (calendar-day boundaries differ by timezone; epoch-relative
/// cycles don't), the way a shared daily puzzle needs to be.
int dailyCycleIndex(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch ~/ dailyCycleDuration.inMilliseconds;

/// Wall-clock instant [cycle] unlocks at, i.e. when the cycle *after* it
/// begins - what [PreferencesService.timeUntilNextDailyCycle] counts down
/// to.
DateTime dailyCycleUnlockTime(int cycle) =>
    DateTime.fromMillisecondsSinceEpoch(
      (cycle + 1) * dailyCycleDuration.inMilliseconds,
      isUtc: true,
    ).toLocal();

/// A difficulty tier, chosen by the player before a Classic round (see the
/// home screen's difficulty picker) or fixed by the current [dailyCycleIndex]
/// for the Daily Challenge (see [Difficulty.forDate]), so every player sees
/// the same Daily tier within the same cycle, the same way everyone gets the
/// same puzzle.
///
/// The Daily Challenge is a Rush round (see [rushPairDistanceRange]/
/// [rushSumPairChance]/[rushDuration]), not Classic's rising stack -
/// [autoRowIntervalSeconds]/[initialRows] only take effect in Classic.
enum Difficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
      };

  /// How often a new row rises from the bottom in Classic's rising-stack
  /// mode - the one clock that mode has, so it's the most direct lever on
  /// pressure. Unused by the Daily Challenge (see class doc).
  double get autoRowIntervalSeconds => switch (this) {
        Difficulty.easy => 12,
        Difficulty.medium => 10,
        Difficulty.hard => 8,
      };

  /// Board height (rows) in Classic - [GridComponent.maxRows]. Fixed at 8
  /// for [easy]/[medium]; [hard] gets a taller 9-row board (still 9
  /// columns, so a 9x9 grid), which also shrinks every tile a little since
  /// cell size is screen height / [maxRows] (see
  /// [GridComponent._recalculateMetrics]). Unused by the Daily Challenge,
  /// which always fills the fixed 9x8 board via [GridComponent.fillRushBoard]
  /// regardless of tier.
  int get maxRows => switch (this) {
        Difficulty.easy => 8,
        Difficulty.medium => 8,
        Difficulty.hard => 9,
      };

  /// Rows filled before a Classic round even starts - less starting
  /// headroom means less room to recover from an early mistake. [hard]
  /// starts roughly half of its (taller, see [maxRows]) board already
  /// stacked, on top of that reduced headroom. Unused by the Daily
  /// Challenge (see class doc).
  int get initialRows => switch (this) {
        Difficulty.easy => 2,
        Difficulty.medium => 3,
        Difficulty.hard => (maxRows / 2).ceil(),
      };

  /// Tile face values are drawn from 1..[maxTileValue] - fixed at 10 for
  /// every tier (Classic and Daily alike), so pace (see
  /// [autoRowIntervalSeconds]) is what separates the tiers, not the tile
  /// pool itself.
  int get maxTileValue => 10;

  /// Daily Rush only: how far apart (Chebyshev distance in cells) a
  /// planted pair's two tiles are placed. Narrow on [easy] (the pair sits
  /// right next to each other, or diagonally touching); wide on [hard]
  /// (opposite ends of the board) - the max possible distance on the 9x8
  /// board is 8, corner to corner.
  ({int min, int max}) get rushPairDistanceRange => switch (this) {
        Difficulty.easy => (min: 1, max: 2),
        Difficulty.medium => (min: 3, max: 5),
        Difficulty.hard => (min: 6, max: 8),
      };

  /// Daily Rush only: the chance a given planted pair is a sum-to-10 pair
  /// rather than an equal-value pair. Low on [easy] (equal-value pairs are
  /// the easiest to spot at a glance); high on [hard] (favors the mental
  /// math of a sum-to-10 over the instant recognition of a repeat).
  double get rushSumPairChance => switch (this) {
        Difficulty.easy => 0.25,
        Difficulty.medium => 0.5,
        Difficulty.hard => 0.75,
      };

  /// Daily Rush only: how long the countdown starts at. Fixed at 60 seconds
  /// for every tier - pressure on [hard] instead comes from
  /// [rushPairDistanceRange]'s far-apart pairs and [rushSumPairChance]'s
  /// harder mental math already making each pair slower to find.
  Duration get rushDuration => const Duration(seconds: 60);

  /// Deterministic difficulty-of-the-cycle: every player sees the same tier
  /// within the same [dailyCycleIndex] (wall-clock time, not calendar date),
  /// and it rotates so consecutive cycles differ.
  static Difficulty forDate(DateTime date) =>
      Difficulty.values[dailyCycleIndex(date) % Difficulty.values.length];
}

/// A per-cycle identifier shown alongside the daily board (e.g. "SEED
/// #014522") - and something for the results share card to reference.
/// Derived straight from [dailyCycleIndex], so - unlike the old per-calendar
/// day label - it never repeats across two different Daily boards.
String dailySeedLabel(DateTime date) =>
    'SEED #${dailyCycleIndex(date).toString().padLeft(6, '0')}';

/// Deterministic integer seed for [date]'s [dailyCycleIndex] - the same
/// value for every player regardless of time zone, and different from every
/// other cycle. Feeds [NumberamaGame]'s injectable `Random` so the Daily
/// Challenge board - tile values and pair placement, not just [Difficulty]
/// tier - is the same for every player, the same way a real shared daily
/// puzzle should be.
int dailySeed(DateTime date) => dailyCycleIndex(date);
