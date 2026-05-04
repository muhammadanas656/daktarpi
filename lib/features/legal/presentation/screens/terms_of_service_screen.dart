import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/legal_text.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simple parser to separate headers from body
    // Assumes format: ## Header \n Body
    final List<String> sections = LegalText.termsOfService.split('## ');

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(title: "Terms of Service"),
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
            20,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                sections.map((section) {
                  if (section.trim().isEmpty) return SizedBox.shrink();

                  // First line is header, rest is body
                  final lines = section.split('\n');
                  final header = lines.first.trim();
                  final body = lines.sublist(1).join('\n').trim();

                  return Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (header.isNotEmpty)
                          Text(
                            header,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: context.colorTextDark,
                            ),
                          ),
                        if (header.isNotEmpty) SizedBox(height: 8),
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: context.colorTextLight,
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
