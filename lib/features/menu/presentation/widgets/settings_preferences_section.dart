import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/appointment_notification_service.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../settings/presentation/settings_notifier.dart';
import 'settings_section_header.dart';
import 'settings_tile.dart';

class SettingsPreferencesSection extends StatefulWidget {
  final bool isBiometricEnabled;

  const SettingsPreferencesSection({
    super.key,
    required this.isBiometricEnabled,
  });

  @override
  State<SettingsPreferencesSection> createState() =>
      _SettingsPreferencesSectionState();
}

class _SettingsPreferencesSectionState
    extends State<SettingsPreferencesSection> {
  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _getTimeoutName(int ms) {
    if (ms == 0) return "Off";
    if (ms == 60000) return "1 Minute";
    if (ms == 300000) return "5 Minutes";
    if (ms == 900000) return "15 Minutes";
    if (ms == 1800000) return "30 Minutes";
    if (ms == 3600000) return "1 Hour";
    return "5 Minutes";
  }

  void _showTimeoutSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Inactivity Lock",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...[0, 60000, 300000, 900000, 1800000, 3600000].map((timeout) {
                return ListTile(
                  title: Text(_getTimeoutName(timeout)),
                  trailing:
                      SettingsNotifier.instance.inactivityTimeoutMs == timeout
                          ? const Icon(
                            Icons.check,
                            color: AppColors.primaryGreen,
                          )
                          : null,
                  onTap: () {
                    SettingsNotifier.instance.updateInactivityTimeout(timeout);
                    Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: "Preferences"),
        AnimatedBuilder(
          animation: SettingsNotifier.instance,
          builder: (context, child) {
            return SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              title: const Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              subtitle: const Text(
                "Receive appointment reminders",
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              value: SettingsNotifier.instance.notificationsEnabled,
              activeColor: AppColors.primaryGreen,
              onChanged: (val) async {
                await SettingsNotifier.instance.updateNotificationsEnabled(val);
                if (!val) {
                  await AppointmentNotificationService.instance
                      .cancelAllReminders();
                }
              },
            );
          },
        ),
        if (widget.isBiometricEnabled)
          AnimatedBuilder(
            animation: SettingsNotifier.instance,
            builder: (context, child) {
              return SettingsTile(
                icon: Icons.timer_outlined,
                title: "Inactivity Lock",
                value: _getTimeoutName(
                  SettingsNotifier.instance.inactivityTimeoutMs,
                ),
                onTap: () => _showTimeoutSelectionDialog(),
              );
            },
          ),
        SettingsTile(
          icon: Icons.attach_money,
          title: "Currency",
          value: ProfileNotifier.instance.currencySymbol,
          subtitle: "Set automatically by location",
          onTap:
              () => CustomSnackbar.showInfo(
                context,
                "Currency is automatically configured based on your profile location.",
              ),
        ),
        SettingsTile(
          icon: Icons.dark_mode_outlined,
          title: "Appearance",
          value: _getThemeName(SettingsNotifier.instance.themeMode),
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Appearance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.brightness_auto),
                        title: const Text("System Default"),
                        trailing:
                            SettingsNotifier.instance.themeMode ==
                                    ThemeMode.system
                                ? const Icon(
                                  Icons.check,
                                  color: AppColors.primaryGreen,
                                )
                                : null,
                        onTap: () {
                          SettingsNotifier.instance.updateThemeMode(
                            ThemeMode.system,
                          );
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.light_mode),
                        title: const Text("Light"),
                        trailing:
                            SettingsNotifier.instance.themeMode ==
                                    ThemeMode.light
                                ? const Icon(
                                  Icons.check,
                                  color: AppColors.primaryGreen,
                                )
                                : null,
                        onTap: () {
                          SettingsNotifier.instance.updateThemeMode(
                            ThemeMode.light,
                          );
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dark_mode),
                        title: const Text("Dark"),
                        trailing:
                            SettingsNotifier.instance.themeMode ==
                                    ThemeMode.dark
                                ? const Icon(
                                  Icons.check,
                                  color: AppColors.primaryGreen,
                                )
                                : null,
                        onTap: () {
                          SettingsNotifier.instance.updateThemeMode(
                            ThemeMode.dark,
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
            if (mounted) setState(() {});
          },
        ),
        AnimatedBuilder(
          animation: SettingsNotifier.instance,
          builder: (context, child) {
            return SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.animation,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              title: const Text(
                "Menu Drawer Hint",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              subtitle: const Text(
                "Show animation on startup",
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              value: SettingsNotifier.instance.showDrawerHint,
              activeColor: AppColors.primaryGreen,
              onChanged: (val) {
                SettingsNotifier.instance.updateShowDrawerHint(val);
              },
            );
          },
        ),
      ],
    );
  }
}
