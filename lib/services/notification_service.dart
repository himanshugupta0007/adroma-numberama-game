import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../state/difficulty.dart';

/// Schedules and cancels Numberama's single local notification - the Daily
/// Challenge "ready" reminder. UI-independent: nothing in here reads
/// `BuildContext` or Riverpod state, so the Settings screen and the gameplay
/// completion flow can both call straight into it.
///
/// The reminder is a one-shot, not an OS-level repeating notification
/// (`matchDateTimeComponents`) - it targets the exact instant the Daily
/// Challenge's [dailyCycleDuration] cooldown ends (see
/// [scheduleDailyReadyReminder]), so it's rescheduled explicitly every time
/// that instant changes: right after a Daily round is played (see
/// `gameplay_screen.dart`) and by the app re-arming it on every launch (see
/// `main.dart`), since a scheduled notification isn't guaranteed to survive
/// an app update/reinstall.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _streakReminderId = 1001;
  static const _reminderTitle = 'New Daily Challenge ready!';
  static const _reminderBody =
      'Your next board just unlocked — keep the streak alive.';

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

  /// Schedules the Daily Challenge "ready" reminder to fire at [unlockAt] -
  /// normally `lastPlayed + dailyCycleDuration`, i.e. the exact instant the
  /// next board unlocks (see `gameplay_screen.dart` and `main.dart`, its two
  /// call sites). Uses a fixed notification id so a repeat call cleanly
  /// replaces whatever was previously pending rather than stacking a second
  /// one. A past [unlockAt] (e.g. the app was closed well past the last
  /// cycle's unlock) is clamped to fire immediately rather than being
  /// silently dropped.
  ///
  /// `androidScheduleMode: inexactAllowWhileIdle` is deliberate - this
  /// reminder doesn't need to-the-second precision, and inexact mode is the
  /// one that never requires Android's separate exact-alarm permission.
  Future<void> scheduleDailyReadyReminder(DateTime unlockAt) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime.from(unlockAt, tz.local);
    if (!scheduled.isAfter(now)) {
      scheduled = now.add(const Duration(seconds: 1));
    }
    await _plugin.zonedSchedule(
      id: _streakReminderId,
      title: _reminderTitle,
      body: _reminderBody,
      scheduledDate: scheduled,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelStreakReminder() =>
      _plugin.cancel(id: _streakReminderId);

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'streak_reminder',
      'Streak Reminders',
      channelDescription:
          'Lets you know when your next Daily Challenge board is ready',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});
