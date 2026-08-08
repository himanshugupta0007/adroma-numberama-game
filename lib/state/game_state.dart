import 'package:flutter_riverpod/flutter_riverpod.dart';

/// High-level lifecycle of a single game session.
enum GamePhase { idle, playing, won, lost }

/// Immutable snapshot of the game's score-keeping state.
///
/// This holds only cross-cutting session data (score, moves, phase) - grid
/// and tile state live in the Flame component tree, not here.
class GameState {
  const GameState({
    this.score = 0,
    this.moves = 0,
    this.phase = GamePhase.idle,
    this.combo = 0,
    this.bestCombo = 0,
    this.shuffleAvailable = true,
    this.hintAvailable = true,
    this.clearRowAvailable = true,
    this.consecutiveMisses = 0,
    this.rushSecondsRemaining,
    this.startedAt,
    this.attemptHistory = const [],
  });

  final int score;
  final int moves;
  final GamePhase phase;

  /// Wall-clock moment [GameStateNotifier.startGame] was called - `null`
  /// only before the very first round starts. The results screen reads
  /// `DateTime.now().difference(startedAt)` at the moment a round ends to
  /// show a real elapsed time instead of a guess.
  final DateTime? startedAt;

  /// Consecutive valid pairs cleared with no invalid attempt in between.
  /// Resets to 0 the moment a wrong pair is tapped.
  final int combo;

  /// Highest [combo] reached so far this round - survives combo resets so
  /// the results screen can show the round's peak streak, not just however
  /// it happened to end.
  final int bestCombo;

  /// Whether the round's one free shuffle is still unused. Once spent it
  /// stays `false` for the rest of the round - the power bar then shows the
  /// shuffle slot as ad-gated instead of offering another free use.
  final bool shuffleAvailable;

  /// Whether the round's one free hint is still unused. Once spent it stays
  /// `false` for the rest of the round - the power bar then shows the hint
  /// slot as ad-gated instead of offering another free use.
  final bool hintAvailable;

  /// Whether the round's clear-row power-up is available for free right
  /// now. In Classic this behaves just like [shuffleAvailable]/
  /// [hintAvailable] - one free use, then ad-gated. In the Daily Challenge
  /// it's seeded `false` by [GameStateNotifier.startGame] and never turns
  /// `true` - clearing a row there always requires watching an ad, with no
  /// free use at all (see [GameStateNotifier.startGame]'s doc).
  final bool clearRowAvailable;

  /// Consecutive invalid pair attempts with no valid pair or power-up use
  /// in between. Drives the power bar's "try shuffle/hint" nudge once the
  /// player looks stuck - see [GameStateNotifier.registerInvalidAttempt].
  final int consecutiveMisses;

  /// Daily Challenge Rush only - seconds left on the round's countdown, or
  /// `null` for a Classic round (which has no clock). Ticked once a second
  /// by [NumberamaGame]; the HUD's countdown display reads this directly.
  final int? rushSecondsRemaining;

  /// One entry per pair attempt this round, in order: `true` for a valid
  /// pair cleared, `false` for an invalid attempt. The results screen's
  /// share card mosaic is built directly from this, so it reflects how the
  /// round actually went instead of a decorative placeholder.
  final List<bool> attemptHistory;

  GameState copyWith({
    int? score,
    int? moves,
    GamePhase? phase,
    int? combo,
    int? bestCombo,
    bool? shuffleAvailable,
    bool? hintAvailable,
    bool? clearRowAvailable,
    int? consecutiveMisses,
    int? rushSecondsRemaining,
    DateTime? startedAt,
    List<bool>? attemptHistory,
  }) {
    return GameState(
      score: score ?? this.score,
      moves: moves ?? this.moves,
      phase: phase ?? this.phase,
      combo: combo ?? this.combo,
      bestCombo: bestCombo ?? this.bestCombo,
      shuffleAvailable: shuffleAvailable ?? this.shuffleAvailable,
      hintAvailable: hintAvailable ?? this.hintAvailable,
      clearRowAvailable: clearRowAvailable ?? this.clearRowAvailable,
      consecutiveMisses: consecutiveMisses ?? this.consecutiveMisses,
      rushSecondsRemaining: rushSecondsRemaining ?? this.rushSecondsRemaining,
      startedAt: startedAt ?? this.startedAt,
      attemptHistory: attemptHistory ?? this.attemptHistory,
    );
  }

  @override
  String toString() =>
      'GameState(score: $score, moves: $moves, phase: $phase, combo: $combo, bestCombo: $bestCombo, shuffleAvailable: $shuffleAvailable, hintAvailable: $hintAvailable, clearRowAvailable: $clearRowAvailable, consecutiveMisses: $consecutiveMisses, rushSecondsRemaining: $rushSecondsRemaining, startedAt: $startedAt, attemptHistory: $attemptHistory)';
}

class GameStateNotifier extends StateNotifier<GameState> {
  GameStateNotifier() : super(const GameState());

  /// Public read of the current phase - `state` itself is `@protected` on
  /// [StateNotifier], so code outside this class (e.g. [NumberamaGame]'s
  /// auto-row timer, deciding whether to still act) can't read it directly.
  GamePhase get phase => state.phase;

  /// Resets score/moves and starts a fresh round. Also called when a new
  /// round begins after a previous one finished, so it must not carry over
  /// the prior round's score/moves via [copyWith].
  ///
  /// [powerUpsEnabled] false starts the round with shuffle and hint already
  /// showing ad-gated instead of the usual one free use each - there's no
  /// separate "not offered this round" UI state, so "start already spent"
  /// reuses the existing ad-gated look to mean "removed entirely". Every
  /// [Difficulty] tier (Hard included) currently gets one free use of each,
  /// same as [clearRowAvailable] in Classic below - this parameter stays
  /// available as a hook for a future round type that wants to remove
  /// power-ups outright, rather than as something any current caller varies.
  ///
  /// [rushSecondsRemaining] is only passed for a Daily Challenge Rush round
  /// - left `null` for Classic, which has no clock.
  ///
  /// [clearRowAvailable] governs the clear-row power-up's *starting* state
  /// only - unlike [powerUpsEnabled], it isn't a single on/off switch shared
  /// with shuffle/hint. Classic leaves it at the default `true` (one free
  /// use, then ad-gated, same as shuffle/hint, at every tier); the Daily
  /// Challenge always passes `false` - clearing a row there is ad-gated
  /// from the very first frame, with no free use at all, regardless of
  /// tier.
  void startGame({
    bool powerUpsEnabled = true,
    bool clearRowAvailable = true,
    int? rushSecondsRemaining,
  }) {
    state = GameState(
      phase: GamePhase.playing,
      shuffleAvailable: powerUpsEnabled,
      hintAvailable: powerUpsEnabled,
      clearRowAvailable: clearRowAvailable,
      rushSecondsRemaining: rushSecondsRemaining,
      startedAt: DateTime.now(),
    );
  }

  /// Ticks the Rush countdown - called once a second by [NumberamaGame]
  /// while a Daily Challenge round is in progress.
  void setRushSecondsRemaining(int seconds) {
    state = state.copyWith(rushSecondsRemaining: seconds);
  }

  void incrementScore(int amount) {
    state = state.copyWith(score: state.score + amount);
  }

  void incrementMoves() {
    state = state.copyWith(moves: state.moves + 1);
  }

  /// Registers a cleared pair: bumps the combo streak and awards
  /// [basePoints] scaled by the resulting streak (e.g. the 3rd pair in a
  /// row is worth 3x), so combos are a real scoring incentive and not just
  /// a display number.
  void registerPairCleared(int basePoints) {
    final newCombo = state.combo + 1;
    state = state.copyWith(
      score: state.score + basePoints * newCombo,
      combo: newCombo,
      bestCombo: newCombo > state.bestCombo ? newCombo : state.bestCombo,
      consecutiveMisses: 0,
      attemptHistory: [...state.attemptHistory, true],
    );
  }

  /// Breaks the current streak - called whenever an invalid pair is tapped.
  void resetCombo() {
    if (state.combo == 0) return;
    state = state.copyWith(combo: 0);
  }

  /// Bumps the invalid-attempt streak - called whenever an invalid pair is
  /// tapped, alongside [resetCombo]. Kept separate from combo since a miss
  /// streak (which drives the power-bar nudge) and a combo streak (which
  /// drives scoring) reset on different events - a power-up use clears the
  /// former but not the latter.
  void registerInvalidAttempt() {
    state = state.copyWith(
      consecutiveMisses: state.consecutiveMisses + 1,
      attemptHistory: [...state.attemptHistory, false],
    );
  }

  /// Spends the round's free shuffle. Idempotent - calling it again once
  /// already spent (e.g. a stray double-tap) is a no-op rather than an
  /// error, since there's nothing left to spend.
  void useShuffle() {
    if (!state.shuffleAvailable) return;
    state = state.copyWith(shuffleAvailable: false, consecutiveMisses: 0);
  }

  /// Spends the round's free hint. Idempotent - calling it again once
  /// already spent (e.g. a stray double-tap) is a no-op rather than an
  /// error, since there's nothing left to spend.
  void useHint() {
    if (!state.hintAvailable) return;
    state = state.copyWith(hintAvailable: false, consecutiveMisses: 0);
  }

  /// Spends the round's free clear-row use. Idempotent, same as
  /// [useShuffle]/[useHint] - in the Daily Challenge, where
  /// [GameState.clearRowAvailable] starts and stays `false`, this is
  /// always a no-op.
  void useClearRow() {
    if (!state.clearRowAvailable) return;
    state = state.copyWith(clearRowAvailable: false, consecutiveMisses: 0);
  }

  void setPhase(GamePhase phase) {
    state = state.copyWith(phase: phase);
  }

  void reset() {
    state = const GameState();
  }
}

final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>(
  (ref) => GameStateNotifier(),
);
