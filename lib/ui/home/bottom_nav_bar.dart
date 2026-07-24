import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../settings_screen.dart';

/// The Play/Ranks/Settings tab strip on [HomeScreen]. Play and Settings
/// have real destinations (Daily Challenge is reached via its own card
/// above, not this bar) - Ranks renders as an inert affordance (no screen
/// designed for it yet) and surfaces a "coming soon" snack bar instead of
/// doing nothing silently on tap.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

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
              active: true,
              onTap: () {},
            ),
            _NavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Ranks',
              active: false,
              onTap: () => _showComingSoon(context, 'Ranks'),
            ),
            _NavItem(
              icon: Icons.tune_rounded,
              label: 'Settings',
              active: false,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon')),
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
