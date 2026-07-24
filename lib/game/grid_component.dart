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

  /// Fixed 9x9 board - square on purpose, so [_recalculateMetrics] can size
  /// it off `min(width, height)` and it shrinks/grows uniformly on any
  /// screen without ever needing to scroll or overflow its allotted space.
  static const int columns = 9;

  /// Board-full ceiling: once the grid has this many rows, [addRow] can no
  /// longer be called - see [canAddRow].
  static const int maxRows = 9;

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
  /// later as rows are appended - the full 9x9 board always fits the
  /// canvas without clipping, and shrinks uniformly (never scrolls) on a
  /// shorter screen since both axes are divided by the same 9. The
  /// rectangle itself is sized for [maxRows] and centered once here -
  /// unlike tile layout, it never moves as rows are added or cleared,
  /// since it represents the fixed play-field boundary, not the current
  /// stack height.
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
        // A previous layout pass (e.g. an earlier addRow() called in the
        // same synchronous batch, before either had a chance to tick) may
        // have left a MoveEffect for this tile still queued but not yet
        // started. Without clearing it first, both effects would fight
        // over the same tile's position once ticking begins - visible as
        // rows snapping to the wrong slot or briefly overlapping.
        tile.children.whereType<MoveEffect>().toList().forEach(
              (effect) => effect.removeFromParent(),
            );
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
  /// pushing every existing row up by one cell height. [animate] should be
  /// `false` for the silent initial fill (several calls back-to-back with
  /// no frame tick in between, so there's nothing to smoothly animate from
  /// anyway) and `true` for every in-round row added while the player watches.
  ///
  /// Each value is rolled to differ from its left neighbor and from the
  /// tile directly above it (see [_nextTileValue]) - an equal-value pair
  /// sitting right next to each other would be spottable at a glance,
  /// which trivializes the puzzle. This only rules out adjacency, not the
  /// pair existing on the board at all: it's still just as easy to find by
  /// looking, just not for free.
  void addRow({bool animate = true}) {
    final rowIndex = _grid.length;
    final newTotalRows = rowIndex + 1;
    final rowAbove = _grid.isNotEmpty ? _grid.last : null;
    final row = <TileComponent?>[];
    for (var col = 0; col < columns; col++) {
      final tile = TileComponent(
        value: _nextTileValue(col: col, row: row, rowAbove: rowAbove),
        onTileTapped: selectionManager.onTileTapped,
        position: _positionForCell(rowIndex, col, totalRows: newTotalRows),
        size: Vector2.all(_tileSize),
      );
      row.add(tile);
      add(tile);
    }
    _grid.add(row);
    _applyLayout(animate: animate);
  }

  /// Rolls a random 1-9 value for the cell at [col] in the row currently
  /// being built, excluding whatever sits immediately to its left (already
  /// in [row]) and immediately above it (in [rowAbove], the previous row -
  /// `null` for the very first row). Excluding at most two values out of
  /// nine always leaves a non-empty pool, so this can pick directly from
  /// the allowed set instead of rerolling.
  int _nextTileValue({
    required int col,
    required List<TileComponent?> row,
    required List<TileComponent?>? rowAbove,
  }) {
    final left = col > 0 ? row[col - 1]?.value : null;
    final above =
        (rowAbove != null && col < rowAbove.length) ? rowAbove[col]?.value : null;
    final excluded = {if (left != null) left, if (above != null) above};

    final allowed = [
      for (var value = 1; value <= 9; value++)
        if (!excluded.contains(value)) value,
    ];
    return allowed[_random.nextInt(allowed.length)];
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

  /// Delay between one tile starting its flip and the next - small enough
  /// that the whole board still reads as "one shuffle", large enough that
  /// it visibly ripples across the board rather than every tile flipping
  /// in a single flat instant.
  static const Duration _shuffleStagger = Duration(milliseconds: 18);

  /// Randomly redistributes the values of every tile currently on the
  /// board among themselves - positions/identities don't change, only
  /// which number each occupied cell shows - then plays a staggered flip
  /// reveal across the board. Retries the redistribution (up to
  /// [maxAttempts] times) until [isAcceptable] holds for the candidate
  /// values, in [activeTiles] order; if nothing satisfies it, the last
  /// attempt is used anyway rather than leaving the shuffle a no-op. Used
  /// by [SelectionManager]'s shuffle power-up, which owns *what* counts as
  /// acceptable (i.e. "leaves a valid pair") - this method only owns the
  /// randomization/animation.
  Future<void> shuffleTileValues({
    required bool Function(List<int> values) isAcceptable,
    int maxAttempts = 30,
  }) async {
    final tiles = activeTiles;
    if (tiles.length < 2) return;

    final originalValues = [for (final tile in tiles) tile.value];
    var candidate = originalValues;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      candidate = List<int>.from(originalValues)..shuffle(_random);
      if (isAcceptable(candidate)) break;
    }

    Future<void> reveal(int i) async {
      if (i > 0) await Future<void>.delayed(_shuffleStagger * i);
      await tiles[i].playShuffleAnimation(candidate[i]);
    }

    await Future.wait([for (var i = 0; i < tiles.length; i++) reveal(i)]);
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
