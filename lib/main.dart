import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'state/preferences_service.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Deferred to after the first frame renders, not kicked off here - the
  // Mobile Ads SDK's own native init plus the UMP consent round-trip are
  // real, sometimes-slow work (network-bound), and none of it gates
  // anything the app needs to show its first screen. Starting it only once
  // the player can already see and interact with Home keeps that init
  // from competing with Firebase/Hive/notifications for the same startup
  // window - every ad call site already tolerates "not ready yet" (see
  // AdService.isInterstitialReady/isRewardedReady, and AdBannerWidget
  // rendering nothing until its ad actually loads), so nothing is lost by
  // the banner/interstitial/rewarded ads simply becoming ready a little
  // later than before.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    AdService.instance.initialize();
  });
  await Hive.initFlutter();
  final box = await Hive.openBox(PreferencesService.boxName);
  final prefs = PreferencesService(box);
  prefs.registerAppOpened();

  await NotificationService.instance.initialize();
  // Scheduled notifications aren't guaranteed to survive app
  // updates/reinstalls, so the streak reminder is re-armed on every launch
  // (not just when the toggle is first switched on) whenever it's still
  // meant to be on.
  if (prefs.dailyReminderEnabled) {
    await NotificationService.instance.scheduleStreakReminder();
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
