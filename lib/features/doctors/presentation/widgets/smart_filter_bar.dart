import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../doctors_notifier.dart';

class FilterConfig {
  static const List<String> standard = ['All', 'Nearest', 'Available Today', 'Top Rated'];
  static const List<String> withFacilities = ['All', 'Nearest', 'Hospital', 'Clinic', 'Top Rated'];
}

class SmartFilterBar extends StatefulWidget {
  final List<String> filters;
  final String initialFilter;
  final bool isBackgroundLayer;
  
  /// Triggered whenever the filter changes, OR when the radius is calculated/changed limit.
  final void Function(String filter, double? maxRadiusKm) onFilterChanged;

  const SmartFilterBar({
    Key? key,
    required this.filters,
    required this.onFilterChanged,
    this.initialFilter = 'All',
    this.isBackgroundLayer = false,
  }) : super(key: key);

  @override
  State<SmartFilterBar> createState() => _SmartFilterBarState();
}

class _SmartFilterBarState extends State<SmartFilterBar> {
  late String _selectedFilter;
  
  // Radius State
  double? _activeRadiusKm;
  bool _isRadiusAutoCalculated = true;
  double _minAllowedRadius = 2.0;
  bool _isFetchingRadius = false;
  
  // UI State
  bool _isRadiusPillExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    if (!widget.isBackgroundLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkAndFetchRadiusIfNeeded();
      });
    }
  }

  void _checkAndFetchRadiusIfNeeded() {
    // Always fire the callback immediately with whatever radius we have (or null).
    // This ensures pill taps are never silently dropped, even mid-GPS-fetch.
    widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
    // If we don't have a radius yet, kick off the GPS fetch in the background,
    // which will fire onFilterChanged again once radius arrives.
    if (_activeRadiusKm == null && _isRadiusAutoCalculated && !_isFetchingRadius) {
      _fetchOptimalRadius();
    }
  }

  Future<void> _fetchOptimalRadius() async {
    if (_isFetchingRadius || widget.isBackgroundLayer) return;
    setState(() => _isFetchingRadius = true);

    try {
      final pos = await DoctorsNotifier.instance.getUserPosition();
      final countryIso = ProfileNotifier.instance.profile?.countryIso;

      if (pos != null && countryIso != null) {
        final optimalRadius = await DoctorsNotifier.instance.fetchSmartClusterRadius(
          userLat: pos.latitude,
          userLng: pos.longitude,
          countryIso: countryIso,
        );

        if (mounted) {
          setState(() {
            _activeRadiusKm = optimalRadius;
            _minAllowedRadius = optimalRadius > 1.0 ? optimalRadius : 1.0;
            _isFetchingRadius = false;
          });
          // Only re-fire the callback for filters that genuinely need GPS.
          // All / Top Rated already got their immediate no-radius callback —
          // firing again here would cause a second fetch (double-fire race).
          final needsGps = _selectedFilter == 'Nearest' ||
              _selectedFilter == 'Available Today';
          if (needsGps) {
            widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
          }
        }
      } else {
        if (mounted) setState(() => _isFetchingRadius = false);
        // GPS unavailable — the immediate null-radius callback already ran, no second fire.
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingRadius = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // When the radius pill expands, we shift the list view to accommodate it.
    // We can use a combination of Row and ListView.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        children: [
          // 1. PRIMARY PILL (Radius)
          _buildPrimaryRadiusPill(isDark),
          
          if (_activeRadiusKm != null || _isFetchingRadius)
            const SizedBox(width: 8),

          // 2. SECONDARY PILLS (Categories)
          ...widget.filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildSecondaryPill(filter, isSelected, isDark),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPrimaryRadiusPill(bool isDark) {
    // Only show if a radius is active or actively fetching
    if (_activeRadiusKm == null && !_isFetchingRadius) {
      return const SizedBox.shrink();
    }

    final String text = _isFetchingRadius 
        ? "Calculating boundary..." 
        : "📍 Within ${_activeRadiusKm!.ceil()} km";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCirc,
      decoration: BoxDecoration(
        color: _isRadiusPillExpanded 
            ? AppColors.primaryGreen.withOpacity(isDark ? 0.15 : 0.08)
            : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isRadiusPillExpanded
              ? AppColors.primaryGreen.withOpacity(0.5)
              : (isDark ? Colors.white12 : Colors.black12),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (widget.isBackgroundLayer || _isFetchingRadius) return;
            HapticFeedback.lightImpact();
            _showRadiusOptions(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Center(
              child: _isFetchingRadius
                  ? const SizedBox(
                      width: 14, 
                      height: 14, 
                      child: CircularProgressIndicator(strokeWidth: 2)
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          text,
                          style: TextStyle(
                            color: _isRadiusPillExpanded 
                                ? AppColors.primaryGreen 
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: _isRadiusPillExpanded ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _isRadiusPillExpanded 
                              ? AppColors.primaryGreen 
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRadiusOptions(BuildContext context) {
    setState(() => _isRadiusPillExpanded = true);
    
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(24, 40), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      items: [
        PopupMenuItem(
          value: 'optimal', 
          child: Text('Optimal Cluster (~${_minAllowedRadius.ceil()} km)')
        ),
        ...[10, 25, 50, 100, 250, 500]
            .where((standard) => standard > _minAllowedRadius.ceil())
            .map((standard) => PopupMenuItem(
                  value: standard.toString(),
                  child: Text('$standard km'),
                )),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'custom', child: Text('Custom Parameter...')),
      ],
    ).then((value) {
      setState(() => _isRadiusPillExpanded = false);
      if (value == null) return;
      
      if (value == 'optimal') {
        _isRadiusAutoCalculated = true;
        _activeRadiusKm = null;
        _checkAndFetchRadiusIfNeeded();
      } else if (value == 'custom') {
        _showCustomRadiusDialog();
      } else {
        final double parsed = double.tryParse(value) ?? 10.0;
        _applyRadius(parsed);
      }
    });
  }

  void _showCustomRadiusDialog() {
    final TextEditingController controller = TextEditingController(
      text: _activeRadiusKm?.ceil().toString() ?? '',
    );
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Custom Range (km)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter distance logically...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? val = double.tryParse(controller.text);
                Navigator.pop(ctx);
                if (val != null) {
                  _applyRadius(val);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }

  void _applyRadius(double val) {
    HapticFeedback.selectionClick();
    _isRadiusAutoCalculated = false;

    if (val < _minAllowedRadius) {
      val = _minAllowedRadius;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Minimum cluster radius is ${_minAllowedRadius.ceil()} km — setting that instead.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() => _activeRadiusKm = val);
    widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
  }

  Widget _buildSecondaryPill(String filter, bool isSelected, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primaryGreen.withOpacity(0.12)
            : (isDark ? Colors.white.withOpacity(0.04) : Colors.transparent),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? Colors.transparent
              : (isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            if (widget.isBackgroundLayer) return;
            HapticFeedback.selectionClick();
            setState(() {
              _selectedFilter = filter;
              // Close radius pill if user switches filters
              if (filter != 'Nearest' && filter != 'Available Today') {
                _isRadiusPillExpanded = false;
              }
            });
            _checkAndFetchRadiusIfNeeded();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primaryGreen
                      : (isDark ? Colors.white70 : const Color(0xFF86868B)),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
