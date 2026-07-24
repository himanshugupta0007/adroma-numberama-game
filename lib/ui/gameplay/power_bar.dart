import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/selection_manager.dart';
import '../../state/game_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The power-up strip: shuffle and hint each get one free use per round,
/// ad-gated after (see [_handleShuffleTap]/[_handleHintTap]). Both slots
/// also pulse a "try me" nudge every 3 consecutive invalid taps, in case
/// the player's stuck and hasn't noticed them.
class PowerBar extends ConsumerStatefulWidget {
  const PowerBar({super.key, required this.selectionManager});

  final SelectionManager selectionManager;

  @override
  ConsumerState<PowerBar> createState() => _PowerBarState();
}

class _PowerBarState extends ConsumerState<PowerBar> {
  /// Bumped once per 3-miss threshold crossed - the value itself is
  /// meaningless to [_PowerSlot], only that it changed matters, so it can
  /// stay a plain rebuild counter rather than anything richer.
  int _nudgeTick = 0;

  @override
  Widget build(BuildContext context) {
    final selectionManager = widget.selectionManager;
    final shuffleAvailable =
        ref.watch(gameStateProvider.select((s) => s.shuffleAvailable));
    final hintAvailable =
        ref.watch(gameStateProvider.select((s) => s.hintAvailable));

    // Edge-triggered on crossing a multiple of 3 (not just "> 0") so the
    // nudge replays every few misses rather than firing once and going
    // quiet, but still only once per crossing rather than every rebuild.
    ref.listen<int>(
      gameStateProvider.select((s) => s.consecutiveMisses),
      (previous, next) {
        if (next == 0 || next % 3 != 0) return;
        setState(() => _nudgeTick++);
      },
    );

    void handleShuffleTap() {
      if (shuffleAvailable) {
        selectionManager.shuffle();
        ref.read(gameStateProvider.notifier).useShuffle();
        return;
      }
      // No ad SDK wired up yet - honest placeholder, same pattern as the
      // results screen's "Share result" button.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watch an ad for a shuffle — coming soon')),
      );
    }

    void handleHintTap() {
      if (hintAvailable) {
        selectionManager.hint();
        ref.read(gameStateProvider.notifier).useHint();
        return;
      }
      // Same honest placeholder as shuffle above - no ad SDK wired up yet.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Watch an ad for a hint — coming soon')),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PowerSlot(
            icon: Icons.shuffle_rounded,
            count: shuffleAvailable ? 1 : null,
            adGated: !shuffleAvailable,
            onTap: handleShuffleTap,
            nudge: _nudgeTick,
          ),
          const SizedBox(width: 16),
          _PowerSlot(
            icon: Icons.lightbulb_outline_rounded,
            count: hintAvailable ? 1 : null,
            adGated: !hintAvailable,
            onTap: handleHintTap,
            nudge: _nudgeTick,
          ),
        ],
      ),
    );
  }
}

class _PowerSlot extends StatefulWidget {
  const _PowerSlot({
    required this.icon,
    this.count,
    this.adGated = false,
    this.onTap,
    this.nudge = 0,
  });

  final IconData icon;
  final int? count;
  final bool adGated;

  /// Null keeps a slot purely decorative - only slots with a real handler
  /// are tappable.
  final VoidCallback? onTap;

  /// Bumped by [PowerBar] to replay the "try me" zoom pulse below. Only
  /// *changes* to this value matter (see [_PowerSlotState.didUpdateWidget])
  /// - the number itself carries no meaning.
  final int nudge;

  @override
  State<_PowerSlot> createState() => _PowerSlotState();
}

class _PowerSlotState extends State<_PowerSlot>
    with SingleTickerProviderStateMixin {
  /// One full nudge plays 3 pulses back to back over this long, so it stays
  /// noticeable rather than flashing past in under a second.
  static const _pulseDuration = Duration(milliseconds: 3000);
  static const _pulseCount = 3;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: _pulseDuration,
  );

  // Each of the [_pulseCount] pulses zooms up fast, then eases back past
  // 1.0 and settles - reads as a deliberate "look here" pop repeated a few
  // times, rather than one flash or a smooth continuous breathing loop.
  late final Animation<double> _scale = TweenSequence<double>([
    for (var i = 0; i < _pulseCount; i++) ...[
      TweenSequenceItem(
        weight: 35,
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
      ),
      TweenSequenceItem(
        weight: 65,
        tween: Tween(begin: 1.35, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
      ),
    ],
  ]).animate(_pulseController);

  @override
  void didUpdateWidget(covariant _PowerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nudge != oldWidget.nudge) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inert = widget.count == null && !widget.adGated;
    return ScaleTransition(
      scale: _scale,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: inert
                        ? AppColors.textLow.withValues(alpha: 0.55)
                        : AppColors.textHi,
                  ),
                ),
              ),
            ),
            if (widget.count != null)
              Positioned(
                bottom: -6,
                right: -6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.bgNavy,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.surfaceRaised),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: AppTextStyles.mono(9, color: AppColors.textMid),
                  ),
                ),
              ),
            if (widget.adGated)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.play_arrow_rounded,
                      size: 10, color: AppColors.bgDeep),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
