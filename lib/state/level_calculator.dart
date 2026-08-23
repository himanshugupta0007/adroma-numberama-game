import 'difficulty.dart';

/// How many levels the progression curve supports - the single knob for
/// "how many levels can be achieved". Raising this alone extends
/// [xpThresholds] with more (increasingly expensive) levels; nothing else
/// in this file needs to change.
///
/// TODO(progression): placeholder - tune before launch.
const int maxLevel = 100;

/// XP required to go from level 1 to level 2 - the smallest per-level jump,
/// since every later jump grows from this one via [xpGrowthRate].
///
/// TODO(progression): placeholder - tune against real scoring data before
/// launch.
const int firstLevelXpIncrement = 200;

/// How much bigger each level's XP requirement is than the one before it,
/// as a multiplier on the *increment* between consecutive thresholds (not
/// on the running total) - e.g. `1.07` means the level 3→2 jump costs 7%
/// more XP than the level 2→1 jump did. Compounding the increment (rather
/// than the threshold itself) gives a curve that ramps up gradually across
/// [maxLevel] levels instead of exploding immediately.
///
/// TODO(progression): placeholder - tune against real scoring data before
/// launch.
const double xpGrowthRate = 1.07;

/// XP total required to *start* each level - `xpThresholds[i]` is the XP a
/// player needs to be level `i + 1`. Level 1 starts at 0 XP, so every
/// player begins there. Has [maxLevel] entries, generated once from
/// [firstLevelXpIncrement] and [xpGrowthRate] - retune the whole curve by
/// changing those two constants (or [maxLevel] itself), not this list.
final List<int> xpThresholds = _buildXpThresholds();

List<int> _buildXpThresholds() {
  final thresholds = <int>[0];
  var increment = firstLevelXpIncrement.toDouble();
  for (var level = 2; level <= maxLevel; level++) {
    thresholds.add(thresholds.last + increment.round());
    increment *= xpGrowthRate;
  }
  return thresholds;
}

/// The level [xp] total corresponds to, via [xpThresholds] lookup. Every
/// player starts at level 1 (0 XP); XP beyond [xpThresholds]'s last entry
/// still reads as [maxLevel] until that constant (and the curve it drives)
/// is raised.
int calculateLevel(int xp) {
  int level = 1;
  for (int i = 1; i < xpThresholds.length; i++) {
    if (xp >= xpThresholds[i]) {
      level = i + 1;
    } else {
      break;
    }
  }
  return level;
}

/// XP earned for clearing one pair at [difficulty] - [baseXp] scaled by a
/// per-tier multiplier (Easy 1x, Medium 1.5x, Hard 2x), rounded to the
/// nearest whole XP.
///
/// TODO(progression): baseXp is a placeholder - tune before launch.
int xpForPair({required int baseXp, required Difficulty difficulty}) {
  final multiplier = switch (difficulty) {
    Difficulty.easy => 1.0,
    Difficulty.medium => 1.5,
    Difficulty.hard => 2.0,
  };
  return (baseXp * multiplier).round();
}
