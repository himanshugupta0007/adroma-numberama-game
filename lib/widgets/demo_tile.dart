import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A plain-Flutter stand-in for [TileComponent]'s look (idle/selected
/// colors, corner radius, digit style), used wherever a tile needs to
/// render outside the Flame game - currently only the onboarding tutorial.
class DemoTile extends StatelessWidget {
  const DemoTile({
    super.key,
    required this.value,
    this.size = 56,
    this.selected = false,
    this.opacity = 1,
  });

  final int value;
  final double size;
  final bool selected;
  final double opacity;

  static const _cornerRadiusFactor = 0.16;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0, 1),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(size * _cornerRadiusFactor),
        ),
        child: Text(
          '$value',
          style: AppTextStyles.mono(
            size * 0.5,
            weight: FontWeight.bold,
            color: selected ? AppColors.bgNavy : AppColors.textMid,
          ),
        ),
      ),
    );
  }
}
