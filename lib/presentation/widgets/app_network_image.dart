import 'dart:io'; // PRO FIX: Added dart:io for local file handling
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
    final fallback = _buildFallback();
    final url = imageUrl?.trim();

    Widget imageChild;
    if (url == null || url.isEmpty) {
      imageChild = fallback;
    } 
    // PRO FIX: If it's a web URL, aggressively cache it!
    else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageChild = CachedNetworkImage(
        imageUrl: url,
        cacheKey: cacheKey,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => _buildShimmer(context),
        errorWidget: (context, url, error) => fallback,
      );
    } 
    // PRO FIX: If it's a local file (like a newly picked category image), render it instantly!
    else {
      final file = File(url);
      imageChild = Image.file(
        file,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
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

    final Color baseColor =
        isDark
            ? const Color(0xFF1E293B) 
            : const Color(0xFFF1F5F9); 

    final Color highlightColor =
        isDark
            ? const Color(0xFF334155) 
            : const Color(0xFFFFFFFF); 

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