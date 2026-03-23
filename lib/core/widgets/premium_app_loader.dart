import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PremiumAppLoader extends StatefulWidget {
  final double size;
  final Color? primaryColor;

  const PremiumAppLoader({
    super.key,
    this.size = 36.0, // Slightly smaller default for elegance
    this.primaryColor,
  });

  @override
  State<PremiumAppLoader> createState() => _PremiumAppLoaderState();
}

class _PremiumAppLoaderState extends State<PremiumAppLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // A smooth 1.2s sine-wave cycle
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPill(int index, Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // --- THE MATH ---
        // Creates a seamless flowing wave by offsetting each pill's start time
        // math.pi / 2.5 ensures a beautiful trailing effect
        final wave = math.sin((_controller.value * 2 * math.pi) - (index * math.pi / 2.5));
        
        // Maps the sine wave (-1 to +1) to a vertical scale (0.5 to 1.0)
        final scaleY = 0.75 + (0.25 * wave);
        
        // Maps the sine wave to opacity for a soft glowing trail
        final opacity = 0.6 + (0.4 * wave);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scaleY: scaleY, // ONLY stretches vertically (Hardware Accelerated!)
            child: Container(
              width: widget.size * 0.22, // Proportional width
              height: widget.size,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100), // Perfect pill shape
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3 * opacity),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              ),
            ),
          ),
        );
      },
    );
  }

 @override
  Widget build(BuildContext context) {
    final color = widget.primaryColor ?? AppColors.primaryGreen;

    // --- PRO FIX: Removed RepaintBoundary ---
    // RepaintBoundaries inside of Slide/Fade Transitions can cause 
    // the very first frame to freeze. Removing it allows it to flow freely!
    return SizedBox(
      width: widget.size * 1.2,
      height: widget.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildPill(0, color),
          _buildPill(1, color),
          _buildPill(2, color),
        ],
      ),
    );
  }
}
