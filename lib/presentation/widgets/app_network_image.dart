import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final String? cacheKey; // PRO FIX: Added cacheKey for Signed URLs
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
    final placeholder = _buildShimmer();
    final fallback = _buildFallback();
    final url = imageUrl?.trim();

    Widget imageChild;
    if (url == null || url.isEmpty) {
      imageChild = fallback;
    } else {
      imageChild = CachedNetworkImage(
        imageUrl: url,
        cacheKey:
            cacheKey, // PRO FIX: Binds the image to the phone's disk permanently
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => fallback,
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

  Widget _buildShimmer() {
    return RepaintBoundary( // PRO FIX: Isolates the shader so it doesn't corrupt the GPU during 3D scaling
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF8FAFC),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            shape: circular ? BoxShape.circle : BoxShape.rectangle,
          ),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return RepaintBoundary( // PRO FIX: Stops offline font glyphs from crashing the text atlas
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
