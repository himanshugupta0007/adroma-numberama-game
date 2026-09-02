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
    this.category,
  });

  final String title;
  final String? subtitle;
  final String iconAsset;
  final String soundAsset;

  /// Optional coalescing key. Enqueuing an event whose [category] matches
  /// one still waiting in the queue (not yet shown) drops the older one
  /// first, so a burst of same-category events - e.g. climbing several
  /// levels in one round - collapses into a single toast for the latest.
  final String? category;
}

/// FIFO queue of [AchievementEvent]s waiting to be shown as a toast. One
/// event displays at a time; [dismissCurrent] advances to the next once its
/// toast finishes.
class AchievementQueueNotifier extends StateNotifier<Queue<AchievementEvent>> {
  AchievementQueueNotifier() : super(Queue());

  void enqueue(AchievementEvent event) {
    final queue = Queue.of(state);
    if (event.category != null) {
      queue.removeWhere((queued) => queued.category == event.category);
    }
    state = queue..add(event);
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
