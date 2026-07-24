import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// One row inside a [SettingsSectionCard] - a label, an optional muted
/// subtitle underneath it, and a trailing widget (a [Switch], a chevron
/// icon, a "coming soon" tag, ...). Every row on the Settings screen is
/// built from this rather than hand-rolled per row, since the screen has
/// ~15 of them and they only ever vary in these four things.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.labelColor,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides the label's color - used for the destructive "Reset
  /// Progress" row ([AppColors.coral]). Ignored when [enabled] is false.
  final Color? labelColor;

  /// False renders the row greyed-out and non-interactive - used for stubs
  /// that aren't wired up yet (e.g. "Remove Ads" before IAP exists).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final resolvedLabelColor =
        !enabled ? AppColors.textLow : (labelColor ?? AppColors.textHi);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTextStyles.display(
                    14.5,
                    weight: FontWeight.w500,
                    color: resolvedLabelColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppTextStyles.display(
                      11.5,
                      weight: FontWeight.w400,
                      color: AppColors.textLow,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null || !enabled) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// Hairline separator between rows inside a [SettingsSectionCard] - a flat
/// rgba(255,255,255,0.06) line, not the default Material [Divider].
class SettingsRowDivider extends StatelessWidget {
  const SettingsRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: ColoredBox(color: Color(0x0FFFFFFF)),
    );
  }
}

/// Rounded [AppColors.surface] card grouping a section's [SettingsRow]s,
/// with a [SettingsRowDivider] automatically inserted between each pair.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SettingsRowDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Uppercase muted caption sitting above a [SettingsSectionCard].
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label.toUpperCase(), style: AppTextStyles.caption),
    );
  }
}
