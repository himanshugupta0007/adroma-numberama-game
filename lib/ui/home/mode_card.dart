import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A Classic/Rush mode picker card on [HomeScreen]: an icon badge, title,
/// short description, and a CTA button supplied by the caller (a
/// [GradientButton] for the primary mode, a themed ghost [ElevatedButton]
/// for the secondary one).
class ModeCard extends StatelessWidget {
  const ModeCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.action,
    this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final Widget action;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.display(16)),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.display(
              12.5,
              weight: FontWeight.w400,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: action),
        ],
      ),
    );
  }
}
