import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/services/appointment_notification_service.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
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

  String _getReminderTimeName(int mins) {
    switch (mins) {
      case 15:
        return "15 Mins Before";
      case 30:
        return "30 Mins Before";
      case 60:
        return "1 Hour Before";
      case 120:
        return "2 Hours Before";
      case 1440:
        return "1 Day Before";
      default:
        return "$mins Mins Before";
    }
  }

  // --- PRO FIX: Premium Adaptive Glass Floating Dialog ---
  void _showNotificationSettingsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6), // Rich backdrop
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: AnimatedBuilder(
            animation: SettingsNotifier.instance,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final isGlobalEnabled =
                  SettingsNotifier.instance.notificationsEnabled;

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color:
                        isDark
                            ? AppColors.darkBorder
                            : Colors.grey.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.15),
                      blurRadius: 50,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isGlobalEnabled
                                  ? AppColors.primaryGreen.withValues(
                                    alpha: 0.1,
                                  )
                                  : Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isGlobalEnabled
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_off_rounded,
                          color:
                              isGlobalEnabled
                                  ? AppColors.primaryGreen
                                  : Colors.grey,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Notifications",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isGlobalEnabled
                            ? "DaktarPai alerts are active."
                            : "All alerts are currently muted.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Content Container
                      Container(
                        decoration: AppStyles.surfaceCard(
                          context,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // PRO FIX: Move clipping to a child ClipRRect. This protects the outer border from getting "shaved" or cut off.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              // 1. Master Toggle
                              SwitchListTile(
                                value: isGlobalEnabled,
                                onChanged: (val) async {
                                  await SettingsNotifier.instance
                                      .updateNotificationsEnabled(val);
                                  if (!val) {
                                    await AppointmentNotificationService
                                        .instance
                                        .cancelAllReminders();
                                  }
                                },
                                activeColor: AppColors.primaryGreen,
                                // PRO FIX: Explicit padding ensures perfect alignment with the sub-toggles below
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                title: Text(
                                  "Allow Notifications",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.colorTextDark,
                                  ),
                                ),
                              ),

                              // 2. Sub-Toggles (Animated Expansion)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child:
                                    isGlobalEnabled
                                        ? Container(
                                          color:
                                              isDark
                                                  ? Colors.black.withValues(
                                                    alpha: 0.2,
                                                  )
                                                  : Colors.grey[50],
                                          child: Column(
                                            children: [
                                              Divider(
                                                height: 1,
                                                color: context.colorBorder
                                                    .withValues(alpha: 0.5),
                                              ),
                                              _buildDialogToggle(
                                                context: context,
                                                title: "Booking Confirmations",
                                                value:
                                                    SettingsNotifier
                                                        .instance
                                                        .bookingAlertsEnabled,
                                                onChanged:
                                                    (val) => SettingsNotifier
                                                        .instance
                                                        .updateBookingAlertsEnabled(
                                                          val,
                                                        ),
                                              ),
                                              Divider(
                                                height: 1,
                                                indent: 16,
                                                endIndent: 16,
                                                color: context.colorBorder
                                                    .withValues(alpha: 0.3),
                                              ),
                                              _buildDialogToggle(
                                                context: context,
                                                title: "Appointment Reminders",
                                                value:
                                                    SettingsNotifier
                                                        .instance
                                                        .reminderAlertsEnabled,
                                                onChanged: (val) {
                                                  SettingsNotifier.instance
                                                      .updateReminderAlertsEnabled(
                                                        val,
                                                      );
                                                  if (!val) {
                                                    AppointmentNotificationService
                                                        .instance
                                                        .cancelAllReminders();
                                                  }
                                                },
                                              ),

                                              // Inline Time Selector
                                              AnimatedSize(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                child:
                                                    SettingsNotifier
                                                            .instance
                                                            .reminderAlertsEnabled
                                                        ? InkWell(
                                                          onTap:
                                                              _showReminderTimeSelectionDialog,
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 12,
                                                                ),
                                                            child: Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                const Text(
                                                                  "Alert Time",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color:
                                                                        Colors
                                                                            .grey,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Text(
                                                                      _getReminderTimeName(
                                                                        SettingsNotifier
                                                                            .instance
                                                                            .globalReminderMinutes,
                                                                      ),
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        color:
                                                                            AppColors.primaryGreen,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    const Icon(
                                                                      Icons
                                                                          .arrow_drop_down_rounded,
                                                                      color:
                                                                          AppColors
                                                                              .primaryGreen,
                                                                      size: 18,
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                        : const SizedBox.shrink(),
                                              ),

                                              Divider(
                                                height: 1,
                                                indent: 16,
                                                endIndent: 16,
                                                color: context.colorBorder
                                                    .withValues(alpha: 0.3),
                                              ),
                                              _buildDialogToggle(
                                                context: context,
                                                title: "App Updates",
                                                value:
                                                    SettingsNotifier
                                                        .instance
                                                        .appUpdatesEnabled,
                                                onChanged:
                                                    (val) => SettingsNotifier
                                                        .instance
                                                        .updateAppUpdatesEnabled(
                                                          val,
                                                        ),
                                              ),

                                              // PRO FIX: Added a tiny padding bumper so the bottom-most list item
                                              // doesn't look cramped against the bottom curve
                                              const SizedBox(height: 4),
                                            ],
                                          ),
                                        )
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: "Done",
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDialogToggle({
    required BuildContext context,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primaryGreen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      visualDensity: VisualDensity.compact,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: context.colorTextDark,
        ),
      ),
    );
  }

  // --- TIME SELECTION BOTTOM SHEET ---
  void _showReminderTimeSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Global Reminder Time",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ...[15, 30, 60, 120, 1440].map((mins) {
                  final isSelected =
                      SettingsNotifier.instance.globalReminderMinutes == mins;
                  return InkWell(
                    onTap: () {
                      SettingsNotifier.instance.updateGlobalReminderMinutes(
                        mins,
                      );
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          _getReminderTimeName(mins),
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color: isSelected ? AppColors.primaryGreen : null,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryGreen,
                                )
                                : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTimeoutSelectionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Inactivity Lock",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ...[0, 60000, 300000, 900000, 1800000, 3600000].map((timeout) {
                  final isSelected =
                      SettingsNotifier.instance.inactivityTimeoutMs == timeout;
                  return InkWell(
                    onTap: () {
                      SettingsNotifier.instance.updateInactivityTimeout(
                        timeout,
                      );
                      Navigator.pop(context);
                      if (mounted) setState(() {});
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          _getTimeoutName(timeout),
                          style: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                            color: isSelected ? AppColors.primaryGreen : null,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.primaryGreen,
                                )
                                : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
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

        // --- PRO FIX: Clean Card that triggers the Floating Dialog ---
        AnimatedBuilder(
          animation: SettingsNotifier.instance,
          builder: (context, child) {
            final isGlobalEnabled =
                SettingsNotifier.instance.notificationsEnabled;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppStyles.surfaceCard(
                context,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap:
                      () =>
                          _showNotificationSettingsDialog(), // Triggers the Floating Window
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            isGlobalEnabled
                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isGlobalEnabled
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_off_rounded,
                        color:
                            isGlobalEnabled
                                ? AppColors.primaryGreen
                                : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colorTextDark,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isGlobalEnabled ? "On" : "Off",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isGlobalEnabled
                                    ? AppColors.primaryGreen
                                    : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
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
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) {
                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Appearance",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildThemeOption(
                          context,
                          ThemeMode.system,
                          "System Default",
                          Icons.brightness_auto_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildThemeOption(
                          context,
                          ThemeMode.light,
                          "Light Mode",
                          Icons.light_mode_rounded,
                        ),
                        const SizedBox(height: 8),
                        _buildThemeOption(
                          context,
                          ThemeMode.dark,
                          "Dark Mode",
                          Icons.dark_mode_rounded,
                        ),
                      ],
                    ),
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
              decoration: AppStyles.surfaceCard(
                context,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
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
                title: Text(
                  "Menu Drawer Hint",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.colorTextDark,
                  ),
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

  Widget _buildThemeOption(
    BuildContext context,
    ThemeMode mode,
    String title,
    IconData icon,
  ) {
    final isSelected = SettingsNotifier.instance.themeMode == mode;
    return InkWell(
      onTap: () {
        SettingsNotifier.instance.updateThemeMode(mode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primaryGreen.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primaryGreen.withValues(alpha: 0.3)
                    : Colors.transparent,
          ),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? AppColors.primaryGreen : Colors.grey,
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primaryGreen : null,
            ),
          ),
          trailing:
              isSelected
                  ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryGreen,
                  )
                  : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          dense: true,
        ),
      ),
    );
  }
}
