import 'dart:ui' as ui; // 📌 PRO FIX: Needed for Frosted Glass blur
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_loader.dart';

class AppFloatingDialog extends StatelessWidget {
  final IconData headerIcon;
  final Color iconColor;
  final String title;
  final String? description;
  final Widget content;
  final Widget actions;
  final bool isUpdating; 

  const AppFloatingDialog({
    super.key,
    required this.headerIcon,
    required this.iconColor,
    required this.title,
    this.description,
    required this.content,
    required this.actions,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 📌 PRO FIX: Placed the Frosted Glass BackdropFilter perfectly inside the dialog's shape!
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The Main Box
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              // 📌 PRO FIX: Heavy cinematic drop shadow kept on outer wrapper
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    // 📌 PRO FIX: Slight transparency to make the glass feel real
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: isDark ? 0.85 : 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: AbsorbPointer(
                    absorbing: isUpdating,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 3. The Glowing Header Icon
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: iconColor.withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: Icon(headerIcon, color: iconColor, size: 34),
                          ),
                          const SizedBox(height: 24),

                          // 4. Standardized Typography
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (description != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              description!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),

                          // 5. Custom Content
                          content,

                          const SizedBox(height: 32),
                          // 6. Buttons
                          actions,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

            // 7. Loading Overlay 
            if (isUpdating)
              Positioned.fill( // <--- THE GHOST KILLER: Forces the white box to perfectly match the size of the dialog!
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black54 : Colors.white54,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const AppLoader(
                    size: 40,
                  ),
                ),
              ),
          ],
        ),
    );
  }
}
