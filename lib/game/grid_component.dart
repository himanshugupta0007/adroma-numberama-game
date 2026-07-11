import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import 'selection_manager.dart';
import 'tile_component.dart';

/// Owns the 2D board of [TileComponent]s: lays them out in a fixed
/// 9-column grid centered on screen, spawns new rows, and collapses the
/// grid after a pair is removed. Contains layout/bookkeeping only - the
/// decision of *which* two tiles form a valid pair lives in
/// [SelectionManager].
class GridComponent extends PositionComponent with HasGameReference {
  GridComponent({required this.selectionManager, Random? random})
      : _random = random ?? Random();

  final SelectionManager selectionManager;

  static const int columns = 9;

  /// Tile padding as a fraction of a grid cell's width, per spec: tiles are
  /// 10% padded relative to (screen width / 9 columns).
  static const double _paddingFactor = 0.1;

  /// Injectable so tests can seed deterministic tile values.
  final Random _random;

  /// Row-major grid of tiles. A `null` entry marks a cleared cell that
  /// hasn't been collapsed away yet.
  final List<List<TileComponent?>> _grid = [];

  late double _cellSize;
  late double _tileSize;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _recalculateMetrics();
  }

  void _recalculateMetrics() {
    _cellSize = game.size.x / columns;
    _tileSize = _cellSize * (1 - _paddingFactor);
  }

  /// Pixel position (relative to this component) of the cell at [row]/[col],
  /// with the tile centered inside its padded cell.
  Vector2 _positionForCell(int row, int col) {
    final inset = (_cellSize - _tileSize) / 2;
    return Vector2(col * _cellSize + inset, row * _cellSize + inset);
  }

  /// Recomputes this component's position so the grid stays horizontally
  /// and vertically centered on screen as rows are added/removed.
  void _recenter() {
    final screenSize = game.size;
    final gridWidth = columns * _cellSize;
    final gridHeight = _grid.length * _cellSize;
    position = Vector2(
      (screenSize.x - gridWidth) / 2,
      (screenSize.y - gridHeight) / 2,
    );
  }

  bool get isEmpty => tileCount == 0;

  int get tileCount => _grid.fold(
        0,
        (sum, row) => sum + row.where((tile) => tile != null).length,
      );

  /// All tiles currently on the board, in reading order. Exposed read-only
  /// so [SelectionManager] can decide things like "is the player stuck"
  /// without GridComponent needing to know what a valid pair even is.
  List<TileComponent> get activeTiles => [
        for (final row in _grid)
          for (final tile in row)
            if (tile != null) tile,
      ];

  /// Appends a new row of random 1-9 tiles at the bottom of the grid.
  void addRow() {
    final rowIndex = _grid.length;
    final row = <TileComponent?>[];
    for (var col = 0; col < columns; col++) {
      final tile = TileComponent(
        value: _random.nextInt(9) + 1,
        onTileTapped: selectionManager.onTileTapped,
        position: _positionForCell(rowIndex, col),
        size: Vector2.all(_tileSize),
      );
      row.add(tile);
      add(tile);
    }
    _grid.add(row);
    _recenter();
  }

  /// Removes [tile1] and [tile2] from the grid and collapses remaining
  /// tiles to fill the gap, reflowing them in reading order (left-to-right,
  /// top-to-bottom) and animating them to their new slots.
  void removePair(TileComponent tile1, TileComponent tile2) {
    _clearCell(tile1);
    _clearCell(tile2);
    _collapse();
  }

  void _clearCell(TileComponent tile) {
    for (final row in _grid) {
      final col = row.indexOf(tile);
      if (col != -1) {
        row[col] = null;
        return;
      }
    }
  }

  void _collapse() {
    final remaining = <TileComponent>[
      for (final row in _grid)
        for (final tile in row)
          if (tile != null) tile,
    ];

    _grid
      ..clear()
      ..addAll([
        for (var i = 0; i < remaining.length; i += columns)
          <TileComponent?>[...remaining.skip(i).take(columns)],
      ]);

    for (var row = 0; row < _grid.length; row++) {
      for (var col = 0; col < _grid[row].length; col++) {
        final tile = _grid[row][col];
        if (tile == null) continue;
        final target = _positionForCell(row, col);
        if (tile.position == target) continue;
        tile.add(
          MoveEffect.to(
            target,
            EffectController(duration: 0.25, curve: Curves.easeOut),
          ),
        );
      }
    }

    _recenter();
  }
}
