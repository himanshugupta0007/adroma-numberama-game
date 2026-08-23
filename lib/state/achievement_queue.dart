import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One toast-worthy celebration moment - a level-up today, a badge unlock
/// later. Deliberately generic: nothing in this file (or the toast that
/// renders it) knows what kind of achievement it represents.
class AchievementEvent {
  const AchievementEvent({
    required this.title,
    this.subtitle,
    required this.iconAsset,
    required this.soundAsset,
  });

  final String title;
  final String? subtitle;
  final String iconAsset;
  final String soundAsset;
}

/// FIFO queue of [AchievementEvent]s waiting to be shown as a toast. One
/// event displays at a time; [dismissCurrent] advances to the next once its
/// toast finishes.
class AchievementQueueNotifier extends StateNotifier<Queue<AchievementEvent>> {
  AchievementQueueNotifier() : super(Queue());

  void enqueue(AchievementEvent event) {
    state = Queue.of(state)..add(event);
  }

  /// Removes the front event once its toast finishes displaying, exposing
  /// the next one (if any). A no-op if the queue is already empty.
  void dismissCurrent() {
    if (state.isEmpty) return;
    state = Queue.of(state)..removeFirst();
  }
}

final achievementQueueProvider =
    StateNotifierProvider<AchievementQueueNotifier, Queue<AchievementEvent>>(
  (ref) => AchievementQueueNotifier(),
);
