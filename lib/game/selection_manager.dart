import 'package:flutter/foundation.dart';

import '../state/game_state.dart';
import 'grid_component.dart';
import 'tile_component.dart';

/// Owns all pairing/scoring rules for the board. This is the single place
/// that decides whether two tapped tiles form a valid pair, drives their
/// animations, and reports outcomes to [GameStateNotifier]. Tile and grid
/// components stay dumb; this class is where "business logic" lives.
class SelectionManager {
  SelectionManager({required this.gameStateNotifier, this.isDaily = false});

  final GameStateNotifier gameStateNotifier;

  /// Whether this round is the Daily Challenge's Rush mode: a fixed board
  /// with no rising stack, so being stuck isn't itself a loss condition
  /// (only running out of time is) - see [_handleValidPair].
  final bool isDaily;

  /// Points awarded per valid pair.
  static const int _pointsPerPair = 10;

  late final GridComponent grid;

  final List<TileComponent> _selectedTiles = [];

  /// Broadcasts the currently-selected tiles (0, 1, or 2) so UI code can
  /// render the "sum arc" signature interaction between a real pair without
  /// this class knowing anything about Flutter widgets.
  final ValueNotifier<List<TileComponent>> selectedTilesNotifier =
      ValueNotifier(const []);

  ValueListenable<List<TileComponent>> get selectedTilesListenable =>
      selectedTilesNotifier;

  /// Wires this manager up to the grid it controls. Split from the
  /// constructor because the grid needs a reference to this manager to
  /// build its tiles, creating a construction-order dependency.
  void attachGrid(GridComponent gridComponent) {
    grid = gridComponent;
  }

  /// Entry point tiles call into on tap. Never called directly by game
  /// logic - only ever invoked as a callback from a [TileComponent].
  void onTileTapped(TileComponent tile) {
    if (tile.visualState != TileVisualState.idle) return;
    if (_selectedTiles.contains(tile)) return;
    if (_selectedTiles.length >= 2) return;

    tile.setSelected(true);
    _selectedTiles.add(tile);
    selectedTilesNotifier.value = List.of(_selectedTiles);

    if (_selectedTiles.length == 2) {
      _evaluateSelection();
    }
  }

  /// The one pairing rule for the whole game: equal values, or values that
  /// sum to 10.
  bool _isValidPair(int a, int b) => a == b || a + b == 10;

  void _evaluateSelection() {
    final tile1 = _selectedTiles[0];
    final tile2 = _selectedTiles[1];

    if (_isValidPair(tile1.value, tile2.value)) {
      _handleValidPair(tile1, tile2);
    } else {
      _handleInvalidPair(tile1, tile2);
    }
  }

  Future<void> _handleValidPair(
      TileComponent tile1, TileComponent tile2) async {
    // TODO(sound): trigger "valid match" sound/fanfare here.
    await Future.wait([
      tile1.playClearAnimation(),
      tile2.playClearAnimation(),
    ]);

    grid.removePair(tile1, tile2);
    _selectedTiles.clear();
    selectedTilesNotifier.value = const [];

    gameStateNotifier.registerPairCleared(_pointsPerPair);
    gameStateNotifier.incrementMoves();

    if (grid.isEmpty) {
      // TODO(sound): trigger "board cleared / win" sound here.
      gameStateNotifier.setPhase(GamePhase.won);
      return;
    }

    // Rush is a fixed board for the whole round - no refilling, and being
    // stuck isn't a loss condition (only the countdown, driven by
    // NumberamaGame, is). The player just needs to shuffle or wait it out.
    if (isDaily) return;

    // Only refill when the player is actually stuck - refilling on tile
    // count alone would mean the board could never reach zero, making the
    // "clear the whole board to win" rule unreachable. Keep adding rows
    // until a valid pair actually exists: a single row isn't guaranteed to
    // unstick the board, especially with a narrow column count. If the
    // board fills up (hits GridComponent.maxRows) while still stuck, the
    // round is lost - there's no more room to refill into.
    while (!_hasAnyValidPair()) {
      if (!grid.canAddRow) {
        // TODO(sound): trigger "board full / game over" sound here.
        gameStateNotifier.setPhase(GamePhase.lost);
        return;
      }
      // TODO(sound): trigger "new row added" sound here.
      grid.addRow();
    }
  }

  /// Shuffle power-up: re-rolls which value sits in which occupied cell and
  /// plays the flip flourish. [GridComponent.shuffleTileValues] owns the
  /// randomization/animation; this just tells it what counts as an
  /// acceptable result - re-rolling into a board with no valid pair at all
  /// would make the power-up actively hurt the player.
  Future<void> shuffle() {
    return grid.shuffleTileValues(isAcceptable: _hasValidPairAmong);
  }

  /// Hint power-up: finds the first valid pair among the tiles currently on
  /// the board (in reading order) and pulses both, without selecting them -
  /// the player still has to tap the pair themselves to actually clear it.
  /// A no-op if the board somehow has no valid pair (shouldn't happen -
  /// [_handleValidPair] never leaves the board in that state).
  Future<void> hint() async {
    final tiles = grid.activeTiles;
    for (var i = 0; i < tiles.length; i++) {
      for (var j = i + 1; j < tiles.length; j++) {
        if (_isValidPair(tiles[i].value, tiles[j].value)) {
          await Future.wait([
            tiles[i].playHintAnimation(),
            tiles[j].playHintAnimation(),
          ]);
          return;
        }
      }
    }
  }

  /// Whether any two tiles currently on the board would form a valid pair.
  bool _hasAnyValidPair() => _hasValidPairAmong(
        [for (final tile in grid.activeTiles) tile.value],
      );

  /// Whether any two entries in [values] would form a valid pair. Same rule
  /// as [_hasAnyValidPair], expressed over plain values instead of live
  /// tiles so [shuffle] can test a candidate redistribution before it's
  /// ever applied to the board.
  bool _hasValidPairAmong(List<int> values) {
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        if (_isValidPair(values[i], values[j])) return true;
      }
    }
    return false;
  }

  void _handleInvalidPair(TileComponent tile1, TileComponent tile2) {
    // TODO(sound): trigger "invalid pair" sound effect here.
    // Clear immediately (not after the shake) - _evaluateSelection is
    // synchronous, so there's no real "pending" frame to show the arc for,
    // and leaving it up during the shake would show it frozen at stale
    // tile positions while the tiles visibly wiggle underneath.
    selectedTilesNotifier.value = const [];
    gameStateNotifier.resetCombo();
    gameStateNotifier.registerInvalidAttempt();
    var animationsFinished = 0;
    void onShakeComplete() {
      animationsFinished++;
      if (animationsFinished < 2) return;
      tile1.setSelected(false);
      tile2.setSelected(false);
      _selectedTiles.clear();
    }

    tile1.playShakeAnimation(onComplete: onShakeComplete);
    tile2.playShakeAnimation(onComplete: onShakeComplete);
  }
}
