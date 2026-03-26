import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class DynamicGlassShelfDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  
  DynamicGlassShelfDelegate({required this.child});
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isPinned = shrinkOffset > 0 || overlapsContent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isPinned 
            ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85)
            : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
        boxShadow: isPinned
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: isPinned ? 16.0 : 0.0, 
            sigmaY: isPinned ? 16.0 : 0.0,
          ),
          child: child,
        ),
      ),
    );
  }
  
  @override
  double get maxExtent => 88.0; 
  @override
  double get minExtent => 88.0;
  @override
  bool shouldRebuild(covariant DynamicGlassShelfDelegate oldDelegate) => oldDelegate.child != child;
}
