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
  static final _gameOverClip = AssetSource('sounds/game-over.mp3');

  final _matchPlayer = AudioPlayer();
  final _mismatchPlayer = AudioPlayer();
  final _powerUpPlayer = AudioPlayer();
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

  /// The round just ended - board cleared (win) or stuck with nowhere left
  /// to grow (loss). Same clip covers both, same reasoning as
  /// [playPowerUp]: it's the "round over" cue, not a verdict on the
  /// outcome - the results screen is what actually tells the player win vs.
  /// loss.
  void playGameOver() => _play(_gameOverPlayer, _gameOverClip);

  /// One dedicated player per fixed clip above avoids two overlapping SFX
  /// cutting each other off; a dynamic one-off (achievement toasts today,
  /// reused for badges later - see `AchievementEvent.soundAsset`) has no
  /// fixed clip to dedicate a player to, so it gets a fresh one per call
  /// instead. These fire rarely enough (level-ups, badge unlocks) that
  /// overlap with each other is a non-issue in practice.
  void playOneOff(String assetPath) {
    if (!_enabled) return;
    final player = AudioPlayer();
    unawaited(
      player.play(AssetSource(assetPath)).catchError((_) {}).whenComplete(
            player.dispose,
          ),
    );
  }

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
