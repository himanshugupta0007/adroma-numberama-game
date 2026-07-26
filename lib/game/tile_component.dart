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

  /// The face value of this tile, 1-9. Mutable only for the shuffle
  /// power-up (see [setValue]) - every other rule in the game treats a
  /// tile's value as fixed for its lifetime.
  int value;

  /// Callback invoked on tap. SelectionManager passes itself in via this
  /// function reference so the tile never needs to know about it directly.
  final void Function(TileComponent tile) onTileTapped;

  TileVisualState visualState = TileVisualState.idle;

  /// Whether the hint power-up is currently pulsing this tile. Kept
  /// separate from [visualState] (rather than adding a `hint` case) since a
  /// hint is a transient highlight, not an interaction-gating state - the
  /// tile stays tappable and idle/selected logic is unaffected while it's
  /// hinted.
  bool isHinted = false;

  static const _idleColor = AppColors.surfaceRaised;
  static const _selectedColor = AppColors.amber;
  static const _idleTextColor = AppColors.textMid;
  static const _selectedTextColor = AppColors.bgNavy;
  static const _hintRingColor = AppColors.teal;
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

    if (isHinted) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = _hintRingColor,
      );
    }

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
    // TODO(sound): trigger tile-tap sound effect here - needs a dedicated
    // clip; every existing SFX already fires on the 2nd tile of a pair
    // (match/mismatch), so reusing one here would double up on that tap.
    onTileTapped(this);
  }

  /// Toggles idle <-> selected. Called by SelectionManager once it has
  /// decided a tap should register as a selection.
  void setSelected(bool selected) {
    if (visualState == TileVisualState.clearing) return;
    visualState = selected ? TileVisualState.selected : TileVisualState.idle;
  }

  /// Reassigns the number this tile displays, for the shuffle power-up.
  /// Deliberately doesn't touch position/identity/callbacks - only the
  /// rendered face value changes, which [render] picks up on its next
  /// frame with no extra signal needed.
  void setValue(int newValue) {
    value = newValue;
  }

  /// The shuffle power-up's "flip" flourish: squashes flat on the
  /// horizontal axis, swaps to [newValue] at the midpoint (while the tile
  /// is edge-on and the old number isn't visible), then unfolds back open -
  /// a card-flip read rather than the number just silently changing. The
  /// returned future resolves once the reveal finishes, so callers can
  /// stagger many tiles without their effects colliding.
  Future<void> playShuffleAnimation(int newValue) {
    final completer = Completer<void>();
    // Sound plays once per shuffle in SelectionManager.shuffle(), not once
    // per tile here.
    add(
      ScaleEffect.to(
        Vector2(0, 1),
        EffectController(duration: 0.12, curve: Curves.easeIn),
        onComplete: () {
          value = newValue;
          add(
            ScaleEffect.to(
              Vector2(1, 1),
              EffectController(duration: 0.15, curve: Curves.easeOut),
              onComplete: () => completer.complete(),
            ),
          );
        },
      ),
    );
    return completer.future;
  }

  /// The hint power-up's flourish: rings the tile and pulses it up and back
  /// twice, then drops the ring. Deliberately leaves [visualState] alone -
  /// unlike selection/clear/shake, a hint doesn't gate interaction, it's
  /// just pointing at a pair the player can still tap for themselves. The
  /// returned future resolves once the pulse finishes, so callers can await
  /// both tiles in the hinted pair.
  Future<void> playHintAnimation() {
    final completer = Completer<void>();
    isHinted = true;
    // Sound plays once per hint in SelectionManager.hint(), not once per
    // tile here.
    add(
      ScaleEffect.to(
        Vector2.all(1.12),
        EffectController(
          duration: 0.22,
          curve: Curves.easeInOut,
          alternate: true,
          repeatCount: 2,
        ),
        onComplete: () {
          isHinted = false;
          completer.complete();
        },
      ),
    );
    return completer.future;
  }

  /// Plays the "valid pair" clear animation and removes this tile from the
  /// component tree once it finishes. The returned future resolves when the
  /// animation completes, so callers can await both tiles in a pair.
  Future<void> playClearAnimation() {
    visualState = TileVisualState.clearing;
    final completer = Completer<void>();
    // Sound plays once per pair in SelectionManager._handleValidPair, not
    // once per tile here.
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
    // Sound plays once per pair in SelectionManager._handleInvalidPair,
    // not once per tile here.
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
