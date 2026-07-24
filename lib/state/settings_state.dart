import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preferences_service.dart';

/// Immutable snapshot of every user-facing toggle on the Settings screen.
///
/// Unlike [GameState] this isn't reset between rounds - it's loaded once
/// from [PreferencesService] when [settingsStateProvider] is first read and
/// stays in sync with it for the rest of the app's lifetime, so any widget
/// (not just the Settings screen) can watch a single toggle without going
/// through Hive directly.
class SettingsState {
  const SettingsState({
    this.soundEnabled = true,
    this.hapticsEnabled = true,
    this.dailyReminderEnabled = false,
    this.reduceMotionEnabled = false,
    this.colorblindPaletteEnabled = false,
  });

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool dailyReminderEnabled;
  final bool reduceMotionEnabled;
  final bool colorblindPaletteEnabled;

  SettingsState copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? dailyReminderEnabled,
    bool? reduceMotionEnabled,
    bool? colorblindPaletteEnabled,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      reduceMotionEnabled: reduceMotionEnabled ?? this.reduceMotionEnabled,
      colorblindPaletteEnabled:
          colorblindPaletteEnabled ?? this.colorblindPaletteEnabled,
    );
  }
}

/// Holds the live [SettingsState] and mirrors every change straight to
/// [PreferencesService] so a value set here survives a restart with no
/// separate "save" step.
///
/// [dailyReminderEnabled] is the one exception worth calling out: flipping
/// it involves an async permission round-trip (and, on grant, scheduling a
/// real notification) that this notifier has no business owning - the
/// Settings screen drives that flow itself via `NotificationService` and
/// only calls [setDailyReminderEnabled] once the outcome (granted or not)
/// is already known, so this class never has to represent an
/// "in-flight/pending" toggle state.
class SettingsStateNotifier extends StateNotifier<SettingsState> {
  SettingsStateNotifier(this._prefs)
      : super(
          SettingsState(
            soundEnabled: _prefs.soundEnabled,
            hapticsEnabled: _prefs.hapticsEnabled,
            dailyReminderEnabled: _prefs.dailyReminderEnabled,
            reduceMotionEnabled: _prefs.reduceMotionEnabled,
            colorblindPaletteEnabled: _prefs.colorblindPaletteEnabled,
          ),
        );

  final PreferencesService _prefs;

  void setSoundEnabled(bool value) {
    state = state.copyWith(soundEnabled: value);
    _prefs.setSoundEnabled(value);
  }

  void setHapticsEnabled(bool value) {
    state = state.copyWith(hapticsEnabled: value);
    _prefs.setHapticsEnabled(value);
  }

  void setDailyReminderEnabled(bool value) {
    state = state.copyWith(dailyReminderEnabled: value);
    _prefs.setDailyReminderEnabled(value);
  }

  void setReduceMotionEnabled(bool value) {
    state = state.copyWith(reduceMotionEnabled: value);
    _prefs.setReduceMotionEnabled(value);
  }

  void setColorblindPaletteEnabled(bool value) {
    state = state.copyWith(colorblindPaletteEnabled: value);
    _prefs.setColorblindPaletteEnabled(value);
  }

  /// Snaps every toggle back to first-launch defaults - [_prefs] has
  /// already been wiped by the caller (Settings' "Reset Progress" action)
  /// by the time this runs, so this only needs to bring in-memory state
  /// back in line with it.
  void resetToDefaults() {
    state = const SettingsState();
  }
}

final settingsStateProvider =
    StateNotifierProvider<SettingsStateNotifier, SettingsState>((ref) {
  return SettingsStateNotifier(ref.watch(preferencesServiceProvider));
});
