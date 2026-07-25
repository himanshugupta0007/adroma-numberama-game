import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'dialog_card.dart';

/// Shows a single-message dialog with an "OK" dismiss button - the app-wide
/// replacement for [SnackBar]s, which don't fit the dark, full-bleed theme
/// and are easy to miss. Used for both plain info ("coming soon" stubs,
/// confirmations) and errors; pass [isError] to tint the message coral.
Future<void> showMessageDialog(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _MessageDialog(message: message, isError: isError),
  );
}

class _MessageDialog extends StatelessWidget {
  const _MessageDialog({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              14,
              weight: FontWeight.w500,
              color: isError ? AppColors.coral : AppColors.textHi,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
