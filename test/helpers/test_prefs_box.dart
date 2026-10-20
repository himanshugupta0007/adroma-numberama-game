import 'dart:typed_data';

import 'package:hive/hive.dart';

/// Bumped per call so each test's Hive box gets a unique name - Hive keeps
/// open boxes cached by name for the life of the test process, so reusing
/// one across tests would leak state.
int _boxCounter = 0;

/// Opens a fresh, in-memory Hive box seeded with [initial].
///
/// In-memory (via `bytes:`) rather than file-backed on purpose: `testWidgets`
/// runs on a fake clock, and real disk I/O awaited on that clock never
/// completes - opening, writing to or closing a file-backed box from a
/// widget test hangs until the whole run is killed.
Future<Box> openTestPrefsBox({Map<String, Object?> initial = const {}}) async {
  final box =
      await Hive.openBox('prefs_${_boxCounter++}', bytes: Uint8List(0));
  await box.putAll(initial);
  return box;
}
