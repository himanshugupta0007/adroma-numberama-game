import 'dart:math';

import 'package:flame/components.dart' show TimerComponent;
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, Colors;

import '../state/difficulty.dart';
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
    this.difficulty = Difficulty.medium,
    this.isDaily = false,
    Random? random,
    double? autoRowIntervalSeconds,
    Duration? rushDuration,
  })  : _random = random,
        autoRowIntervalSeconds =
            autoRowIntervalSeconds ?? difficulty.autoRowIntervalSeconds,
        initialRows = difficulty.initialRows,
        rushDuration = rushDuration ?? dailyRushDuration,
        selectionManager = SelectionManager(
          gameStateNotifier: gameStateNotifier,
          isDaily: isDaily,
        );

  final GameStateNotifier gameStateNotifier;

  /// Governs tile value range and whether power-ups are offered this round
  /// (both apply to Classic and Daily), plus - for Classic only - starting
  /// rows and auto-row speed. See [Difficulty]. Classic always plays at
  /// [Difficulty.medium] (today's existing baseline); only the Daily
  /// Challenge varies tier.
  final Difficulty difficulty;

  /// Whether this is the Daily Challenge's Rush mode: a fixed, fully-filled
  /// board racing a countdown, rather than Classic's rising stack. Flips
  /// [onLoad] over to the Rush setup path entirely - see there.
  final bool isDaily;

  /// Injectable so tests can seed deterministic tile values.
  final Random? _random;

  static const int columns = GridComponent.columns;
  static const int maxRows = GridComponent.maxRows;

  /// Classic only - how many of the [maxRows] rows are already filled when
  /// a fresh round begins, before the board starts rising on its own.
  /// Derived from [difficulty] - lower on easier tiers, so there's more
  /// starting headroom.
  final int initialRows;

  /// Classic only - how often a new row automatically rises from the
  /// bottom. There is no manual "add row" control - this is the only
  /// source of new rows besides [SelectionManager]'s stuck-board safety
  /// net. Derived from [difficulty] unless overridden (tests only; the app
  /// never overrides this).
  final double autoRowIntervalSeconds;

  /// Daily Challenge Rush only - how long the countdown starts at. Defaults
  /// to [dailyRushDuration]; overridable (tests only; the app always uses
  /// the default).
  final Duration rushDuration;

  /// Daily Challenge Rush only - seconds left on the countdown, ticked down
  /// once a second by [_tickRushCountdown]. Mirrored into
  /// [GameStateNotifier.rushSecondsRemaining] for the HUD.
  int _rushSecondsRemaining = 0;

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

    gridComponent = GridComponent(
      selectionManager: selectionManager,
      random: _random,
      maxTileValue: difficulty.maxTileValue,
    );
    selectionManager.attachGrid(gridComponent);

    await add(gridComponent);

    if (isDaily) {
      gridComponent.fillRushBoard(
        pairDistanceRange: difficulty.rushPairDistanceRange,
        sumPairChance: difficulty.rushSumPairChance,
      );

      _rushSecondsRemaining = rushDuration.inSeconds;

      add(
        TimerComponent(
          period: 1,
          repeat: true,
          onTick: _tickRushCountdown,
        ),
      );

      gameStateNotifier.startGame(
        powerUpsEnabled: difficulty.powerUpsEnabled,
        rushSecondsRemaining: _rushSecondsRemaining,
      );
      return;
    }

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

    gameStateNotifier.startGame(powerUpsEnabled: difficulty.powerUpsEnabled);
  }

  /// Fires every [autoRowIntervalSeconds]. If there's still room, a new row
  /// rises from the bottom; if not, the stack has nowhere left to go but
  /// through the rectangle's top edge, so the round ends right here rather
  /// than silently doing nothing. Classic only - [isDaily] uses
  /// [_tickRushCountdown] instead.
  void _autoAddRow() {
    if (gameStateNotifier.phase != GamePhase.playing) return;
    if (gridComponent.canAddRow) {
      gridComponent.addRow();
    } else {
      gameStateNotifier.setPhase(GamePhase.lost);
    }
  }

  /// Fires once a second while a Daily Challenge Rush round is in progress.
  /// Ends the round the moment the clock hits zero: a win if the board
  /// happened to already be clear, a loss otherwise (tiles left with no
  /// time to clear them).
  void _tickRushCountdown() {
    if (gameStateNotifier.phase != GamePhase.playing) return;
    _rushSecondsRemaining--;
    gameStateNotifier.setRushSecondsRemaining(_rushSecondsRemaining);
    if (_rushSecondsRemaining <= 0) {
      gameStateNotifier.setPhase(
        gridComponent.isEmpty ? GamePhase.won : GamePhase.lost,
      );
    }
  }
}
