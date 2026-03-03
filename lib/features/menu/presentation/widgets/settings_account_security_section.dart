import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/widgets/pessimistic_switch.dart';
import '../screens/account_activity_screen.dart';
import 'settings_section_header.dart';
import 'settings_tile.dart';

class SettingsAccountSecuritySection extends StatelessWidget {
  final bool hasEmailProvider;
  final bool hasBiometricHardware;
  final bool isBiometricEnabled;
  final bool isBiometricToggleBusy;
  final Future<bool> Function(bool) onBiometricToggle;
  final bool is2FAEnabled;
  final bool is2FAToggleBusy;
  final Future<bool> Function(bool) onTwoFactorToggle;
  final VoidCallback onTapChangePassword;
  final VoidCallback onTapDeleteAccount;

  const SettingsAccountSecuritySection({
    super.key,
    required this.hasEmailProvider,
    required this.hasBiometricHardware,
    required this.isBiometricEnabled,
    required this.isBiometricToggleBusy,
    required this.onBiometricToggle,
    required this.is2FAEnabled,
    required this.is2FAToggleBusy,
    required this.onTwoFactorToggle,
    required this.onTapChangePassword,
    required this.onTapDeleteAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: "Account & Security"),
        SettingsTile(
          icon: Icons.manage_search,
          title: "Account Activity",
          subtitle: "View your booking history",
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountActivityScreen(),
                ),
              ),
        ),
        if (hasEmailProvider)
          SettingsTile(
            icon: Icons.lock_outline,
            title: "Change Password",
            onTap: onTapChangePassword,
          ),
        SettingsTile(
          icon: Icons.link,
          title: "Linked Accounts",
          subtitle: "Facebook, Google",
          onTap: () => context.push(AppRoutes.linkedAccounts),
        ),
        if (hasBiometricHardware && is2FAEnabled)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              title: const Text(
                "Enable Biometric Login",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
              subtitle:
                  isBiometricToggleBusy
                      ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                "Updating...",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      : Text(
                        isBiometricEnabled
                            ? "Linked to this device"
                            : "Not configured",
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isBiometricEnabled
                                  ? AppColors.primaryGreen
                                  : AppColors.textLight,
                        ),
                      ),
              trailing: PessimisticSwitch(
                value: isBiometricEnabled,
                enabled: !isBiometricToggleBusy,
                activeColor: AppColors.primaryGreen,
                onAttemptChange: onBiometricToggle,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.security,
                color: AppColors.primaryGreen,
                size: 20,
              ),
            ),
            title: const Text(
              "Two-Factor Authentication",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            subtitle:
                is2FAToggleBusy
                    ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Updating security setting...",
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : Text(
                      is2FAEnabled ? "Enabled via Authenticator" : "Disabled",
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            is2FAEnabled
                                ? AppColors.primaryGreen
                                : AppColors.textLight,
                      ),
                    ),
            trailing: PessimisticSwitch(
              value: is2FAEnabled,
              enabled: !is2FAToggleBusy,
              activeColor: AppColors.primaryGreen,
              onAttemptChange: onTwoFactorToggle,
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.delete_forever,
          title: "Delete Account",
          isDestructive: true,
          onTap: onTapDeleteAccount,
        ),
      ],
    );
  }
}
