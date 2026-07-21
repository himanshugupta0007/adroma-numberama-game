import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

import '../theme/app_colors.dart';
import 'selection_manager.dart';
import 'tile_component.dart';

/// Owns the 2D board of [TileComponent]s: renders a fixed-size rectangle
/// (sized for [maxRows] rows x [columns] columns, centered on screen and
/// never repositioned as rows come and go) and lays tiles out inside it
/// bottom-anchored, like a rising stack - the newest row always sits on the
/// rectangle's bottom edge, and every existing row is pushed up by one cell
/// height to make room for it. Collapses the grid after a pair is removed,
/// letting the remaining stack sink back down. Contains layout/bookkeeping
/// only - the decision of *which* two tiles form a valid pair, and what to
/// do when the board is both stuck and full, lives in [SelectionManager].
class GridComponent extends PositionComponent with HasGameReference {
  GridComponent({required this.selectionManager, Random? random})
      : _random = random ?? Random();

  final SelectionManager selectionManager;

  static const int columns = 8;

  /// Board-full ceiling: once the grid has this many rows, [addRow] can no
  /// longer be called - see [canAddRow].
  static const int maxRows = 8;

  /// Tile padding as a fraction of a grid cell's width, per spec: tiles are
  /// 10% padded relative to (screen width / 8 columns).
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

  /// Re-fits the board rectangle if the canvas is resized after load -
  /// keeps the boundary (and every tile inside it) correctly placed rather
  /// than frozen at whatever size the game had on the first frame.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!isLoaded) return;
    _recalculateMetrics();
    _applyLayout(animate: false);
  }

  /// Cell size is constrained by both axes against the *max* board size
  /// (not the current row count), so tiles never have to shrink again
  /// later as rows are appended - the full 8x8 board always fits the
  /// canvas without clipping. The rectangle itself is sized for [maxRows]
  /// and centered once here - unlike tile layout, it never moves as rows
  /// are added or cleared, since it represents the fixed play-field
  /// boundary, not the current stack height.
  void _recalculateMetrics() {
    _cellSize = min(game.size.x / columns, game.size.y / maxRows);
    _tileSize = _cellSize * (1 - _paddingFactor);
    final boardWidth = columns * _cellSize;
    final boardHeight = maxRows * _cellSize;
    position = Vector2(
      (game.size.x - boardWidth) / 2,
      (game.size.y - boardHeight) / 2,
    );
  }

  /// Pixel position (relative to this component) of the cell at [row]/[col]
  /// out of [totalRows] currently on the board, with the tile centered
  /// inside its padded cell. Rows are bottom-anchored: row `totalRows - 1`
  /// always sits on the rectangle's bottom edge (slot `maxRows - 1`),
  /// regardless of how many rows currently exist, so the stack visually
  /// rises as rows are added and sinks as they're cleared.
  Vector2 _positionForCell(int row, int col, {required int totalRows}) {
    final rowSlot = (maxRows - totalRows) + row;
    final inset = (_cellSize - _tileSize) / 2;
    return Vector2(col * _cellSize + inset, rowSlot * _cellSize + inset);
  }

  /// Moves every tile to its correct slot for the current [_grid] contents.
  /// Called after any change to row count (add or collapse) since a change
  /// in total rows shifts where *every* row's bottom-anchored slot is, not
  /// just the row that changed.
  void _applyLayout({required bool animate}) {
    final totalRows = _grid.length;
    for (var row = 0; row < totalRows; row++) {
      for (var col = 0; col < _grid[row].length; col++) {
        final tile = _grid[row][col];
        if (tile == null) continue;
        final target = _positionForCell(row, col, totalRows: totalRows);
        if (tile.position == target) continue;
        if (animate) {
          tile.add(
            MoveEffect.to(
              target,
              EffectController(duration: 0.25, curve: Curves.easeOut),
            ),
          );
        } else {
          tile.position = target;
        }
      }
    }
  }

  /// Draws the fixed play-field boundary. A tile is never actually rendered
  /// outside this rectangle in normal play - it exists so the "hits the top
  /// and the round ends" rule (enforced by whoever calls [addRow] when
  /// ![canAddRow]) reads as a visible ceiling, not an invisible rule.
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, columns * _cellSize, maxRows * _cellSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.textLow.withValues(alpha: 0.35),
    );
  }

  bool get isEmpty => tileCount == 0;

  /// Whether another row can be appended without exceeding [maxRows].
  bool get canAddRow => _grid.length < maxRows;

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

  /// Appends a new row of random 1-9 tiles at the bottom of the rectangle,
  /// pushing every existing row up by one cell height.
  void addRow() {
    final rowIndex = _grid.length;
    final newTotalRows = rowIndex + 1;
    final row = <TileComponent?>[];
    for (var col = 0; col < columns; col++) {
      final tile = TileComponent(
        value: _random.nextInt(9) + 1,
        onTileTapped: selectionManager.onTileTapped,
        position: _positionForCell(rowIndex, col, totalRows: newTotalRows),
        size: Vector2.all(_tileSize),
      );
      row.add(tile);
      add(tile);
    }
    _grid.add(row);
    _applyLayout(animate: true);
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

    _applyLayout(animate: true);
  }
}
