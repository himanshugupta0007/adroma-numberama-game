import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Primary CTA button ("Play Classic", "Play Again", "Start Today's Board",
/// ...). Renders the amber→amberDeep gradient that [ButtonStyle] can't
/// express, so it's a plain widget rather than a themed [ElevatedButton].
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  static const _borderRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(_borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.amber, AppColors.amberDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(_borderRadius),
            boxShadow: [
              BoxShadow(
                color: AppColors.amber.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTextStyles.display(
              14,
              weight: FontWeight.w600,
              color: AppColors.onAmber,
            ),
          ),
        ),
      ),
    );
  }
}
