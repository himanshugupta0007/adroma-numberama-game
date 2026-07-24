/// A Daily Challenge difficulty tier. Classic always plays at [medium]
/// (today's existing baseline behavior, via [NumberamaGame]'s default) -
/// only the Daily Challenge varies tier, and which tier applies on a given
/// date is fixed (see [Difficulty.forDate]) so every player sees the same
/// difficulty on the same day, the same way everyone gets the same puzzle.
///
/// The Daily Challenge is a Rush round (see [rushPairDistanceRange]/
/// [rushSumPairChance]/[dailyRushDuration]), not Classic's rising stack -
/// [autoRowIntervalSeconds]/[initialRows] exist only for Classic's own
/// fixed [medium] baseline and are never varied by tier in practice.
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
        Difficulty.easy => 8,
        Difficulty.medium => 5,
        Difficulty.hard => 3,
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

  /// Tile face values are drawn from 1..[maxTileValue]. [easy] narrows the
  /// pool so pairs are easier to spot at a glance; [medium]/[hard] use the
  /// full 1-9 spread, where a matching pair is rarer to stumble across.
  /// Applies to both Classic and Daily.
  int get maxTileValue => this == Difficulty.easy ? 5 : 9;

  /// Daily Rush only: how far apart (Chebyshev distance in cells) a
  /// planted pair's two tiles are placed. Narrow on [easy] (the pair sits
  /// right next to each other, or diagonally touching); wide on [hard]
  /// (opposite ends of the board) - the max possible distance on a 9x9
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
/// for July 14th). Not a literal RNG seed - there's no seeded board
/// generator yet, so today's board is still randomly generated like any
/// Classic round - but a stable, honest per-date label instead of a
/// hardcoded placeholder, and something for the results share card to
/// reference.
String dailySeedLabel(DateTime date) =>
    'SEED #${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}';
