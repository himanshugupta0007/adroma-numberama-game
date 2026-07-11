import '../state/game_state.dart';
import 'grid_component.dart';
import 'tile_component.dart';

/// Owns all pairing/scoring rules for the board. This is the single place
/// that decides whether two tapped tiles form a valid pair, drives their
/// animations, and reports outcomes to [GameStateNotifier]. Tile and grid
/// components stay dumb; this class is where "business logic" lives.
class SelectionManager {
  SelectionManager({required this.gameStateNotifier});

  final GameStateNotifier gameStateNotifier;

  /// Points awarded per valid pair.
  static const int _pointsPerPair = 10;

  late final GridComponent grid;

  final List<TileComponent> _selectedTiles = [];

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

    if (_selectedTiles.length == 2) {
      _evaluateSelection();
    }
  }

  void _evaluateSelection() {
    final tile1 = _selectedTiles[0];
    final tile2 = _selectedTiles[1];
    final isValidPair =
        tile1.value == tile2.value || tile1.value + tile2.value == 10;

    if (isValidPair) {
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

    gameStateNotifier.incrementScore(_pointsPerPair);
    gameStateNotifier.incrementMoves();

    if (grid.isEmpty) {
      // TODO(sound): trigger "board cleared / win" sound here.
      gameStateNotifier.setPhase(GamePhase.won);
      return;
    }

    // Only refill when the player is actually stuck - refilling on tile
    // count alone would mean the board could never reach zero, making the
    // "clear the whole board to win" rule unreachable.
    if (!_hasAnyValidPair()) {
      // TODO(sound): trigger "new row added" sound here.
      grid.addRow();
    }
  }

  /// Whether any two tiles currently on the board would form a valid pair.
  bool _hasAnyValidPair() {
    final tiles = grid.activeTiles;
    for (var i = 0; i < tiles.length; i++) {
      for (var j = i + 1; j < tiles.length; j++) {
        final a = tiles[i];
        final b = tiles[j];
        if (a.value == b.value || a.value + b.value == 10) return true;
      }
    }
    return false;
  }

  void _handleInvalidPair(TileComponent tile1, TileComponent tile2) {
    // TODO(sound): trigger "invalid pair" sound effect here.
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
