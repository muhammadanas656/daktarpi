import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.onBackPressed,
    this.actions,
    this.backgroundColor = Colors.transparent,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: titleWidget ?? (title != null ? Text(
        title!,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1D1D1F),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ) : const SizedBox.shrink()),
      centerTitle: true,
      backgroundColor: backgroundColor,
      
      // 1. KILL ALL NATIVE SHADOWS EXPLICITLY
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent, 

      flexibleSpace: ClipRRect(
        child: Stack(
          children: [
            // PRO FIX 1: The Z-Index Buffer. 
            // This solid layer sits BEHIND the blur, eating harsh drop-shadows from 
            // cards below so they don't get amplified by the blur engine!
            Positioned.fill(
              child: Container(
                color: isDark 
                    ? Colors.black.withValues(alpha: 0.6) 
                    : Colors.white.withValues(alpha: 0.8), // Strong enough to mute shadows, light enough to remain translucent
              ),
            ),
            
            // PRO FIX 2: The actual Frost layer
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24, tileMode: TileMode.mirror),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent, // Color is now handled by the buffer layer above
                    border: Border(
                      bottom: BorderSide(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.05) 
                            : Colors.black.withValues(alpha: 0.03),
                        width: 0.5, 
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      leadingWidth: 72,
      leading: Container(
        padding: const EdgeInsets.only(left: 24),
        alignment: Alignment.centerLeft,
        child: Material(
          elevation: 0,
          // THE FIX: Smart Contrast! 
          // Dark Mode = White Frost. Light Mode = Black Ink Frost.
          color: isDark 
              ? Colors.white12 
              : Colors.black.withValues(alpha: 0.05), // A subtle, elegant dark tint
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              if (onBackPressed != null) {
                onBackPressed!();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                // THE FIX: Ensure the icon matches the deep contrast of the text!
                color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                size: 18,
              ),
            ),
          ),
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
