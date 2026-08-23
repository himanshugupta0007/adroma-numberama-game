import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ad_service.dart';
import '../services/notification_service.dart';
import '../services/rate_service.dart';
import '../state/difficulty.dart';
import '../state/preferences_service.dart';
import '../state/settings_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dialog_card.dart';
import '../widgets/graph_paper_background.dart';
import '../widgets/message_dialog.dart';
import '../widgets/settings_row.dart';
import 'home/bottom_nav_bar.dart';

/// The full Settings screen, reached from the home screen's bottom nav.
/// Every toggle here mirrors straight to [PreferencesService] via
/// [settingsStateProvider] - see that file for why the Streak Reminder
/// toggle is the one exception driven from this screen instead.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const _supportEmail = 'adromagames@gmail.com';

  static const _privacyPolicyUrl =
      'https://www.adromagames.com/privacy-policy/';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSharingApp = false;

  /// Null until [PackageInfo.fromPlatform] resolves - the footer just shows
  /// nothing for that one frame rather than a hardcoded placeholder version.
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = 'v${info.version}');
  }

  Future<void> _shareApp() async {
    if (_isSharingApp) return;
    setState(() => _isSharingApp = true);
    try {
      const text = 'I love playing Numberama, a number-matching puzzle '
          "game - you should give it a try!";
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (mounted) {
        await showMessageDialog(context, 'Could not share Numberama.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSharingApp = false);
    }
  }

  Future<void> _handleReminderToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final settingsNotifier = ref.read(settingsStateProvider.notifier);
    final notifications = ref.read(notificationServiceProvider);

    if (value) {
      final granted = await notifications.requestPermission();
      if (!granted) {
        if (!context.mounted) return;
        await showMessageDialog(
          context,
          "Notifications are off for Numberama at the system level - "
          'enable them in system settings to get streak reminders.',
          isError: true,
        );
        // Leave the toggle off - state was never flipped to true.
        return;
      }
      final prefs = ref.read(preferencesServiceProvider);
      final now = DateTime.now();
      final remaining = prefs.timeUntilNextDailyCycle(now);
      await notifications.scheduleDailyReadyReminder(
        now.add(remaining > Duration.zero ? remaining : dailyCycleDuration),
      );
      settingsNotifier.setDailyReminderEnabled(true);
    } else {
      await notifications.cancelStreakReminder();
      settingsNotifier.setDailyReminderEnabled(false);
    }
  }

  Future<void> _confirmResetProgress(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ResetProgressDialog(),
    );
    if (confirmed != true) return;

    await ref.read(preferencesServiceProvider).clearAll();
    await ref.read(notificationServiceProvider).cancelStreakReminder();
    ref.read(settingsStateProvider.notifier).resetToDefaults();

    if (!context.mounted) return;
    await showMessageDialog(context, 'Progress reset.');
  }

  void _showComingSoon(BuildContext context, String label) {
    showMessageDialog(context, '$label — coming soon');
  }

  /// Manual counterpart to the home screen's automatic prompt (see
  /// [PreferencesService.shouldShowRatePrompt]) - requests the same native
  /// review flow on demand, and marks it rated so the automatic prompt
  /// doesn't also nag afterwards.
  Future<void> _rateApp(WidgetRef ref) async {
    await RateService.instance.requestReview();
    await ref.read(preferencesServiceProvider).setHasRated();
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: SettingsScreen._supportEmail,
      queryParameters: {'subject': 'Numberama feedback'},
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      await showMessageDialog(context, "Couldn't open a mail app.",
          isError: true);
    }
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final launched = await launchUrl(
      Uri.parse(SettingsScreen._privacyPolicyUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      await showMessageDialog(context, "Couldn't open the link.",
          isError: true);
    }
  }

  Widget _switch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.amber,
    );
  }

  Widget _chevron() =>
      const Icon(Icons.chevron_right_rounded, color: AppColors.textLow);

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsStateProvider);
    final settingsNotifier = ref.read(settingsStateProvider.notifier);

    return Scaffold(
      body: GraphPaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.chevron_left_rounded,
                          color: AppColors.textHi),
                    ),
                    Text('Settings', style: AppTextStyles.heading),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SettingsSectionHeader('Sound & Feedback'),
                      SettingsSectionCard(
                        rows: [
                          SettingsRow(
                            label: 'Sound Effects',
                            trailing: _switch(
                              settings.soundEnabled,
                              settingsNotifier.setSoundEnabled,
                            ),
                          ),
                          SettingsRow(
                            label: 'Haptic Feedback',
                            trailing: _switch(
                              settings.hapticsEnabled,
                              settingsNotifier.setHapticsEnabled,
                            ),
                          ),
                          SettingsRow(
                            label: 'Reduce Motion',
                            subtitle: 'Simplifies animations',
                            trailing: _switch(
                              settings.reduceMotionEnabled,
                              settingsNotifier.setReduceMotionEnabled,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionHeader('Notifications'),
                      SettingsSectionCard(
                        rows: [
                          SettingsRow(
                            label: 'Streak Reminder',
                            subtitle: 'Get notified before your streak resets',
                            trailing: _switch(
                              settings.dailyReminderEnabled,
                              (value) =>
                                  _handleReminderToggle(context, ref, value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionHeader('Purchases & Ads'),
                      SettingsSectionCard(
                        rows: [
                          // TODO(iap): open remove-ads purchase flow.
                          const SettingsRow(
                            label: 'Remove Ads',
                            enabled: false,
                            trailing: _ComingSoonTag(),
                          ),
                          SettingsRow(
                            label: 'Restore Purchases',
                            trailing: _chevron(),
                            // TODO(iap): call in_app_purchase
                            // restorePurchases().
                            onTap: () =>
                                _showComingSoon(context, 'Restore Purchases'),
                          ),
                          SettingsRow(
                            label: 'Manage Ad Preferences',
                            trailing: _chevron(),
                            // A no-op for players outside the EEA/UK, whose
                            // region never required a consent form in the
                            // first place - see AdService.
                            // showPrivacyOptionsForm. Left visible
                            // unconditionally rather than only for players
                            // it applies to, since a GDPR consent form
                            // itself only reaches EEA/UK players.
                            onTap: () =>
                                AdService.instance.showPrivacyOptionsForm(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionHeader('Data'),
                      SettingsSectionCard(
                        rows: [
                          SettingsRow(
                            label: 'Reset Progress',
                            labelColor: AppColors.coral,
                            trailing: Icon(Icons.chevron_right_rounded,
                                color: AppColors.coral.withValues(alpha: 0.7)),
                            onTap: () => _confirmResetProgress(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionHeader('Share'),
                      const SizedBox(height: 12),
                      SettingsSectionCard(
                        rows: [
                          SettingsRow(
                            label: 'Share Numberama',
                            subtitle: 'Invite friends to play',
                            trailing: _isSharingApp
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : _chevron(),
                            onTap: _isSharingApp ? null : _shareApp,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const SettingsSectionHeader('About'),
                      SettingsSectionCard(
                        rows: [
                          SettingsRow(
                            label: 'Rate Numberama',
                            trailing: _chevron(),
                            onTap: () => _rateApp(ref),
                          ),
                          SettingsRow(
                            label: 'Send Feedback',
                            trailing: _chevron(),
                            onTap: () => _sendFeedback(context),
                          ),
                          // TODO(cross-promo): "More Games" row hidden until
                          // there's a games-list screen (and other games) to
                          // point it at - see doc/remaining-work.md.
                          SettingsRow(
                            label: 'Privacy Policy',
                            trailing: _chevron(),
                            onTap: () => _openPrivacyPolicy(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Center(
                        child: Text(
                          _appVersion == null
                              ? 'Adhroma Games'
                              : 'Adhroma Games · $_appVersion',
                          style: AppTextStyles.mono(
                            10.5,
                            weight: FontWeight.w500,
                            color: AppColors.textLow,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: BottomNavBar(activeTab: HomeTab.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Coming soon',
        style: AppTextStyles.mono(9,
            weight: FontWeight.w600, color: AppColors.textLow),
      ),
    );
  }
}

/// Dark-themed confirm/cancel dialog for the destructive "Reset Progress"
/// action - [DialogCard] rather than a default [AlertDialog] so it actually
/// picks up [AppColors] instead of Material's light dialog chrome.
class _ResetProgressDialog extends StatelessWidget {
  const _ResetProgressDialog();

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset all progress?',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            "This clears your streak, scores, and saved settings. This "
            "can't be undone.",
            textAlign: TextAlign.center,
            style: AppTextStyles.display(
              13,
              weight: FontWeight.w400,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: AppColors.textHi,
                    side: BorderSide.none,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
