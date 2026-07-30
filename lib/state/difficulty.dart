/// A difficulty tier, chosen by the player before a Classic round (see the
/// home screen's difficulty picker) or fixed by the calendar date for the
/// Daily Challenge (see [Difficulty.forDate]), so every player sees the same
/// Daily tier on the same day, the same way everyone gets the same puzzle.
///
/// The Daily Challenge is a Rush round (see [rushPairDistanceRange]/
/// [rushSumPairChance]/[dailyRushDuration]), not Classic's rising stack -
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
        Difficulty.easy => 10,
        Difficulty.medium => 7,
        Difficulty.hard => 5,
      };

  /// Rows filled before a Classic round even starts - less starting
  /// headroom means less room to recover from an early mistake. Unused by
  /// the Daily Challenge (see class doc).
  int get initialRows => switch (this) {
        Difficulty.easy => 2,
        Difficulty.medium => 3,
        Difficulty.hard => 5,
      };

  /// Whether shuffle/hint are offered at all this round - removed
  /// entirely on [hard] (shown ad-gated from the very first frame) rather
  /// than merely harder to earn. Applies to both Classic and Daily.
  bool get powerUpsEnabled => this != Difficulty.hard;

  /// Tile face values are drawn from 1..[maxTileValue] - a narrower pool
  /// means more repeated values on the board, so a matching pair is easier
  /// to spot at a glance; a wider pool spreads values thinner, so pairs are
  /// rarer to stumble across. Widens from [easy] to [hard] so pair-finding
  /// itself gets progressively harder, not just the board's pace. Applies
  /// to both Classic and Daily.
  int get maxTileValue => switch (this) {
        Difficulty.easy => 5,
        Difficulty.medium => 7,
        Difficulty.hard => 9,
      };

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

  /// Deterministic difficulty-of-the-day: every player sees the same tier
  /// on the same calendar date (in that date's local calendar day, not
  /// wall-clock time), and it rotates so consecutive days differ.
  static Difficulty forDate(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final yearStart = DateTime.utc(date.year, 1, 1);
    final dayOfYear = day.difference(yearStart).inDays;
    return Difficulty.values[dayOfYear % Difficulty.values.length];
  }
}

/// The Daily Challenge Rush round length - the one knob to retune the
/// countdown. Change this value; nothing else needs to change (tests
/// override it directly via [NumberamaGame]'s constructor instead).
const Duration dailyRushDuration = Duration(seconds: 60);

/// A per-day identifier shown alongside the daily board (e.g. "SEED #0714"
/// for July 14th) - and something for the results share card to reference.
/// A display label only: month+day repeats across years, so it's not
/// unique the way [dailySeed] needs to be.
String dailySeedLabel(DateTime date) =>
    'SEED #${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';

/// Deterministic integer seed for [date]'s local calendar day - the same
/// value for every player regardless of time zone, and different from
/// every other day (unlike [dailySeedLabel], which repeats across years).
/// Feeds [NumberamaGame]'s injectable `Random` so the Daily Challenge board
/// - tile values and pair placement, not just [Difficulty] tier - is the
/// same for every player, the same way a real shared daily puzzle should be.
int dailySeed(DateTime date) {
  final day = DateTime.utc(date.year, date.month, date.day);
  return day.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}
