import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import 'settings_section_header.dart';
import 'settings_tile.dart';

class SettingsSupportLegalSection extends StatelessWidget {
  const SettingsSupportLegalSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: "Support & Legal"),
        SettingsTile(
          icon: Icons.help_outline,
          title: "Help Center",
          onTap: () => context.push(AppRoutes.helpCenter),
        ),
        SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: "Privacy Policy",
          onTap: () => context.push(AppRoutes.privacyPolicy),
        ),
        SettingsTile(
          icon: Icons.description_outlined,
          title: "Terms of Service",
          onTap: () => context.push(AppRoutes.termsOfService),
        ),
        SettingsTile(
          icon: Icons.info_outline,
          title: "About App",
          value: "v1.0.0",
          onTap: () {},
        ),
      ],
    );
  }
}
