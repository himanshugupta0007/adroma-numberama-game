import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin wrapper around the game's four short SFX clips (`assets/sounds/`).
/// One dedicated [AudioPlayer] per clip rather than a single shared player,
/// so two different sounds firing close together (e.g. a match clearing
/// right as the final countdown kicks in) don't cut each other off.
///
/// A plain singleton, same shape as [NotificationService] - Flame's game
/// object tree ([SelectionManager], [NumberamaGame], [TileComponent]) has
/// no reachable Riverpod `ref`, so [setEnabled] is how `GameplayScreen`
/// threads the Settings "Sound Effects" toggle in once per round instead
/// of every call site needing its own `PreferencesService` read.
class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static final _matchClip = AssetSource('sounds/match-sound.mp3');
  static final _mismatchClip = AssetSource('sounds/mis-match-sound.mp3');
  static final _powerUpClip = AssetSource('sounds/shuffle-powerup.mp3');
  static final _finalCountdownClip = AssetSource('sounds/final-count-down.mp3');
  static final _gameOverClip = AssetSource('sounds/game-over.mp3');

  final _matchPlayer = AudioPlayer();
  final _mismatchPlayer = AudioPlayer();
  final _powerUpPlayer = AudioPlayer();
  final _finalCountdownPlayer = AudioPlayer();
  final _gameOverPlayer = AudioPlayer();

  bool _enabled = true;

  /// Threaded in once per round from Settings' "Sound Effects" toggle -
  /// see class doc for why this can't just read `PreferencesService`
  /// directly.
  void setEnabled(bool enabled) => _enabled = enabled;

  /// A valid pair was cleared.
  void playMatch() => _play(_matchPlayer, _matchClip);

  /// An invalid pair was tapped.
  void playMismatch() => _play(_mismatchPlayer, _mismatchClip);

  /// Shuffle or hint power-up used - the same clip covers both by design,
  /// not an omission.
  void playPowerUp() => _play(_powerUpPlayer, _powerUpClip);

  /// A handful of seconds left before the round can end - Classic once the
  /// stack is full and stuck (see `NumberamaGame.update`), Daily Rush once
  /// the countdown is nearly out (see `NumberamaGame._tickRushCountdown`).
  void playFinalCountdown() =>
      _play(_finalCountdownPlayer, _finalCountdownClip);

  /// The round just ended - board cleared (win) or stuck with nowhere left
  /// to grow (loss). Same clip covers both, same reasoning as
  /// [playPowerUp]: it's the "round over" cue, not a verdict on the
  /// outcome - the results screen is what actually tells the player win vs.
  /// loss.
  void playGameOver() => _play(_gameOverPlayer, _gameOverClip);

  void _play(AudioPlayer player, Source clip) {
    if (!_enabled) return;
    // Never let an audio backend hiccup (a platform channel error, a
    // missing/corrupt asset) take the round down with it - SFX is
    // decoration, not gameplay-critical.
    unawaited(player.play(clip).catchError((_) {}));
  }
}

final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService.instance;
});
