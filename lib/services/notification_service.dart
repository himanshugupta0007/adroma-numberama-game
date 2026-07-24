import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and cancels Numberama's single local notification - the daily
/// streak reminder. UI-independent: nothing in here reads `BuildContext` or
/// Riverpod state, so the Settings screen and the gameplay completion flow
/// can both call straight into it.
///
/// The reminder is deliberately a one-shot, not an OS-level repeating
/// notification (`matchDateTimeComponents`) - it's rescheduled for the next
/// day explicitly, either by [skipTodaysReminder] (today's board already
/// played) or by the app re-arming it on every launch (see `main.dart`).
/// That's the only re-arm path this pass has: without a background-execution
/// package (e.g. `workmanager`, out of scope here), there's no code running
/// to chain a one-shot into the next day's while the app is fully closed and
/// its notification simply fires unopened. In practice that's fine - the
/// player opens the app at least once before the next fire time in the
/// overwhelming majority of cases, and re-arming on launch covers it.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _streakReminderId = 1001;
  static const _defaultReminderTime = TimeOfDay(hour: 20, minute: 0);
  static const _reminderTitle = "Don't lose your streak!";
  static const _reminderBody =
      "You haven't played today — keep your streak alive.";

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _timezoneReady = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    // Alert/badge/sound permission is requested explicitly from
    // requestPermission() only when the player turns the Streak Reminder
    // toggle on - never implicitly here, since initialize() runs on every
    // launch regardless of the setting.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
    await _ensureTimezone();
  }

  Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Leaves tz.local on the package's UTC default - the reminder still
      // fires, just potentially off by the device's UTC offset until a
      // later call succeeds.
    }
    _timezoneReady = true;
  }

  /// Requests OS notification permission and reports whether it was
  /// granted. Only ever called from the Settings screen when the player
  /// turns Streak Reminder on - never at app launch.
  ///
  /// Android: on API 33+ this shows the real system prompt for
  /// `POST_NOTIFICATIONS`; on older Android there's no such runtime
  /// permission and the plugin resolves `true` immediately. iOS: standard
  /// alert/sound/badge authorization prompt.
  Future<bool> requestPermission() async {
    await initialize();

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission() ?? false;
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final macImpl = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macImpl != null) {
      return await macImpl.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    // No platform-specific implementation resolved (e.g. desktop/web in
    // tests) - nothing to gate on those targets.
    return true;
  }

  /// Schedules the next occurrence of the streak reminder at [time]
  /// (today if it hasn't passed yet, otherwise tomorrow). Uses a fixed
  /// notification id so a repeat call cleanly replaces whatever was
  /// previously pending rather than stacking a second one.
  ///
  /// `androidScheduleMode: inexactAllowWhileIdle` is deliberate - this
  /// reminder doesn't need to-the-second precision, and inexact mode is the
  /// one that never requires Android's separate exact-alarm permission.
  Future<void> scheduleStreakReminder({
    TimeOfDay time = _defaultReminderTime,
  }) async {
    await initialize();
    await _plugin.zonedSchedule(
      id: _streakReminderId,
      title: _reminderTitle,
      body: _reminderBody,
      scheduledDate: _nextInstanceOfTime(time),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelStreakReminder() =>
      _plugin.cancel(id: _streakReminderId);

  /// Cancels only the next pending fire and immediately re-schedules the
  /// following day's, without the user touching the toggle - called when
  /// the player completes today's Daily Challenge.
  ///
  /// If today's reminder time has already passed, whatever is currently
  /// pending is already tomorrow's occurrence (see [_nextInstanceOfTime]),
  /// so there's nothing to skip and this is a no-op.
  Future<void> skipTodaysReminder({
    TimeOfDay time = _defaultReminderTime,
  }) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    final todayAtTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!todayAtTime.isAfter(now)) return;

    await _plugin.zonedSchedule(
      id: _streakReminderId,
      title: _reminderTitle,
      body: _reminderBody,
      scheduledDate: todayAtTime.add(const Duration(days: 1)),
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak_reminder',
      'Streak Reminders',
      channelDescription: 'Daily reminder to keep your Numberama streak alive',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
