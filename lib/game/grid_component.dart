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
  GridComponent({
    required this.selectionManager,
    Random? random,
    this.maxTileValue = 10,
    this.maxRows = 8,
  }) : _random = random ?? Random();

  final SelectionManager selectionManager;

  /// Tile face values are drawn from 1..[maxTileValue]. Defaults to the
  /// full 1-10 spread, the same value every difficulty tier uses.
  final int maxTileValue;

  /// Fixed 9-column board, so [_recalculateMetrics] can size it off
  /// `min(width, height)` and it shrinks/grows uniformly on any screen
  /// without ever needing to scroll or overflow its allotted space.
  static const int columns = 9;

  /// Board-full ceiling: once the grid has this many rows, [addRow] can no
  /// longer be called - see [canAddRow]. Fixed at 8 for every difficulty
  /// except [Difficulty.hard] (9 - see [Difficulty.maxRows]), which trades
  /// the extra row for smaller tiles (cell size is [game.size.y] /
  /// [maxRows], so a taller board means a smaller cell) and less starting
  /// headroom.
  final int maxRows;

  /// Tile padding as a fraction of a grid cell's width, per spec: tiles are
  /// 10% padded relative to (screen width / 9 columns).
  static const double _paddingFactor = 0.06;

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
  /// later as rows are appended - the full board always fits the
  /// canvas without clipping. The rectangle itself is sized for [maxRows]
  /// and centered once here -
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
        // A tile's size is fixed at creation time from whatever _tileSize
        // was then - if onGameResize recalculates it afterward (see
        // _recalculateMetrics), every tile already on the board would
        // otherwise keep its stale (old cell pitch) size forever, even once
        // repositioned to the new grid below. Only freshly-created tiles
        // (addRow/_topUpBottomRow, which pass the *current* _tileSize) would
        // be sized correctly, so already-placed tiles would visibly overlap
        // their neighbors until they happen to get cleared - sync every
        // active tile's size here too, not just its position.
        if (tile.size.x != _tileSize) tile.size = Vector2.all(_tileSize);
        final target = _positionForCell(row, col, totalRows: totalRows);
        if (tile.position == target) continue;
        // A previous layout pass (e.g. an earlier addRow() called in the
        // same synchronous batch, before either had a chance to tick) may
        // have left a MoveEffect for this tile still queued but not yet
        // started. Without clearing it first, both effects would fight
        // over the same tile's position once ticking begins - visible as
        // rows snapping to the wrong slot or briefly overlapping.
        //
        // This can also interrupt a tile's in-flight *shake* (see
        // TileComponent.playShakeAnimation, also a MoveEffect) - e.g. the
        // auto-row timer fires while an invalid pair is still mid-shake.
        // Flame only calls an effect's onComplete from its own update() on
        // natural completion, never from a forced removeFromParent(), so
        // silently dropping it here would strand whatever that callback was
        // guarding - the shake's onComplete is what resets the tile back to
        // idle and tells SelectionManager to release its selection, so
        // skipping it leaves both tiles selected-but-unresettable and the
        // board permanently unresponsive to taps. Fire it manually first so
        // interrupting the effect still lets its callback run.
        tile.children.whereType<MoveEffect>().toList().forEach((effect) {
          effect.onComplete?.call();
          effect.removeFromParent();
        });
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

  /// Whether calling [addRow] can do anything. True either when the
  /// bottom-most row still has spare columns to top up, or when a brand
  /// new row can be appended without exceeding [maxRows] - see [addRow].
  bool get canAddRow =>
      (_grid.isNotEmpty && _grid.last.length < columns) ||
      _grid.length < maxRows;

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

  /// Called whenever a row-add event fires - the auto-row timer's tick, or
  /// [SelectionManager]'s stuck-board recovery loop. Does two things, in
  /// order:
  ///
  /// 1. If the bottom-most row is a short one left behind by [_collapse]
  ///    (fewer than [columns] tiles, e.g. after a pair clears and the
  ///    remaining tiles reflow), tops it back up to [columns] tiles first -
  ///    see [_topUpBottomRow]. A match itself never triggers this (the short
  ///    row is left lingering, same as any other in-progress board state) -
  ///    only an actual row-add event does, so Classic's win condition (clear
  ///    every tile) stays reachable through ordinary play instead of every
  ///    match getting silently refunded by an immediate top-up.
  /// 2. Always appends a brand new, always-full row of random 1-10 tiles at
  ///    the bottom of the rectangle, pushing every existing row up by one
  ///    cell height - unless [maxRows] is already reached, in which case
  ///    only step 1 (if applicable) happens.
  ///
  /// [animate] should be `false` for the silent initial fill (several calls
  /// back-to-back with no frame tick in between, so there's nothing to
  /// smoothly animate from anyway) and `true` for every in-round row added
  /// while the player watches.
  ///
  /// Each value is rolled to differ from every already-placed neighbor
  /// touching its cell - left, directly above, and both above-diagonals
  /// (see [_nextTileValue]) - an equal-value pair sitting right next to
  /// each other, including diagonally, would be spottable at a glance,
  /// which trivializes the puzzle. This only rules out adjacency, not the
  /// pair existing on the board at all: it's still just as easy to find by
  /// looking, just not for free.
  void addRow({bool animate = true}) {
    if (_grid.isNotEmpty && _grid.last.length < columns) {
      _topUpBottomRow(animate: animate);
    }
    if (_grid.length >= maxRows) return;

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

  /// Fills the missing columns of the current bottom row up to [columns]
  /// tiles - see [addRow]'s doc for why this exists instead of always
  /// appending a new row. Row count ([_grid.length]) doesn't change, so
  /// unlike a genuinely new row this never shifts any other row's slot.
  void _topUpBottomRow({required bool animate}) {
    final rowIndex = _grid.length - 1;
    final row = _grid[rowIndex];
    final rowAbove = rowIndex > 0 ? _grid[rowIndex - 1] : null;
    final totalRows = _grid.length;
    for (var col = row.length; col < columns; col++) {
      final tile = TileComponent(
        value: _nextTileValue(col: col, row: row, rowAbove: rowAbove),
        onTileTapped: selectionManager.onTileTapped,
        position: _positionForCell(rowIndex, col, totalRows: totalRows),
        size: Vector2.all(_tileSize),
      );
      row.add(tile);
      add(tile);
    }
    _applyLayout(animate: animate);
  }

  /// Rolls a random 1..[maxTileValue] value for the cell at [col] in the
  /// row currently being built, excluding whatever sits immediately to its
  /// left (already in [row]) and every already-placed neighbor directly
  /// above it (in [rowAbove], the previous row - `null` for the very first
  /// row): straight above plus both above-diagonals. Falls back to just
  /// excluding left/above (guaranteed to leave a non-empty pool, since at
  /// most 2 of [maxTileValue] 10 values get excluded that way) on the rare
  /// board where all four neighbors already cover every value in range.
  int _nextTileValue({
    required int col,
    required List<TileComponent?> row,
    required List<TileComponent?>? rowAbove,
  }) {
    final left = col > 0 ? row[col - 1]?.value : null;
    final above =
        (rowAbove != null && col < rowAbove.length) ? rowAbove[col]?.value : null;
    final aboveLeft =
        (rowAbove != null && col > 0 && col - 1 < rowAbove.length)
            ? rowAbove[col - 1]?.value
            : null;
    final aboveRight =
        (rowAbove != null && col + 1 < rowAbove.length) ? rowAbove[col + 1]?.value : null;

    final excluded = {
      if (left != null) left,
      if (above != null) above,
      if (aboveLeft != null) aboveLeft,
      if (aboveRight != null) aboveRight,
    };
    final allowed = [
      for (var value = 1; value <= maxTileValue; value++)
        if (!excluded.contains(value)) value,
    ];
    if (allowed.isNotEmpty) return allowed[_random.nextInt(allowed.length)];

    final relaxedExcluded = {if (left != null) left, if (above != null) above};
    final relaxed = [
      for (var value = 1; value <= maxTileValue; value++)
        if (!relaxedExcluded.contains(value)) value,
    ];
    return relaxed[_random.nextInt(relaxed.length)];
  }

  /// Fills the *entire* board in one shot - every one of [maxRows] x
  /// [columns] cells gets a tile except [emptyCells] left blank, rather
  /// than growing row by row from the bottom like [addRow]. Used only by
  /// the Daily Challenge's Rush mode, where the whole board exists from
  /// the first frame and there's no rising stack to grow.
  ///
  /// [emptyCells] defaults to whatever keeps the remaining tile count
  /// (board size minus [emptyCells]) even - 1 if [columns] * [maxRows] is
  /// odd, 0 if it's already even - since an odd remaining count would leave
  /// one tile mathematically unmatchable and the board impossible to ever
  /// fully clear.
  ///
  /// Values are placed in matched pairs (equal-value, or summing to 10)
  /// whose two cells are [pairDistanceRange] apart (Chebyshev distance -
  /// diagonal neighbors count as distance 1), with [sumPairChance]
  /// governing the split between the two pair types. This guarantees the
  /// board is fully clearable by construction: every tile has at least the
  /// partner it was planted with, even before counting any incidental
  /// matches elsewhere on the board.
  void fillRushBoard({
    required ({int min, int max}) pairDistanceRange,
    required double sumPairChance,
    int? emptyCells,
  }) {
    emptyCells ??= (columns * maxRows).isOdd ? 1 : 0;
    final cells = [
      for (var row = 0; row < maxRows; row++)
        for (var col = 0; col < columns; col++) (row, col),
    ]..shuffle(_random);

    // The first `emptyCells` never get assigned a value below - they stay
    // blank, which is what makes the remaining count even.
    final unfilled = cells.skip(emptyCells).toList();
    final values = <(int, int), int>{};

    while (unfilled.isNotEmpty) {
      final anchor = unfilled.removeLast();
      final candidates = unfilled
          .where((cell) => _withinDistance(anchor, cell, pairDistanceRange))
          .toList();
      // The distance band can't always be satisfied once only a handful of
      // (already-constrained) cells remain - fall back to whatever's left
      // rather than getting stuck with an unplaced cell.
      final partner = candidates.isEmpty
          ? unfilled[_random.nextInt(unfilled.length)]
          : candidates[_random.nextInt(candidates.length)];
      unfilled.remove(partner);

      final value = 1 + _random.nextInt(maxTileValue);
      final complement = 10 - value;
      // A sum-to-10 pair needs its complement to also be a legal value in
      // range (a 10 has no legal complement - 10 + 0 isn't a real tile) -
      // fall back to an equal-value pair when it isn't, still a perfectly
      // valid pair either way.
      final canSumPair = complement >= 1 && complement <= maxTileValue;
      final wantsSumPair = _random.nextDouble() < sumPairChance;
      final partnerValue = (wantsSumPair && canSumPair) ? complement : value;

      values[anchor] = value;
      values[partner] = partnerValue;
    }

    for (var row = 0; row < maxRows; row++) {
      final rowTiles = <TileComponent?>[];
      for (var col = 0; col < columns; col++) {
        final value = values[(row, col)];
        if (value == null) {
          rowTiles.add(null);
          continue;
        }
        final tile = TileComponent(
          value: value,
          onTileTapped: selectionManager.onTileTapped,
          position: _positionForCell(row, col, totalRows: maxRows),
          size: Vector2.all(_tileSize),
        );
        rowTiles.add(tile);
        add(tile);
      }
      _grid.add(rowTiles);
    }
    _applyLayout(animate: false);
  }

  /// Chebyshev distance (the max of the row and column deltas, so diagonal
  /// neighbors count as distance 1 same as orthogonal ones) between two
  /// cells, checked against [range].
  bool _withinDistance(
    (int, int) a,
    (int, int) b,
    ({int min, int max}) range,
  ) {
    final distance = max((a.$1 - b.$1).abs(), (a.$2 - b.$2).abs());
    return distance >= range.min && distance <= range.max;
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

  /// All non-null tiles currently in the bottom-most row - what the
  /// clear-row power-up (see [SelectionManager.clearRow]) animates before
  /// removing. Empty if the board has no rows yet.
  List<TileComponent> get bottomRowTiles => _grid.isEmpty
      ? const []
      : [for (final tile in _grid.last) if (tile != null) tile];

  /// Clear-row power-up: removes every remaining tile in the bottom-most
  /// row outright, no matching required, then reflows the rest of the
  /// stack to fill the gap - the same reading-order collapse [removePair]
  /// uses after a normal match.
  void clearBottomRow() {
    if (_grid.isEmpty) return;
    final bottomRow = _grid.last;
    for (var col = 0; col < bottomRow.length; col++) {
      bottomRow[col]?.removeFromParent();
      bottomRow[col] = null;
    }
    _collapse();
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

  /// Reflows every remaining tile into compact rows in reading order after
  /// a removal (a matched pair, or the whole bottom row via the clear-row
  /// power-up). This can leave the new bottom-most row short (fewer than
  /// [columns] tiles) if the remaining count isn't a multiple of [columns] -
  /// left as-is here rather than topped up immediately (see [addRow]'s doc
  /// for why: an immediate top-up on every match would refund tiles almost
  /// as fast as they're cleared, making Classic's "clear every tile to win"
  /// condition practically unreachable through ordinary play).
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
