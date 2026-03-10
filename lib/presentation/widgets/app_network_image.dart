import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final String? cacheKey;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool circular;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.cacheKey,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.circular = false,
    this.fallbackIcon = Icons.person,
    this.fallbackIconSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    // PRO FIX: We define the assets inside build to pass the context to the shimmer
    final fallback = _buildFallback();
    final url = imageUrl?.trim();

    Widget imageChild;
    if (url == null || url.isEmpty) {
      imageChild = fallback;
    } else {
      imageChild = CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        width: width,
        height: height,
        fit: fit,
        // PRO FIX: Passing context here to ensure the shimmer knows the theme mode
        placeholder: (context, url) => _buildShimmer(context),
        errorWidget: (context, url, error) => fallback,
      );
    }

    if (circular) {
      return ClipOval(child: imageChild);
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageChild);
    }
    return imageChild;
  }

  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // PROFESSIONAL TOKENS: Slate-based palette for a high-end medical-tech feel
    final Color baseColor =
        isDark
            ? const Color(0xFF1E293B) // Dark Slate
            : const Color(0xFFF1F5F9); // Light Slate

    final Color highlightColor =
        isDark
            ? const Color(0xFF334155) // Lighter Slate
            : const Color(0xFFFFFFFF); // Pure White

    return RepaintBoundary(
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        period: const Duration(milliseconds: 1500),
        direction: ShimmerDirection.ltr,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: baseColor,
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
            // Only apply borderRadius if we are not in circular mode
            borderRadius: !circular ? borderRadius : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        color: const Color(0xFFEAF2F8),
        alignment: Alignment.center,
        child: Icon(
          fallbackIcon,
          size: fallbackIconSize,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
