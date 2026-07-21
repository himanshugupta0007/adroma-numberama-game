import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Visual/interaction state of a tile. Purely presentational - whether a
/// tile *should* be selected, cleared, etc. is decided by SelectionManager,
/// never by this component itself.
enum TileVisualState { idle, selected, clearing, shaking }

/// Renders a single number tile and reports taps upward. Contains no game
/// rules (no pairing/validity logic, no score/move bookkeeping) - all of
/// that lives in SelectionManager.
class TileComponent extends PositionComponent with TapCallbacks {
  TileComponent({
    required this.value,
    required this.onTileTapped,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.topLeft);

  /// The face value of this tile, 1-9.
  final int value;

  /// Callback invoked on tap. SelectionManager passes itself in via this
  /// function reference so the tile never needs to know about it directly.
  final void Function(TileComponent tile) onTileTapped;

  TileVisualState visualState = TileVisualState.idle;

  static const _idleColor = AppColors.surfaceRaised;
  static const _selectedColor = AppColors.amber;
  static const _idleTextColor = AppColors.textMid;
  static const _selectedTextColor = AppColors.bgNavy;
  static const _cornerRadiusFactor = 0.16;

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.x * _cornerRadiusFactor),
    );

    final isSelected = visualState == TileVisualState.selected;
    final bgColor = isSelected ? _selectedColor : _idleColor;
    canvas.drawRRect(rrect, Paint()..color = bgColor);

    final textColor = isSelected ? _selectedTextColor : _idleTextColor;
    final textPaint = TextPaint(
      style: AppTextStyles.mono(
        size.y * 0.5,
        weight: FontWeight.bold,
        color: textColor,
      ),
    );
    textPaint.render(
      canvas,
      '$value',
      Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    // Ignore taps while an animation owns this tile's state.
    if (visualState == TileVisualState.clearing) return;
    // TODO(sound): trigger tile-tap sound effect here.
    onTileTapped(this);
  }

  /// Toggles idle <-> selected. Called by SelectionManager once it has
  /// decided a tap should register as a selection.
  void setSelected(bool selected) {
    if (visualState == TileVisualState.clearing) return;
    visualState = selected ? TileVisualState.selected : TileVisualState.idle;
  }

  /// Plays the "valid pair" clear animation and removes this tile from the
  /// component tree once it finishes. The returned future resolves when the
  /// animation completes, so callers can await both tiles in a pair.
  Future<void> playClearAnimation() {
    visualState = TileVisualState.clearing;
    final completer = Completer<void>();
    // TODO(sound): trigger "match cleared" sound effect here.
    add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.2, curve: Curves.easeIn),
        onComplete: () {
          removeFromParent();
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  /// Plays the "invalid pair" shake animation. Resets to idle when done via
  /// [onComplete] so SelectionManager can clear its selection at the right
  /// moment.
  void playShakeAnimation({VoidCallback? onComplete}) {
    visualState = TileVisualState.shaking;
    final shakeDistance = size.x * 0.08;
    // TODO(sound): trigger "invalid pair" sound effect here.
    add(
      MoveEffect.by(
        Vector2(shakeDistance, 0),
        EffectController(
          duration: 0.05,
          alternate: true,
          repeatCount: 4,
        ),
        onComplete: () {
          visualState = TileVisualState.idle;
          onComplete?.call();
        },
      ),
    );
  }
}
