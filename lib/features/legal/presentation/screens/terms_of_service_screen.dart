import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/legal_text.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simple parser to separate headers from body
    // Assumes format: ## Header \n Body
    final List<String> sections = LegalText.termsOfService.split('## ');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Terms of Service",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
      ),
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                sections.map((section) {
                  if (section.trim().isEmpty) return const SizedBox.shrink();

                  // First line is header, rest is body
                  final lines = section.split('\n');
                  final header = lines.first.trim();
                  final body = lines.sublist(1).join('\n').trim();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (header.isNotEmpty)
                          Text(
                            header,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        if (header.isNotEmpty) const SizedBox(height: 8),
                        Text(
                          body,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }
}
