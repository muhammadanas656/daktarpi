import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../presentation/widgets/custom_snackbar.dart';

import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/app_routes.dart';
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
  double _minAllowedRadius = 25.0; // Updated default
  double _globalMaxRadius = 500.0;
  double _globalMinRadius = 25.0;  // Added min tracker
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

  void _checkAndFetchRadiusIfNeeded() async {
    // CRITICAL: Prevent the Double-Fire Race Condition!
    // Do NOT fire the parent callback prematurely if we are literally about to fetch the bounds.
    final expectsBackgroundGpsLaunch = _activeRadiusKm == null && _isRadiusAutoCalculated && !_isFetchingRadius;
    if (!expectsBackgroundGpsLaunch) {
      widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
    }

    final needsGps = _selectedFilter == 'Nearest' ||
        _selectedFilter == 'Available Today' ||
        _selectedFilter == 'Hospital' ||
        _selectedFilter == 'Clinic';

    if (needsGps && !widget.isBackgroundLayer) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        await context.push(AppRoutes.locationPermission);
      }
    }

    if (!mounted) return;

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
      _globalMaxRadius = await DoctorsNotifier.instance.fetchMaxPlatformRadius();
      _globalMinRadius = await DoctorsNotifier.instance.fetchMinPlatformRadius();

      // THE FIX 1: Guarantee the Profile is loaded so countryIso is NEVER null!
      if (!ProfileNotifier.instance.isLoaded) {
        await ProfileNotifier.instance.loadProfile();
      }

      final pos = await DoctorsNotifier.instance.getUserPosition();
      final countryIso = ProfileNotifier.instance.profile?.countryIso ?? 'PK';

      if (pos != null) {
        debugPrint('🔍 [SmartFilterBar] Requesting GPS: lat=${pos.latitude}, lng=${pos.longitude}, country=$countryIso');
        final optimalRadius = await DoctorsNotifier.instance.fetchSmartClusterRadius(
          userLat: pos.latitude,
          userLng: pos.longitude,
          countryIso: countryIso,
        );
        debugPrint('🔍 [SmartFilterBar] Received optimalRadius from Notifier: $optimalRadius');

        if (mounted) {
          setState(() {
            // 1. The ACTIVE radius safely expands to capture the cluster.
            _activeRadiusKm = optimalRadius;

            // 2. The SLIDER'S absolute floor remains locked to the database minimum.
            _minAllowedRadius = _globalMinRadius;
            _isFetchingRadius = false;
          });
          // Triggers the Screen to finally load the doctors!
          widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
        }
      } else {
        // GPS Denied Fallback
        if (mounted) {
          setState(() {
            _activeRadiusKm = _globalMaxRadius > 50.0 ? 50.0 : _globalMaxRadius;
            _minAllowedRadius = _globalMinRadius;
            _isFetchingRadius = false;
          });
          widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
        }
      }
    } catch (e) {
      debugPrint('🚨 [SmartFilterBar] Exception in _fetchOptimalRadius triggering fallback: $e');
      if (mounted) {
        setState(() {
          _activeRadiusKm = _globalMaxRadius > 50.0 ? 50.0 : _globalMaxRadius;
          _minAllowedRadius = _globalMinRadius;
          _isFetchingRadius = false;
        });
        widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
      }
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
    // THE FIX: Hide the pill entirely if the database returned -1.0 (empty state)
    if ((_activeRadiusKm == null || _activeRadiusKm == -1.0) && !_isFetchingRadius) {
      return const SizedBox.shrink();
    }

    final String text = _isFetchingRadius 
        ? "Calculating boundary..." 
        : "Within ${_activeRadiusKm!.ceil()} km";

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
            _showRadiusBottomSheet(context);
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

  void _showRadiusBottomSheet(BuildContext context) {
    setState(() => _isRadiusPillExpanded = true);

    // Context from the widget tree tells us exact bottom padding
    // Includes dock 110px padding IF dock is present on this specific page
    final double sourceBottomPadding = MediaQuery.of(context).padding.bottom;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return _PremiumRadiusBottomSheet(
          initialRadius: _activeRadiusKm ?? _minAllowedRadius,
          minAllowedRadius: _minAllowedRadius,
          globalMaxRadius: _globalMaxRadius,
          isDark: Theme.of(ctx).brightness == Brightness.dark,
          bottomViewPadding: sourceBottomPadding,
          onApply: (newRadius) {
            Navigator.pop(ctx);
            _applyRadius(newRadius);
          },
          onResetToOptimal: () {
            Navigator.pop(ctx);
            _isRadiusAutoCalculated = true;
            _activeRadiusKm = null;
            _checkAndFetchRadiusIfNeeded();
          },
        );
      },
    ).then((_) {
      // Runs when the bottom sheet closes (whether they swiped it down or hit apply)
      if (mounted) setState(() => _isRadiusPillExpanded = false);
    });
  }

  void _applyRadius(double val) {
    HapticFeedback.selectionClick();
    _isRadiusAutoCalculated = false;

    if (val < _minAllowedRadius) {
      val = _minAllowedRadius;
      if (mounted) {
        CustomSnackbar.showInfo(
          context,
          'Minimum cluster radius is ${_minAllowedRadius.ceil()} km — setting that instead.',
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

class _PremiumRadiusBottomSheet extends StatefulWidget {
  final double initialRadius;
  final double minAllowedRadius;
  final double globalMaxRadius;
  final bool isDark;
  final double bottomViewPadding;
  final void Function(double) onApply;
  final VoidCallback onResetToOptimal;

  const _PremiumRadiusBottomSheet({
    Key? key,
    required this.initialRadius,
    required this.minAllowedRadius,
    required this.globalMaxRadius,
    required this.isDark,
    required this.bottomViewPadding,
    required this.onApply,
    required this.onResetToOptimal,
  }) : super(key: key);

  @override
  State<_PremiumRadiusBottomSheet> createState() => _PremiumRadiusBottomSheetState();
}

class _PremiumRadiusBottomSheetState extends State<_PremiumRadiusBottomSheet> {
  late double _currentValue;
  bool _isEditingCustom = false;
  final TextEditingController _customController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // THE FIX: The UI max strictly adheres to the database `app_settings` radius!
  double get _safeMax {
    return widget.globalMaxRadius > widget.minAllowedRadius
        ? widget.globalMaxRadius
        : widget.minAllowedRadius + 10.0;
  }

  @override
  void initState() {
    super.initState();
    // Safely clamp the incoming value to our dynamic bounds
    _currentValue = widget.initialRadius.clamp(widget.minAllowedRadius, _safeMax);
  }

  @override
  void dispose() {
    _customController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitCustomValue() {
    final double? parsed = double.tryParse(_customController.text);
    
    if (parsed != null) {
      // THE FIX: Graceful fallbacks instead of reverting
      double finalValue = parsed;
      
      // Lower side fallback
      if (finalValue < widget.minAllowedRadius) {
        finalValue = widget.minAllowedRadius;
      }
      
      // Upper side fallback
      if (finalValue > _safeMax) {
        finalValue = _safeMax;
      }

      setState(() {
        _currentValue = finalValue;
        _isEditingCustom = false;
      });
    } else {
      // Revert if out of bounds or empty
      setState(() => _isEditingCustom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clamp aggressively on every build just in case external factors change
    _currentValue = _currentValue.clamp(widget.minAllowedRadius, _safeMax);

    final bgColor = widget.isDark ? AppColors.darkSurface : Colors.white;
    final textColor = widget.isDark ? AppColors.darkTextPrimary : AppColors.textDark;
    final subtitleColor = widget.isDark ? AppColors.darkTextSecondary : AppColors.textLight;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.only(
          // Dynamically matches exactly what the calling screen's bottom layout provides
          // Will dynamically be large if the Holographic dock is there, or small if not
          bottom: widget.bottomViewPadding + 16,
          top: 12,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Search Area",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                // THE UPGRADE: Premium Discoverable Editable Pill
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditingCustom = true;
                      _customController.text = _currentValue.ceil().toString();
                    });
                    // Add a tiny delay to ensure the TextField is built before requesting focus
                    Future.microtask(() => _focusNode.requestFocus());
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isEditingCustom 
                          ? AppColors.primaryGreen.withOpacity(0.2) 
                          : AppColors.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isEditingCustom 
                            ? AppColors.primaryGreen.withOpacity(0.3) 
                            : Colors.transparent, 
                        width: 1.5
                      ), 
                    ),
                    child: _isEditingCustom
                        ? IntrinsicWidth(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 40, maxWidth: 80),
                              child: TextField(
                                controller: _customController,
                                focusNode: _focusNode,
                                
                                // THE FIX: Physically restrict keyboard to numbers only
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                
                                textAlign: TextAlign.center,
                                cursorColor: AppColors.primaryGreen,
                                cursorHeight: 20,
                                cursorWidth: 2,
                                cursorRadius: const Radius.circular(2),
                                enableInteractiveSelection: false, // Kills the teardrop completely
                                
                                style: const TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.w800, 
                                  color: AppColors.primaryGreen,
                                  height: 1.2,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  suffixText: 'km',
                                  suffixStyle: TextStyle(
                                    fontSize: 14, 
                                    fontWeight: FontWeight.bold, 
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                onSubmitted: (_) => _submitCustomValue(),
                                onTapOutside: (_) => _submitCustomValue(),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_currentValue.ceil()} km",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryGreen,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.edit_rounded, 
                                size: 14, 
                                color: AppColors.primaryGreen.withOpacity(0.8),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                // THE FIX: Dynamic helper text reflecting the 2-digit max
                _isEditingCustom 
                    ? "Enter a distance up to ${_safeMax.ceil()} km."
                    : "Expand your search to find more specialists.",
                style: TextStyle(color: subtitleColor, fontSize: 14),
              ),
            ),
            const SizedBox(height: 32),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primaryGreen,
                inactiveTrackColor: widget.isDark ? Colors.white12 : Colors.black12,
                thumbColor: AppColors.primaryGreen,
                overlayColor: AppColors.primaryGreen.withOpacity(0.2),
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              ),
              child: Slider(
                value: _currentValue,
                min: widget.minAllowedRadius,
                max: _safeMax, 
                onChanged: _isEditingCustom ? null : (val) {
                  setState(() => _currentValue = val);
                  if (val.ceil() % 10 == 0) HapticFeedback.selectionClick();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${widget.minAllowedRadius.ceil()} km", style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text("${_safeMax.ceil()} km", style: TextStyle(color: subtitleColor, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextButton(
                    onPressed: widget.onResetToOptimal,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      "Auto",
                      style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (_isEditingCustom) _submitCustomValue();
                      widget.onApply(_currentValue);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text("Apply Radius", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
