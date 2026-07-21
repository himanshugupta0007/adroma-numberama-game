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
  });

  final int score;
  final int moves;
  final GamePhase phase;

  GameState copyWith({int? score, int? moves, GamePhase? phase}) {
    return GameState(
      score: score ?? this.score,
      moves: moves ?? this.moves,
      phase: phase ?? this.phase,
    );
  }

  @override
  String toString() => 'GameState(score: $score, moves: $moves, phase: $phase)';
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
  void startGame() {
    state = const GameState(phase: GamePhase.playing);
  }

  void incrementScore(int amount) {
    state = state.copyWith(score: state.score + amount);
  }

  void incrementMoves() {
    state = state.copyWith(moves: state.moves + 1);
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
