import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio_service.dart';
import '../state/achievement_queue.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/gradient_button.dart';

/// Confetti-backed celebration for whatever's at the front of
/// [achievementQueueProvider] - a level-up today, a badge unlock later (see
/// that file's class docs for why the queue itself stays generic). Renders
/// a confetti burst plus a modal [_LevelUpDialog] the player must
/// acknowledge with its single "OK" button, rather than a passive toast
/// that fades on its own - a deliberate, premium-feeling beat instead of
/// something easy to miss.
///
/// Mounted on `ResultsScreen`, not mid-round: a level-up event sits in the
/// queue (already enqueued the moment it happens, in
/// `GameStateNotifier.registerPairCleared`) until the round actually ends,
/// so the celebration shows once play is over instead of interrupting
/// active gameplay.
class AchievementToast extends ConsumerStatefulWidget {
  const AchievementToast({super.key});

  @override
  ConsumerState<AchievementToast> createState() => _AchievementToastState();
}

class _AchievementToastState extends ConsumerState<AchievementToast> {
  static const _burstDuration = Duration(milliseconds: 1000);

  // Three cannons - top-center explosive, plus one from each side angled
  // inward - so confetti frames the dialog from around it rather than
  // falling from a single point that may not line up with where the
  // dialog actually lands on screen.
  final _confettiTop = ConfettiController(duration: _burstDuration);
  final _confettiLeft = ConfettiController(duration: _burstDuration);
  final _confettiRight = ConfettiController(duration: _burstDuration);

  /// The event a dialog is currently showing (or was just told to show) for
  /// - guards against [build] re-running for an unrelated reason (e.g. a
  /// parent rebuild) and calling [_celebrate] a second time for the same
  /// still-queued event.
  AchievementEvent? _shown;

  /// Whether the confetti cannons should be in the widget tree at all -
  /// mounted only for [_burstDuration], then removed entirely.
  ///
  /// package:confetti has a bug: `_animationStatusListener` calls
  /// `_continueAnimation()` (which restarts its internal AnimationController
  /// via `forward(from: 0)`) unconditionally on every completion, regardless
  /// of `shouldLoop` - so a "non-looping" burst's ticker actually never
  /// stops on its own once played, ticking forever for as long as the
  /// widget stays mounted. Unmounting `ConfettiWidget` (not just letting the
  /// burst "finish") is what actually disposes that AnimationController -
  /// see `_ConfettiWidgetState.dispose()`.
  bool _confettiActive = false;

  @override
  void dispose() {
    _confettiTop.dispose();
    _confettiLeft.dispose();
    _confettiRight.dispose();
    super.dispose();
  }

  void _celebrate(AchievementEvent event) {
    setState(() => _confettiActive = true);
    _confettiTop.play();
    _confettiLeft.play();
    _confettiRight.play();
    Future.delayed(_burstDuration, () {
      if (mounted) setState(() => _confettiActive = false);
    });
    AudioService.instance.playOneOff(event.soundAsset);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Transparent, not the usual dark scrim - this is a celebration, and
      // a dimmed backdrop would hide the confetti bursting behind it.
      barrierColor: Colors.transparent,
      builder: (dialogContext) => _LevelUpDialog(
        event: event,
        onOk: () {
          Navigator.pop(dialogContext);
          _shown = null;
          ref.read(achievementQueueProvider.notifier).dismissCurrent();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch (not listen): the event is enqueued mid-round, well before
    // ResultsScreen (and this widget) ever mounts - `listen` only fires on
    // *changes after registration*, so it would silently miss an event
    // that was already sitting at the front of the queue by the time this
    // widget's first build runs. Watching and comparing against `_shown` on
    // every build catches both that already-there case and any later
    // change the same way.
    final front = ref.watch(
      achievementQueueProvider.select((queue) => queue.isEmpty ? null : queue.first),
    );
    if (front != null && front != _shown) {
      _shown = front;
      // showDialog can't run synchronously mid-build, so it's deferred to
      // right after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _celebrate(front);
      });
    }

    if (!_confettiActive) return const SizedBox.shrink();

    const colors = [
      AppColors.amber,
      AppColors.amberDeep,
      AppColors.coral,
      Colors.white,
    ];

    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiTop,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 24,
              maxBlastForce: 22,
              minBlastForce: 10,
              gravity: 0.25,
              colors: colors,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _confettiLeft,
              blastDirectionality: BlastDirectionality.directional,
              // Up-and-right, toward the center where the dialog sits.
              blastDirection: -math.pi / 4,
              shouldLoop: false,
              numberOfParticles: 16,
              maxBlastForce: 18,
              minBlastForce: 8,
              gravity: 0.2,
              colors: colors,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _confettiRight,
              blastDirectionality: BlastDirectionality.directional,
              // Up-and-left, toward the center where the dialog sits.
              blastDirection: -3 * math.pi / 4,
              shouldLoop: false,
              numberOfParticles: 16,
              maxBlastForce: 18,
              minBlastForce: 8,
              gravity: 0.2,
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }
}

/// The modal celebration itself. Deliberately its own shell rather than the
/// shared `DialogCard` (used by the plainer confirm/pause/rate dialogs) -
/// a flat `AppColors.surface` box reads as barely-there against this app's
/// equally-dark background, which defeats the point of a celebration; the
/// amber border and glow here exist specifically to make it pop instead of
/// blending in.
class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.event, required this.onOk});

  final AchievementEvent event;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceRaised, AppColors.surface],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.amber, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.45),
              blurRadius: 28,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.amber, AppColors.amberDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber.withValues(alpha: 0.5),
                    blurRadius: 20,
                  ),
                ],
              ),
              alignment: Alignment.center,
              // TODO(progression): iconAsset is a placeholder path with no
              // real asset behind it yet - falls back to a plain trophy
              // icon until badges' real artwork lands.
              child: Image.asset(
                event.iconAsset,
                width: 44,
                height: 44,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.onAmber,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'CONGRATULATIONS!',
              textAlign: TextAlign.center,
              style: AppTextStyles.mono(13,
                  weight: FontWeight.w700, color: AppColors.amber),
            ),
            const SizedBox(height: 6),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(26, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              event.subtitle ?? "You're on a roll - keep it up!",
              textAlign: TextAlign.center,
              style: AppTextStyles.display(13,
                  weight: FontWeight.w400, color: AppColors.textMid),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GradientButton(label: 'OK', onPressed: onOk),
            ),
          ],
        ),
      ),
    );
  }
}
