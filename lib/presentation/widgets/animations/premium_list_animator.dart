import 'package:flutter/material.dart';

class PremiumListAnimator extends StatefulWidget {
  final Widget child;
  final int index;
  final bool isHorizontal;

  const PremiumListAnimator({
    super.key,
    required this.child,
    required this.index,
    this.isHorizontal = false,
  });

  @override
  State<PremiumListAnimator> createState() => _PremiumListAnimatorState();
}

class _PremiumListAnimatorState extends State<PremiumListAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );

    Future.delayed(
      Duration(milliseconds: (widget.index * 50).clamp(0, 400).toInt()),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        return Transform.translate(
          offset:
              widget.isHorizontal
                  ? Offset(40 * (1 - val), 0)
                  : Offset(0, 40 * (1 - val)),
          child: Transform.scale(
            scale: 0.95 + (0.05 * val),
            child: Opacity(
              opacity: val.clamp(0.0, 1.0).toDouble(),
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
