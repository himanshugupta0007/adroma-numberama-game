import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../daily/daily_screen.dart';
import '../settings_screen.dart';

/// The three real destinations [BottomNavBar] switches between. `results`
/// isn't one of them - the results screen shows the bar too (per
/// [BottomNavBar]'s doc) but isn't itself a tab, so every item there reads
/// as inactive until tapped.
enum HomeTab { play, daily, settings, results }

/// The Play/Daily/Settings tab strip shown on every screen except
/// [GameplayScreen] itself (a round in progress has no business showing
/// navigation away from it) - Home, Daily Challenge, Settings, and the
/// post-round Results screen all include it. [activeTab] marks which one
/// is currently on screen; tapping a different tab always normalizes the
/// stack back down to [HomeScreen] first (via `popUntil` the first route)
/// before pushing the new destination, so switching tabs can never stack
/// up Daily-on-top-of-Settings-on-top-of-Daily.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, this.activeTab = HomeTab.play});

  final HomeTab activeTab;

  void _switchTo(BuildContext context, HomeTab tab) {
    if (tab == activeTab) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    switch (tab) {
      case HomeTab.play:
        break; // popUntil above already landed on Home.
      case HomeTab.daily:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DailyScreen()),
        );
      case HomeTab.settings:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      case HomeTab.results:
        break; // Not a real navigation target - see HomeTab.results above.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.bgNavy,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgNavy.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavItem(
              icon: Icons.play_circle_fill_rounded,
              label: 'Play',
              active: activeTab == HomeTab.play,
              onTap: () => _switchTo(context, HomeTab.play),
            ),
            _NavItem(
              icon: Icons.calendar_today_rounded,
              label: 'Daily',
              active: activeTab == HomeTab.daily,
              onTap: () => _switchTo(context, HomeTab.daily),
            ),
            _NavItem(
              icon: Icons.tune_rounded,
              label: 'Settings',
              active: activeTab == HomeTab.settings,
              onTap: () => _switchTo(context, HomeTab.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.amber : AppColors.textLow;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.mono(9, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
