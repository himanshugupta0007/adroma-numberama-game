import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/numberama_game.dart';
import 'state/game_state.dart';

void main() {
  runApp(const ProviderScope(child: NumberamaApp()));
}

/// Boots straight into the game loop, no menus/HUD/screens yet - those are
/// deliberately out of scope for this milestone.
class NumberamaApp extends ConsumerWidget {
  const NumberamaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameStateNotifier = ref.read(gameStateProvider.notifier);
    return MaterialApp(
      title: 'Numberama',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: GameWidget(
          game: NumberamaGame(gameStateNotifier: gameStateNotifier),
        ),
      ),
    );
  }
}
