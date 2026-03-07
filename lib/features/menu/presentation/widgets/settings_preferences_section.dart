import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Inactivity Lock",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...[0, 60000, 300000, 900000, 1800000, 3600000].map((timeout) {
                return ListTile(
                  title: Text(_getTimeoutName(timeout)),
                  trailing:
                      SettingsNotifier.instance.inactivityTimeoutMs == timeout
                          ? Icon(Icons.check, color: AppColors.primaryGreen)
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
        SettingsSectionHeader(title: "Preferences"),
        AnimatedBuilder(
          animation: SettingsNotifier.instance,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none, color: AppColors.primaryGreen, size: 20),
                ),
                title: Text(
                  "Notifications",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.colorTextDark),
                ),
                subtitle: Text(
                  "Receive appointment reminders",
                  style: TextStyle(fontSize: 12, color: context.colorTextLight),
                ),
                trailing: Switch(
                  value: SettingsNotifier.instance.notificationsEnabled,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (val) async {
                    await SettingsNotifier.instance.updateNotificationsEnabled(val);
                    if (!val) {
                      await AppointmentNotificationService.instance.cancelAllReminders();
                    }
                  },
                ),
              ),
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
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (context) {
                return Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Appearance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      ListTile(
                        leading: Icon(Icons.brightness_auto),
                        title: Text("System Default"),
                        trailing:
                            SettingsNotifier.instance.themeMode ==
                                    ThemeMode.system
                                ? Icon(
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
                        leading: Icon(Icons.light_mode),
                        title: Text("Light"),
                        trailing:
                            SettingsNotifier.instance.themeMode ==
                                    ThemeMode.light
                                ? Icon(
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
                        leading: Icon(Icons.dark_mode),
                        title: Text("Dark"),
                        trailing:
                            SettingsNotifier.instance.themeMode ==
                                    ThemeMode.dark
                                ? Icon(
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
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.animation, color: AppColors.primaryGreen, size: 20),
                ),
                title: Text(
                  "Menu Drawer Hint",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: context.colorTextDark),
                ),
                subtitle: Text(
                  "Show animation on startup",
                  style: TextStyle(fontSize: 12, color: context.colorTextLight),
                ),
                trailing: Switch(
                  value: SettingsNotifier.instance.showDrawerHint,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (val) {
                    SettingsNotifier.instance.updateShowDrawerHint(val);
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
