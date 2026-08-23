/// Immutable snapshot of one player's persistent progression data.
///
/// [playerId] is the identifier a future cloud backend would key this
/// player's record by (see [PreferencesService]'s class doc on that seam) -
/// generated once on first launch and never regenerated.
///
/// There is no stored "level" field: XP only ever increases during normal
/// play, so the level implied by [totalXp] is always the player's best
/// level too. Storing a level alongside [totalXp] would just be a second
/// source of truth that can drift - call `calculateLevel(totalXp)` (see
/// `level_calculator.dart`) wherever a level is needed.
class PlayerProgress {
  const PlayerProgress({required this.playerId, required this.totalXp});

  final String playerId;
  final int totalXp;
}
