import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(title: "Privacy Policy"),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
          20,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Last Updated: February 19, 2026",
              style: AppTextStyles.bodySmall(
                context,
              ).copyWith(color: Colors.grey),
            ),
            SizedBox(height: 20),

            _buildSection(
              context,
              "1. Information We Collect",
              "We collect information you provide directly to us, such as when you create an account, update your profile, book an appointment, or communicate with us. This may include your name, email address, phone number, date of birth, and medical history (if you choose to upload it).",
            ),

            _buildSection(
              context,
              "2. How We Use Your Information",
              "We use your information to provide, maintain, and improve our services, including processing transactions, sending you appointment reminders, and facilitating communication with doctors.",
            ),

            _buildSection(
              context,
              "3. Data Security",
              "We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction. We use industry-standard encryption for sensitive data.",
            ),

            _buildSection(
              context,
              "4. Sharing of Information",
              "We do not share your personal information with third parties except as described in this policy, such as with doctors you book appointments with, or to comply with the law.",
            ),

            _buildSection(
              context,
              "5. Your Choices",
              "You may update or correct your account information at any time by logging into your account settings. You may also delete your account via the Settings menu.",
            ),

            _buildSection(
              context,
              "6. Contact Us",
              "If you have any questions about this Privacy Policy, please contact us at privacy@aeviapulse.com.",
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colorTextDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: context.colorTextLight,
            ),
          ),
        ],
      ),
    );
  }
}
