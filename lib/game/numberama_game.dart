import 'dart:math';

import 'package:flame/game.dart';

import '../state/game_state.dart';
import 'grid_component.dart';
import 'selection_manager.dart';

/// Root Flame game. Wires the grid, tiles, and selection rules together on
/// load. Deliberately thin - all pairing/scoring logic lives in
/// [SelectionManager], all layout/collapse logic lives in [GridComponent].
///
/// Note: Flame's current event system dispatches `TapCallbacks` (used by
/// [TileComponent]) to any plain [FlameGame] automatically - there is no
/// `HasTappableComponents` mixin in this version of Flame (that name
/// belonged to the older pre-1.8 `Tappable`/`HasTappables` API), so none is
/// mixed in here.
class NumberamaGame extends FlameGame {
  NumberamaGame({required this.gameStateNotifier, Random? random})
      : _random = random;

  final GameStateNotifier gameStateNotifier;

  /// Injectable so tests can seed deterministic tile values.
  final Random? _random;

  static const int columns = GridComponent.columns;
  static const int initialRows = 3;

  late final SelectionManager selectionManager;
  late final GridComponent gridComponent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    selectionManager = SelectionManager(gameStateNotifier: gameStateNotifier);
    gridComponent =
        GridComponent(selectionManager: selectionManager, random: _random);
    selectionManager.attachGrid(gridComponent);

    await add(gridComponent);

    for (var i = 0; i < initialRows; i++) {
      gridComponent.addRow();
    }

    gameStateNotifier.startGame();
  }
}
