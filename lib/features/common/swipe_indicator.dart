import 'package:flutter/material.dart';

class SwipeIndicator extends StatefulWidget {
  final VoidCallback onDismiss;

  const SwipeIndicator({super.key, required this.onDismiss});

  @override
  State<SwipeIndicator> createState() => _SwipeIndicatorState();
}

class _SwipeIndicatorState extends State<SwipeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // UPDATED: Start from 20.0 (inside safe area) instead of -20.0 (edge)
    // Moves to 120.0 to show a clear "open drawer" motion
    _positionAnimation = Tween<double>(begin: 20.0, end: 120.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _startTutorial();
  }

  Future<void> _startTutorial() async {
    await _controller.forward();
    _controller.reset();
    await _controller.forward();

    if (mounted) {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Dimmed Background
        GestureDetector(
          onTap: widget.onDismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // 2. Animated Swipe Hand
        Positioned(
          left: 0,
          // Center vertically
          top: MediaQuery.of(context).size.height * 0.4,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                // Animation moves it from left: 20 -> 120
                offset: Offset(_positionAnimation.value, 0),
                child: Opacity(opacity: _opacityAnimation.value, child: child),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.touch_app_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 12),
                const Material(
                  color: Colors.transparent,
                  child: Text(
                    "Swipe to open menu",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
