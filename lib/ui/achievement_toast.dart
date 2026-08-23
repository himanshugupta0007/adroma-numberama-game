import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_service.dart';
import '../state/achievement_queue.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Floating, non-blocking toast for whatever's at the front of
/// [achievementQueueProvider] - a level-up today, a badge unlock later (see
/// that file's class docs for why the queue itself stays generic).
///
/// Deliberately does not pause the game: this overlays active gameplay
/// rather than interrupting it, so it must never intercept taps meant for
/// the board underneath.
class AchievementToast extends ConsumerStatefulWidget {
  const AchievementToast({super.key});

  @override
  ConsumerState<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends ConsumerState<AchievementToast> {
  static const _visibleDuration = Duration(milliseconds: 1300);
  static const _fadeDuration = Duration(milliseconds: 250);

  AchievementEvent? _current;
  bool _visible = false;

  void _show(AchievementEvent event) {
    setState(() {
      _current = event;
      _visible = true;
    });
    AudioService.instance.playOneOff(event.soundAsset);

    Future.delayed(_visibleDuration, () {
      if (!mounted || _current != event) return;
      setState(() => _visible = false);

      Future.delayed(_fadeDuration, () {
        if (!mounted) return;
        // Only this widget's own fade-out schedules a dismiss, so a queue
        // that's moved on already (shouldn't happen - nothing else drains
        // it) can't be dismissed a second time.
        ref.read(achievementQueueProvider.notifier).dismissCurrent();
        setState(() => _current = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen (not watch): this only needs to react when a new event
    // reaches the front of the queue, not rebuild this widget on every
    // queue change - _show's own setState calls already drive rebuilds.
    ref.listen(
      achievementQueueProvider.select((queue) => queue.isEmpty ? null : queue.first),
      (previous, next) {
        if (next != null && next != _current) _show(next);
      },
    );

    if (_current == null) return const SizedBox.shrink();

    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: _fadeDuration,
          child: AnimatedScale(
            scale: _visible ? 1 : 0.85,
            duration: _fadeDuration,
            child: _ToastCard(event: _current!),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.event});

  final AchievementEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TODO(progression): iconAsset is a placeholder path with no real
          // asset behind it yet - falls back to a plain icon until badges'
          // real artwork lands.
          Image.asset(
            event.iconAsset,
            width: 28,
            height: 28,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.amber,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title,
                  style: AppTextStyles.display(15, weight: FontWeight.w700)),
              if (event.subtitle != null)
                Text(event.subtitle!, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}
