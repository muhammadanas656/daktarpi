import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class DoctorListCardSkeleton extends StatelessWidget {
  const DoctorListCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Shimmer.fromColors(
          baseColor:
              isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
          highlightColor:
              isDark ? Colors.white24 : Colors.black.withOpacity(0.09),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _SkeletonBlock(
                              height: 18,
                              radius: 6,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const _SkeletonCircle(size: 30),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const _SkeletonBlock(
                        width: 112,
                        height: 22,
                        radius: 8,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          _SkeletonBlock(width: 52, height: 12),
                          SizedBox(width: 12),
                          _SkeletonCircle(size: 4),
                          SizedBox(width: 12),
                          _SkeletonBlock(width: 68, height: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorListSkeletonSliver extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry itemPadding;
  final int itemCount;

  const DoctorListSkeletonSliver({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 24),
    this.itemPadding = const EdgeInsets.only(bottom: 16),
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: itemPadding,
            child: const DoctorListCardSkeleton(),
          ),
          childCount: itemCount,
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;

  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}
