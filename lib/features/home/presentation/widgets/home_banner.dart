import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class HomeBanner extends StatelessWidget {
  final List<Map<String, dynamic>> banners;

  const HomeBanner({super.key, required this.banners});

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();

    // For simplicity, showing the first banner. Could be converted to a carousel.
    final banner = banners.first;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF008FA0), Color(0xFF00C689)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20), // Premium Radius
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF008FA0).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 30,
              child: SizedBox(
                width: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      banner['title'] ?? "Medical Center",
                      style: AppTextStyles.h3.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      banner['subtitle'] ??
                          "Find the best doctors in your area.",
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (banner['image_url'] != null)
              Positioned(
                right: 10,
                bottom: 0,
                child: Image.network(
                  banner['image_url'],
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
