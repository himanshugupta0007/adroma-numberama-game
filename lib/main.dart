import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'state/difficulty.dart';
import 'state/preferences_service.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AdService.instance.initialize();
  });
  await Hive.initFlutter();
  final box = await Hive.openBox(PreferencesService.boxName);
  final prefs = PreferencesService(box);
  prefs.registerAppOpened();

  await NotificationService.instance.initialize();
  // Scheduled notifications aren't guaranteed to survive app
  // updates/reinstalls, so the "ready" reminder is re-armed on every launch
  // (not just right after a round is played) whenever it's still meant to be
  // on. If a cycle is already unlocked (no cooldown pending), there's
  // nothing to count down to yet, so this arms a fresh full-length cycle
  // from now rather than firing immediately.
  if (prefs.dailyReminderEnabled) {
    final now = DateTime.now();
    final remaining = prefs.timeUntilNextDailyCycle(now);
    await NotificationService.instance.scheduleDailyReadyReminder(
      now.add(remaining > Duration.zero ? remaining : dailyCycleDuration),
    );
  }

  runApp(
    ProviderScope(
      overrides: [preferencesBoxProvider.overrideWithValue(box)],
      child: const NumberamaApp(),
    ),
  );
}

class NumberamaApp extends StatelessWidget {
  const NumberamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Numberama',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const HomeScreen(),
    );
  }
}
