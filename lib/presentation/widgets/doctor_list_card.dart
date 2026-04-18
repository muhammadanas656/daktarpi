import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import 'app_network_image.dart';

class DoctorListCard extends StatelessWidget {
  final int id;
  final String name;
  final String specialty;
  final String rating;
  final String views;
  final String? imageUrl;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final VoidCallback onCardTap;
  final String heroTagPrefix;
  final Widget? trailingWidget;
  
  // Generic Styling Slots for highly-scalable architecture
  final Color? customBorderColor;
  final Widget? customBadgeOverlay;
  final Widget? customRatingWidget;

  const DoctorListCard({
    super.key,
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.views,
    required this.imageUrl,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.onCardTap,
    this.heroTagPrefix = 'doctor-list-',
    this.trailingWidget,
    this.customBorderColor,
    this.customBadgeOverlay,
    this.customRatingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Evaluate Data State for intelligent fallbacks
    final double numericRating = double.tryParse(rating) ?? 0.0;
    final bool hasRating = numericRating > 0.0;
    final bool hasViews = views != '0' && views.isNotEmpty && views != 'null';

    return RepaintBoundary(
      key: ValueKey('${heroTagPrefix}_$id'),
      child: Container(
        // 1. BACKGROUND & SHADOW
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: customBorderColor != null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    customBorderColor!.withOpacity(isDark ? 0.12 : 0.05),
                    customBorderColor!.withOpacity(0.0),
                  ],
                )
              : null,
          color: customBorderColor == null
              ? (isDark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white)
              : null,
          boxShadow: [
            if (customBorderColor != null)
              BoxShadow(
                color: customBorderColor!.withOpacity(isDark ? 0.15 : 0.08),
                blurRadius: isDark ? 24 : 12,
                offset: isDark ? const Offset(0, 8) : const Offset(0, 3),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        // 2. THE BORDER
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: customBorderColor != null
                ? customBorderColor!.withOpacity(isDark ? 0.3 : 0.12)
                : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04)),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        // 3. THE CONTENT
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onCardTap();
            },
            highlightColor: Colors.transparent,
            splashColor: AppColors.primaryGreen.withOpacity(0.06),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14.0), 
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // --- 1. THE COMPACT SQUIRCLE AVATAR ---
                      Container(
                        width: 80, 
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18), 
                          border: Border.all(
                            color: isDark ? Colors.white24 : Colors.black12,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17), 
                          child: AppNetworkImage(
                            imageUrl: imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            fallbackIconSize: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // --- 2. THE EDITORIAL GRID ---
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                                      letterSpacing: -0.3,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                trailingWidget ?? Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: AnimatedFavoriteButton(
                                    isFavorite: isFavorite,
                                    onTap: onFavoriteTap,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 4), 

                            // Specialty Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : AppColors.primaryGreen.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                specialty,
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            const SizedBox(height: 10), 

                            // --- 3. THE STRUCTURAL DIVIDER ---
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: isDark ? Colors.white12 : Colors.black.withOpacity(0.04), 
                            ),
                            
                            const SizedBox(height: 10), 

                            // --- 4. THE CLEAN METRICS LINE ---
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                customRatingWidget ?? (hasRating
                                    ? Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                                          const SizedBox(width: 4),
                                          Text(
                                            rating,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Container(
                                        // THE UPGRADE: The "NEW" Ghost Pill
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.amber.withOpacity(0.12) : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          "NEW",
                                          style: TextStyle(
                                            color: isDark ? Colors.amber : Colors.orange.shade800,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      )),

                                if (hasViews) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Container(
                                      width: 3.5,
                                      height: 3.5,
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white30 : Colors.black.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.visibility_outlined,
                                    color: isDark ? Colors.white54 : const Color(0xFF86868B), 
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    views,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                      color: isDark ? Colors.white54 : const Color(0xFF86868B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // THE FIX: Injects custom badges anywhere on the platform seamlessly
                if (customBadgeOverlay != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: customBadgeOverlay!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// ZERO-LATENCY Animated Favorite Button (Unchanged)
// ----------------------------------------------------------------------

class AnimatedFavoriteButton extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;

  const AnimatedFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onTap,
  });

  @override
  State<AnimatedFavoriteButton> createState() => _AnimatedFavoriteButtonState();
}

class _AnimatedFavoriteButtonState extends State<AnimatedFavoriteButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late bool _localIsFavorite;

  @override
  void initState() {
    super.initState();
    _localIsFavorite = widget.isFavorite;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.25).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedFavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFavorite != oldWidget.isFavorite && widget.isFavorite != _localIsFavorite) {
      setState(() {
        _localIsFavorite = widget.isFavorite;
      });
      if (_localIsFavorite) {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleOptimisticTap() {
    HapticFeedback.lightImpact();
    setState(() {
      _localIsFavorite = !_localIsFavorite;
    });
    if (_localIsFavorite) {
      _controller.forward(from: 0.0);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _handleOptimisticTap, 
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _localIsFavorite ? _scaleAnimation.value : 1.0,
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(8), 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _localIsFavorite
                    ? AppColors.dangerRed.withOpacity(0.12) 
                    : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: Icon(
                  _localIsFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  key: ValueKey(_localIsFavorite),
                  color: _localIsFavorite ? AppColors.dangerRed : (isDark ? Colors.white54 : const Color(0xFF86868B)), 
                  size: 20, 
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
