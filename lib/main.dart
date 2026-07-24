import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'state/preferences_service.dart';
import 'theme/app_theme.dart';
import 'ui/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox(PreferencesService.boxName);
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
