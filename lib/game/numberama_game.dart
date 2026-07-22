import 'dart:math';

import 'package:flame/components.dart' show TimerComponent;
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, Colors;

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
  NumberamaGame({
    required this.gameStateNotifier,
    Random? random,
    double? autoRowIntervalSeconds,
  })  : _random = random,
        autoRowIntervalSeconds =
            autoRowIntervalSeconds ?? defaultAutoRowIntervalSeconds,
        selectionManager =
            SelectionManager(gameStateNotifier: gameStateNotifier);

  final GameStateNotifier gameStateNotifier;

  /// Injectable so tests can seed deterministic tile values.
  final Random? _random;

  static const int columns = GridComponent.columns;
  static const int maxRows = GridComponent.maxRows;

  /// Starting fill: a fresh Classic round begins with 3 of the 8 rows
  /// filled - the board rises from there rather than the player choosing
  /// when to add rows.
  static const int initialRows = 3;

  /// Default for [autoRowIntervalSeconds]. Overridable per-instance (like
  /// [_random]) so tests can drive the timer without waiting on real game
  /// clock ticks, or push it out of reach entirely when a test wants to
  /// simulate several `update()` seconds without an auto-row ever firing.
  static const double defaultAutoRowIntervalSeconds = 5;

  /// How often a new row automatically rises from the bottom. There is no
  /// manual "add row" control in Classic - this is the only source of new
  /// rows besides [SelectionManager]'s stuck-board safety net.
  final double autoRowIntervalSeconds;

  /// Constructed eagerly (not in [onLoad]) so UI code can read
  /// [SelectionManager.selectedTilesListenable] synchronously right after
  /// this game is created, before Flame's async load has run.
  final SelectionManager selectionManager;
  late final GridComponent gridComponent;

  // Flame defaults to an opaque black canvas. Cell size is now reserved
  // for the full maxRows height up front (see GridComponent), so the
  // not-yet-filled rows above the current board are real, visible empty
  // canvas space - transparent lets GraphPaperBackground's grid show
  // through there instead of a jarring black rectangle.
  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    gridComponent =
        GridComponent(selectionManager: selectionManager, random: _random);
    selectionManager.attachGrid(gridComponent);

    await add(gridComponent);

    for (var i = 0; i < initialRows; i++) {
      gridComponent.addRow(animate: false);
    }

    add(
      TimerComponent(
        period: autoRowIntervalSeconds,
        repeat: true,
        onTick: _autoAddRow,
      ),
    );

    gameStateNotifier.startGame();
  }

  /// Fires every [autoRowIntervalSeconds]. If there's still room, a new row
  /// rises from the bottom; if not, the stack has nowhere left to go but
  /// through the rectangle's top edge, so the round ends right here rather
  /// than silently doing nothing.
  void _autoAddRow() {
    if (gameStateNotifier.phase != GamePhase.playing) return;
    if (gridComponent.canAddRow) {
      gridComponent.addRow();
    } else {
      gameStateNotifier.setPhase(GamePhase.lost);
    }
  }
}
