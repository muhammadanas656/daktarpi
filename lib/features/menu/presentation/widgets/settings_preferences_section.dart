import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/services/appointment_notification_service.dart';
import '../../../../presentation/widgets/custom_snackbar.dart';
import '../../../../presentation/widgets/primary_button.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../settings/presentation/settings_notifier.dart';
import 'settings_section_header.dart';
import '../widgets/settings_tile.dart';

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

class _SettingsPreferencesSectionState extends State<SettingsPreferencesSection> {
  Future<void> _openNotificationSettingsDialog() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _showNotificationSettingsDialog();
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automatic';
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

  // --- 📌 PRO FIX: The 0ms Latency Appearance Selector ---
  Future<void> _showAppearanceBottomSheet() async {
    final localThemeNotifier = ValueNotifier<ThemeMode>(
      SettingsNotifier.instance.themeMode,
    );

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: localThemeNotifier,
          builder: (ctx, currentMode, child) {
            final isSystem = currentMode == ThemeMode.system;
            final isDark =
                currentMode == ThemeMode.dark ||
                (isSystem &&
                    MediaQuery.platformBrightnessOf(ctx) == Brightness.dark);

            final surfaceColor =
                isDark ? const Color(0xFF121418) : Colors.white;

            void handleThemeChange(ThemeMode newMode) {
              if (localThemeNotifier.value == newMode) return;

              HapticFeedback.selectionClick();
              localThemeNotifier.value = newMode;

              // PRO FIX: Delay the heavy global Theme Rebuild until AFTER the local modal's 250ms AnimatedContainer animation finishes!
              Future.delayed(const Duration(milliseconds: 300), () {
                SettingsNotifier.instance.updateThemeMode(newMode);
              });
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: DefaultTextStyle.of(ctx).style.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        child: const Text("Appearance"),
                      ),
                      const SizedBox(height: 8),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        style: DefaultTextStyle.of(ctx).style.copyWith(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        child: const Text(
                          "Customize how AeviaPulse looks on this device.",
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _buildThemeMockupCard(
                              mode: ThemeMode.light,
                              isSelected:
                                  currentMode == ThemeMode.light ||
                                  (isSystem && !isDark),
                              currentIsDark: isDark,
                              onTap: () => handleThemeChange(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildThemeMockupCard(
                              mode: ThemeMode.dark,
                              isSelected:
                                  currentMode == ThemeMode.dark ||
                                  (isSystem && isDark),
                              currentIsDark: isDark,
                              onTap: () => handleThemeChange(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                isDark
                                    ? Colors.white10
                                    : Colors.grey.withValues(alpha: 0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SwitchListTile(
                          value: isSystem,
                          activeColor: AppColors.primaryGreen,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: DefaultTextStyle.of(ctx).style.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            child: const Text("Automatic"),
                          ),
                          subtitle: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: DefaultTextStyle.of(ctx).style.copyWith(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            child: const Text("Follow system settings"),
                          ),
                          onChanged: (val) {
                            final newMode =
                                val
                                    ? ThemeMode.system
                                    : (isDark
                                        ? ThemeMode.dark
                                        : ThemeMode.light);
                            handleThemeChange(newMode);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    localThemeNotifier.dispose();
    if (mounted) setState(() {});
  }

  // --- 🎨 UI Helper: Draws the beautiful mini-app mockups ---
  // (Only one version of this function exists now!)
  Widget _buildThemeMockupCard({
    required ThemeMode mode,
    required bool isSelected,
    required bool currentIsDark,
    required VoidCallback onTap,
  }) {
    final isCardDark = mode == ThemeMode.dark;
    
    final bgColor = isCardDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
    final surfaceColor = isCardDark ? const Color(0xFF1E293B) : Colors.white;
    final accentColor = isCardDark ? Colors.white24 : Colors.black12;
    final primaryAccent = AppColors.primaryGreen.withValues(alpha: 0.8);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? AppColors.primaryGreen 
                    : (currentIsDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2)),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: AppColors.primaryGreen.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 40, height: 8, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(4))),
                    Container(width: 16, height: 16, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(20))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 24, height: 24, decoration: BoxDecoration(color: primaryAccent, borderRadius: BorderRadius.circular(6))),
                    const SizedBox(width: 8),
                    Expanded(child: Container(height: 16, decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(6)))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.primaryGreen 
                        : (currentIsDark ? Colors.white30 : Colors.grey.withValues(alpha: 0.5)),
                    width: isSelected ? 6 : 2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: DefaultTextStyle.of(context).style.copyWith(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected 
                      ? AppColors.primaryGreen 
                      : (currentIsDark ? Colors.white70 : Colors.black54), 
                ),
                child: Text(isCardDark ? "Dark" : "Light"),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showNotificationSettingsDialog() {
    bool localGlobalEnabled = SettingsNotifier.instance.notificationsEnabled;
    bool localBookingEnabled = SettingsNotifier.instance.bookingAlertsEnabled;
    bool localReminderEnabled = SettingsNotifier.instance.reminderAlertsEnabled;
    bool localFiveHourWarningEnabled = SettingsNotifier.instance.fiveHourWarningEnabled;
    bool localMorningOfReminderEnabled = SettingsNotifier.instance.morningOfReminderEnabled;
    bool localMissedAppointmentAlertEnabled = SettingsNotifier.instance.missedAppointmentAlertEnabled;
    bool localAppUpdatesEnabled = SettingsNotifier.instance.appUpdatesEnabled;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: StatefulBuilder(
            builder: (ctx, setDialogState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;

              return RepaintBoundary(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.grey.withValues(alpha: 0.2),
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: localGlobalEnabled
                                ? AppColors.primaryGreen.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            localGlobalEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                            color: localGlobalEnabled ? AppColors.primaryGreen : Colors.grey,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Notifications",
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          localGlobalEnabled ? "AeviaPulse alerts are active." : "All alerts are currently muted.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(16)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile(
                                  value: localGlobalEnabled,
                                  onChanged: (val) async {
                                    final oldVal = localGlobalEnabled;
                                    setDialogState(() => localGlobalEnabled = val);
                                    try {
                                      await SettingsNotifier.instance.updateNotificationsEnabled(val);
                                      if (!val) await AppointmentNotificationService.instance.cancelAllReminders();
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        setDialogState(() => localGlobalEnabled = oldVal);
                                        CustomSnackbar.showError(context, "Network error");
                                      }
                                    }
                                  },
                                  activeColor: AppColors.primaryGreen,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  title: Text(
                                    "Allow Notifications",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.colorTextDark),
                                  ),
                                ),

                                AnimatedSize(
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeInOutCubic,
                                  alignment: Alignment.topCenter,
                                  clipBehavior: Clip.hardEdge,
                                  child: localGlobalEnabled
                                      ? Container(
                                          color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey[50],
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              Divider(height: 1, color: context.colorBorder.withValues(alpha: 0.5)),
                                              _buildDialogToggle(
                                                context: ctx, title: "Booking Confirmations", value: localBookingEnabled,
                                                onChanged: (val) async {
                                                  final oldVal = localBookingEnabled;
                                                  setDialogState(() => localBookingEnabled = val);
                                                  try { await SettingsNotifier.instance.updateBookingAlertsEnabled(val); } catch (e) { if (ctx.mounted) setDialogState(() => localBookingEnabled = oldVal); }
                                                },
                                              ),
                                              Divider(height: 1, indent: 16, endIndent: 16, color: context.colorBorder.withValues(alpha: 0.3)),
                                              _buildDialogToggle(
                                                context: ctx, title: "Appointment Reminders", value: localReminderEnabled,
                                                onChanged: (val) async {
                                                  final oldVal = localReminderEnabled;
                                                  setDialogState(() => localReminderEnabled = val);
                                                  try {
                                                    await SettingsNotifier.instance.updateReminderAlertsEnabled(val);
                                                    if (!val) await AppointmentNotificationService.instance.cancelAllReminders();
                                                  } catch (e) { if (ctx.mounted) setDialogState(() => localReminderEnabled = oldVal); }
                                                },
                                              ),
                                              AnimatedSize(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOutCubic,
                                                alignment: Alignment.topCenter,
                                                clipBehavior: Clip.hardEdge,
                                                child: localReminderEnabled
                                                    ? Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                                        children: [
                                                          Divider(height: 1, indent: 16, endIndent: 16, color: context.colorBorder.withValues(alpha: 0.3)),
                                                          _buildDialogToggle(context: ctx, title: "5-Hour Warning", value: localFiveHourWarningEnabled, onChanged: (val) async { final old = localFiveHourWarningEnabled; setDialogState(() => localFiveHourWarningEnabled = val); try { await SettingsNotifier.instance.updateFiveHourWarningEnabled(val); } catch (e) { if(ctx.mounted) setDialogState(() => localFiveHourWarningEnabled = old); } }),
                                                          Divider(height: 1, indent: 16, endIndent: 16, color: context.colorBorder.withValues(alpha: 0.3)),
                                                          _buildDialogToggle(context: ctx, title: "Morning-Of Reminder", value: localMorningOfReminderEnabled, onChanged: (val) async { final old = localMorningOfReminderEnabled; setDialogState(() => localMorningOfReminderEnabled = val); try { await SettingsNotifier.instance.updateMorningOfReminderEnabled(val); } catch (e) { if(ctx.mounted) setDialogState(() => localMorningOfReminderEnabled = old); } }),
                                                          Divider(height: 1, indent: 16, endIndent: 16, color: context.colorBorder.withValues(alpha: 0.3)),
                                                          _buildDialogToggle(context: ctx, title: "Missed Appointment Alert", value: localMissedAppointmentAlertEnabled, onChanged: (val) async { final old = localMissedAppointmentAlertEnabled; setDialogState(() => localMissedAppointmentAlertEnabled = val); try { await SettingsNotifier.instance.updateMissedAppointmentAlertEnabled(val); } catch (e) { if(ctx.mounted) setDialogState(() => localMissedAppointmentAlertEnabled = old); } }),
                                                        ],
                                                      )
                                                    : const SizedBox(width: double.infinity, height: 0),
                                              ),

                                              AnimatedSize(
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOutCubic,
                                                alignment: Alignment.topCenter,
                                                clipBehavior: Clip.hardEdge,
                                                child: localReminderEnabled
                                                    ? InkWell(
                                                        onTap: () async { await _showReminderTimeSelectionDialog(); if (ctx.mounted) setDialogState(() {}); },
                                                        child: Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              const Text("Alert Time", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                                                              Row(
                                                                children: [
                                                                  Text(_getReminderTimeName(SettingsNotifier.instance.globalReminderMinutes), style: const TextStyle(fontSize: 14, color: AppColors.primaryGreen, fontWeight: FontWeight.bold)),
                                                                  const SizedBox(width: 4),
                                                                  const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primaryGreen, size: 18),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      )
                                                    : const SizedBox(width: double.infinity, height: 0),
                                              ),

                                              Divider(height: 1, indent: 16, endIndent: 16, color: context.colorBorder.withValues(alpha: 0.3)),
                                              _buildDialogToggle(context: ctx, title: "App Updates", value: localAppUpdatesEnabled, onChanged: (val) async { final old = localAppUpdatesEnabled; setDialogState(() => localAppUpdatesEnabled = val); try { await SettingsNotifier.instance.updateAppUpdatesEnabled(val); } catch (e) { if(ctx.mounted) setDialogState(() => localAppUpdatesEnabled = old); } }),
                                              const SizedBox(height: 4),
                                            ],
                                          ),
                                        )
                                      : const SizedBox(width: double.infinity, height: 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(width: double.infinity, child: PrimaryButton(label: "Done", onTap: () => Navigator.pop(dialogContext))),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDialogToggle({required BuildContext context, required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      value: value, onChanged: onChanged, activeColor: AppColors.primaryGreen, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), visualDensity: VisualDensity.compact,
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colorTextDark)),
    );
  }

  Future<void> _showReminderTimeSelectionDialog() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 24),
                const Text("Global Reminder Time", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ...[15, 30, 60, 120, 1440].map((mins) {
                  final isSelected = SettingsNotifier.instance.globalReminderMinutes == mins;
                  return InkWell(
                    onTap: () { SettingsNotifier.instance.updateGlobalReminderMinutes(mins); Navigator.pop(context); },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(_getReminderTimeName(mins), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primaryGreen : null)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen) : null,
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 24),
                const Text("Inactivity Lock", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ...[0, 60000, 300000, 900000, 1800000, 3600000].map((timeout) {
                  final isSelected = SettingsNotifier.instance.inactivityTimeoutMs == timeout;
                  return InkWell(
                    onTap: () { SettingsNotifier.instance.updateInactivityTimeout(timeout); Navigator.pop(context); if (mounted) setState(() {}); },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        title: Text(_getTimeoutName(timeout), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primaryGreen : null)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen) : null,
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

        AnimatedBuilder(
          animation: SettingsNotifier.instance,
          builder: (context, child) {
            final isGlobalEnabled = SettingsNotifier.instance.notificationsEnabled;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppStyles.surfaceCard(context, borderRadius: BorderRadius.circular(16)),
              child: Material(
                color: Colors.transparent,
                type: MaterialType.transparency,
                child: InkWell(
                  splashFactory: NoSplash.splashFactory, splashColor: Colors.transparent, highlightColor: Colors.transparent, overlayColor: WidgetStateProperty.all(Colors.transparent), borderRadius: BorderRadius.circular(16),
                  onTap: _openNotificationSettingsDialog,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: isGlobalEnabled ? AppColors.primaryGreen.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(isGlobalEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded, color: isGlobalEnabled ? AppColors.primaryGreen : Colors.grey, size: 20),
                    ),
                    title: Text("Notifications", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colorTextDark)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isGlobalEnabled ? "On" : "Off", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isGlobalEnabled ? AppColors.primaryGreen : Colors.grey)),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
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
                value: _getTimeoutName(SettingsNotifier.instance.inactivityTimeoutMs),
                onTap: () => _showTimeoutSelectionDialog(),
              );
            },
          ),

        SettingsTile(
          icon: Icons.attach_money,
          title: "Currency",
          value: ProfileNotifier.instance.currencySymbol,
          subtitle: "Set automatically by location",
          onTap: () => CustomSnackbar.showInfo(context, "Currency is automatically configured based on your profile location."),
        ),

        SettingsTile(
          icon: Icons.dark_mode_outlined,
          title: "Appearance",
          value: _getThemeName(SettingsNotifier.instance.themeMode),
          onTap: _showAppearanceBottomSheet,
        ),


      ],
    );
  }
}
