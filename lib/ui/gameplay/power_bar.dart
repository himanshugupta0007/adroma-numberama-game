import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/selection_manager.dart';
import '../../services/ad_service.dart';
import '../../state/game_state.dart';
import '../../state/preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/message_dialog.dart';

/// The power-up strip: shuffle, hint, and clear-row. Shuffle and hint each
/// get one free use per round, ad-gated after; clear-row follows the same
/// rule in Classic but is ad-gated from the very first frame in the Daily
/// Challenge, with no free use at all (see [GameState.clearRowAvailable]).
/// All three slots also pulse a "try me" nudge every 3 consecutive invalid
/// taps, in case the player's stuck and hasn't noticed them.
class PowerBar extends ConsumerStatefulWidget {
  const PowerBar({
    super.key,
    required this.selectionManager,
    required this.onAdWillShow,
    required this.onAdClosed,
  });

  final SelectionManager selectionManager;

  /// Called right before a rewarded ad is requested to show, so the caller
  /// (the gameplay screen) can pause the Flame engine behind it - otherwise
  /// the board keeps ticking (the auto-row timer included) while the ad
  /// covers the screen, invisible to the player until it closes.
  final VoidCallback onAdWillShow;

  /// Called once the rewarded ad's full-screen content is actually gone -
  /// reward earned or not, closed normally, failed to show, or (since no ad
  /// was ever shown to close) immediately if none was ready - so the
  /// pause from [onAdWillShow] always gets undone exactly once.
  final VoidCallback onAdClosed;

  @override
  ConsumerState<PowerBar> createState() => _PowerBarState();
}

class _PowerBarState extends ConsumerState<PowerBar> {
  /// Bumped once per 3-miss threshold crossed - the value itself is
  /// meaningless to [_PowerSlot], only that it changed matters, so it can
  /// stay a plain rebuild counter rather than anything richer.
  int _nudgeTick = 0;

  /// Bumped each time the matching power-up actually fires (free use or
  /// ad-granted) so [_PowerSlot] can play its "used" burst. Same
  /// change-detection convention as [_nudgeTick] - only transitions matter.
  int _shuffleUsedTick = 0;
  int _hintUsedTick = 0;
  int _clearRowUsedTick = 0;

  @override
  Widget build(BuildContext context) {
    final selectionManager = widget.selectionManager;
    final shuffleAvailable =
        ref.watch(gameStateProvider.select((s) => s.shuffleAvailable));
    final hintAvailable =
        ref.watch(gameStateProvider.select((s) => s.hintAvailable));
    final clearRowAvailable =
        ref.watch(gameStateProvider.select((s) => s.clearRowAvailable));

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

    // Once ad-gated, a slot's power-up is granted by watching a rewarded ad
    // to completion - [AdService.showRewarded]'s [onUserEarnedReward] only
    // fires then, never on an early close/skip, so `grant` below can't run
    // for a bailed-out ad. A "Remove Ads" purchase (once Settings' stub is
    // wired up) skips the ad entirely and just grants the power-up outright
    // - there's no ad left to watch once a player has paid to remove them.
    void watchAdFor(VoidCallback grant) {
      if (ref.read(preferencesServiceProvider).removeAdsPurchased) {
        grant();
        return;
      }
      widget.onAdWillShow();
      final shown = AdService.instance.showRewarded(
        onUserEarnedReward: grant,
        onAdClosed: widget.onAdClosed,
      );
      if (!shown) {
        widget.onAdClosed();
        showMessageDialog(context, 'Ad not ready yet — try again in a moment');
      }
    }

    void handleShuffleTap() {
      if (shuffleAvailable) {
        selectionManager.shuffle();
        ref.read(gameStateProvider.notifier).useShuffle();
        setState(() => _shuffleUsedTick++);
        return;
      }
      watchAdFor(() {
        selectionManager.shuffle();
        setState(() => _shuffleUsedTick++);
      });
    }

    void handleHintTap() {
      if (hintAvailable) {
        selectionManager.hint();
        ref.read(gameStateProvider.notifier).useHint();
        setState(() => _hintUsedTick++);
        return;
      }
      watchAdFor(() {
        selectionManager.hint();
        setState(() => _hintUsedTick++);
      });
    }

    void handleClearRowTap() {
      if (clearRowAvailable) {
        selectionManager.clearRow();
        ref.read(gameStateProvider.notifier).useClearRow();
        setState(() => _clearRowUsedTick++);
        return;
      }
      // In the Daily Challenge this is the only path: clearRowAvailable
      // starts false and never flips true there.
      watchAdFor(() {
        selectionManager.clearRow();
        setState(() => _clearRowUsedTick++);
      });
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
            label: 'Shuffle',
            description: 'Mixes up every number on the board.',
            count: shuffleAvailable ? 1 : null,
            adGated: !shuffleAvailable,
            onTap: handleShuffleTap,
            nudge: _nudgeTick,
            used: _shuffleUsedTick,
          ),
          const SizedBox(width: 20),
          _PowerSlot(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            description: 'Flashes one matching pair on the board.',
            count: hintAvailable ? 1 : null,
            adGated: !hintAvailable,
            onTap: handleHintTap,
            nudge: _nudgeTick,
            used: _hintUsedTick,
          ),
          const SizedBox(width: 20),
          _PowerSlot(
            icon: Icons.delete_sweep_rounded,
            label: 'Clear Row',
            description: 'Instantly clears the bottom row.',
            count: clearRowAvailable ? 1 : null,
            adGated: !clearRowAvailable,
            onTap: handleClearRowTap,
            nudge: _nudgeTick,
            used: _clearRowUsedTick,
          ),
        ],
      ),
    );
  }
}

class _PowerSlot extends StatefulWidget {
  const _PowerSlot({
    required this.icon,
    required this.label,
    required this.description,
    this.count,
    this.adGated = false,
    this.onTap,
    this.nudge = 0,
    this.used = 0,
  });

  final IconData icon;

  /// Short caption drawn under the icon at all times - a player shouldn't
  /// have to discover what a slot does through trial and error.
  final String label;

  /// What this power-up actually does, shown in the long-press tooltip
  /// alongside the current free/ad-gated status (see [_PowerSlotState]).
  final String description;

  final int? count;
  final bool adGated;

  /// Null keeps a slot purely decorative - only slots with a real handler
  /// are tappable.
  final VoidCallback? onTap;

  /// Bumped by [PowerBar] to replay the "try me" zoom pulse below. Only
  /// *changes* to this value matter (see [_PowerSlotState.didUpdateWidget])
  /// - the number itself carries no meaning.
  final int nudge;

  /// Bumped by [PowerBar] each time this power-up actually fires, to play
  /// the "used" burst below. Same change-detection convention as [nudge].
  final int used;

  @override
  State<_PowerSlot> createState() => _PowerSlotState();
}

class _PowerSlotState extends State<_PowerSlot>
    with TickerProviderStateMixin {
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

  /// Plays once whenever the power-up actually fires: the icon dips and
  /// bounces back while a translucent ring expands out from behind it and
  /// fades - a quick "consumed" pop distinct from the slower, repeating
  /// "try me" pulse above.
  static const _usedDuration = Duration(milliseconds: 500);

  late final AnimationController _usedController = AnimationController(
    vsync: this,
    duration: _usedDuration,
  );

  late final Animation<double> _usedIconScale = TweenSequence<double>([
    TweenSequenceItem(
      weight: 30,
      tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeOut)),
    ),
    TweenSequenceItem(
      weight: 70,
      tween: Tween(begin: 0.8, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
    ),
  ]).animate(_usedController);

  late final Animation<double> _burstScale = Tween(begin: 0.5, end: 2.0)
      .animate(CurvedAnimation(parent: _usedController, curve: Curves.easeOut));

  late final Animation<double> _burstOpacity = Tween(begin: 0.55, end: 0.0)
      .animate(CurvedAnimation(parent: _usedController, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant _PowerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.nudge != oldWidget.nudge) {
      _pulseController.forward(from: 0);
    }
    if (widget.used != oldWidget.used) {
      _usedController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _usedController.dispose();
    super.dispose();
  }

  /// Appends the slot's current free/ad-gated status to its description, so
  /// the long-press tooltip answers "what does this do" and "why does it
  /// look like that right now" in one message instead of two.
  String get _tooltipMessage {
    final status = widget.count != null
        ? 'Free to use.'
        : widget.adGated
            ? 'Watch a short ad to use it.'
            : '';
    return status.isEmpty
        ? widget.description
        : '${widget.description} $status';
  }

  /// Slot box size - large enough that the icon reads clearly at a glance
  /// and the tap target is comfortable, not just the icon's own bounds.
  static const _boxSize = 60.0;

  @override
  Widget build(BuildContext context) {
    final inert = widget.count == null && !widget.adGated;
    return Tooltip(
      message: _tooltipMessage,
      triggerMode: TooltipTriggerMode.longPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: ScaleTransition(
              scale: _usedIconScale,
              child: SizedBox(
                width: _boxSize,
                height: _boxSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Expanding ring that fades out - the visual cue that a
                    // power-up was just consumed, distinct from the ongoing
                    // "try me" pulse which loops instead of firing once.
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _usedController,
                        builder: (context, child) => Opacity(
                          opacity: _burstOpacity.value,
                          child: Transform.scale(
                            scale: _burstScale.value,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: widget.onTap,
                        child: Container(
                          width: _boxSize,
                          height: _boxSize,
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.icon,
                            size: 26,
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgNavy,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.surfaceRaised),
                          ),
                          child: Text(
                            '${widget.count}',
                            style: AppTextStyles.mono(10,
                                color: AppColors.textMid),
                          ),
                        ),
                      ),
                    if (widget.adGated)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.play_arrow_rounded,
                              size: 13, color: AppColors.bgDeep),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(widget.label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
