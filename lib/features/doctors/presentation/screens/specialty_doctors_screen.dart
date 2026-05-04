import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../favorites_notifier.dart';
import '../doctors_notifier.dart';
import '../widgets/smart_filter_bar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../../presentation/widgets/animations/premium_list_animator.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/doctor_list_card_skeleton.dart';
import '../../data/doctor_repository.dart';
import '../../../../presentation/widgets/app_network_image.dart';

class SpecialtyDoctorsScreen extends StatefulWidget {
  final String specialtyId;
  final String specialtyName;
  final String? specialtyIconUrl;

  const SpecialtyDoctorsScreen({
    super.key,
    required this.specialtyId,
    required this.specialtyName,
    this.specialtyIconUrl,
  });

  @override
  State<SpecialtyDoctorsScreen> createState() => _SpecialtyDoctorsScreenState();
}

class _SpecialtyDoctorsScreenState extends State<SpecialtyDoctorsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _searchController = TextEditingController();
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  Timer? _debounce;

  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  bool _hasEverLoaded = false;
  String? _specialtyIconUrl;
  String _selectedFilter = "All";
  double? _activeRadiusKm;

  @override
  void initState() {
    super.initState();
    _specialtyIconUrl = widget.specialtyIconUrl;
    _favNotifier.addListener(_onStateChanged);
    _profileNotifier.addListener(_onStateChanged);
    if (_specialtyIconUrl == null) _fetchSpecialtyIcon();
    _searchController.addListener(_onSearchChanged);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fetchData(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _favNotifier.removeListener(_onStateChanged);
    _profileNotifier.removeListener(_onStateChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(query: _searchController.text);
    });
  }

  Future<void> _fetchSpecialtyIcon() async {
    final iconUrl = await _doctorRepo.fetchSpecialtyIcon(widget.specialtyId);
    if (iconUrl != null && mounted) {
      setState(() => _specialtyIconUrl = iconUrl);
    }
  }

  List<Map<String, dynamic>> _applySortOverlay(
      List<Map<String, dynamic>> list, String filter) {
    final out = List<Map<String, dynamic>>.from(list);
    if (filter == 'All') {
      out.sort((a, b) =>
          ((b['views_count'] as int?) ?? 0)
              .compareTo((a['views_count'] as int?) ?? 0));
    } else if (filter == 'Top Rated') {
      out.sort((a, b) {
        final ra = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0.0;
        return rb.compareTo(ra);
      });
    }
    return out;
  }

  Future<void> _fetchData({String? query, bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    List<Map<String, dynamic>>? nextDoctors;

    try {
      if (!_favNotifier.isLoaded) {
        await _favNotifier.loadFavorites();
      }

      final countryIso = _profileNotifier.profile?.countryIso;

      double? userLat;
      double? userLng;

      if (_activeRadiusKm != null ||
          _selectedFilter == 'Nearest' ||
          _selectedFilter == 'Available Today') {
        try {
          final pos = await DoctorsNotifier.instance.getUserPosition();
          if (pos != null) {
            userLat = pos.latitude;
            userLng = pos.longitude;
          }
        } catch (e) {
          debugPrint('Location fetch failed: $e');
        }
      }

      final rawDoctors = await _doctorRepo.fetchDoctorsBySpecialty(
        widget.specialtyId,
        query: query,
        filterType: _selectedFilter,
        maxRadiusKm: _activeRadiusKm,
        countryIso: countryIso,
        userLat: userLat,
        userLng: userLng,
        forceRefresh: forceRefresh,
      );
      nextDoctors = _applySortOverlay(rawDoctors, _selectedFilter);
    } catch (e) {
      debugPrint('Specialty fetch error: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (nextDoctors != null) {
            _doctors = nextDoctors!;
          }
          _isLoading = false;
          _hasEverLoaded = true;
        });
      }
    }
  }

  IconData _getFallbackIcon() {
    final lowerName = widget.specialtyName.toLowerCase();
    if (lowerName.contains('dentist')) return Icons.masks_rounded;
    if (lowerName.contains('cardio')) return Icons.favorite_rounded;
    if (lowerName.contains('eye')) return Icons.remove_red_eye_rounded;
    return Icons.medical_services_rounded;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentIconUrl = _specialtyIconUrl;
    final hasValidIcon = currentIconUrl != null && currentIconUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            top: -150,
            left: -100,
            right: -100,
            height: 400,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryGreen.withOpacity(isDark ? 0.15 : 0.08),
                    AppColors.primaryGreen.withOpacity(0.0),
                  ],
                  stops: const [0.2, 1.0],
                ),
              ),
            ),
          ),
          CustomScrollView(
            clipBehavior: Clip.none,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 288.0,
                collapsedHeight: kToolbarHeight + 12.0,
                toolbarHeight: kToolbarHeight + 12.0,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leadingWidth: 72,
                leading: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Center(
                    child: Material(
                      color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(112.0),
                  child: Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: CustomSearchBar(
                            controller: _searchController,
                            hintText: "Search ${widget.specialtyName}${widget.specialtyName.endsWith('s') ? '' : 's'}...",
                            showClearIcon: _searchController.text.isNotEmpty,
                            onClear: () {
                              HapticFeedback.lightImpact();
                              _searchController.clear();
                              _fetchData(forceRefresh: true);
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SmartFilterBar(
                          filters: FilterConfig.standard,
                          initialFilter: _selectedFilter,
                          onFilterChanged: (filter, radius) {
                            setState(() {
                              _selectedFilter = filter;
                              _activeRadiusKm = radius;
                            });
                            _fetchData(
                              query: _searchController.text,
                              forceRefresh: true,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final top = constraints.biggest.height;
                    final safeArea = MediaQuery.of(context).padding.top;

                    final collapsedHeight =
                        safeArea + kToolbarHeight + 12.0 + 112.0;
                    final expandedHeightTotal = 288.0 + safeArea;

                    final expandRatio =
                        (expandedHeightTotal - collapsedHeight) > 0
                            ? ((top - collapsedHeight) /
                                    (expandedHeightTotal - collapsedHeight))
                                .clamp(0.0, 1.0)
                            : 1.0;
                    final collapseRatio = 1.0 - expandRatio;

                    final largeHeaderOpacity =
                        ((expandRatio - 0.2) / 0.8).clamp(0.0, 1.0);
                    final miniHeaderOpacity =
                        ((collapseRatio - 0.4) / 0.6).clamp(0.0, 1.0);

                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor.withOpacity(0.70),
                                border: Border(
                                  bottom: BorderSide(
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.black.withOpacity(0.05),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          left: 24,
                          right: 24,
                          bottom: 145.0,
                          child: IgnorePointer(
                            ignoring: largeHeaderOpacity == 0.0,
                            child: Opacity(
                              opacity: largeHeaderOpacity,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - largeHeaderOpacity)),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Theme.of(context).colorScheme.surface
                                            : Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow:
                                            isDark
                                                ? []
                                                : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.06),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                isDark
                                                    ? Colors.white.withOpacity(0.08)
                                                    : Colors.black.withOpacity(0.03),
                                          ),
                                        ),
                                        child: hasValidIcon
                                            ? SizedBox(
                                                width: 38,
                                                height: 38,
                                                child: AppNetworkImage(
                                                  imageUrl: currentIconUrl,
                                                  circular: false,
                                                  fit: BoxFit.contain,
                                                ),
                                              )
                                            : Icon(
                                                _getFallbackIcon(),
                                                color: AppColors.primaryGreen,
                                                size: 32,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.specialtyName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.6,
                                              height: 1.05,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _isLoading
                                                  ? "Searching..."
                                                  : "${_doctors.length} Verified ${_doctors.length == 1 ? 'Specialist' : 'Specialists'}",
                                              style: const TextStyle(
                                                color: AppColors.primaryGreen,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          top: safeArea,
                          left: 72,
                          right: 72,
                          height: kToolbarHeight - 8,
                          child: IgnorePointer(
                            ignoring: miniHeaderOpacity == 0.0,
                            child: Opacity(
                              opacity: miniHeaderOpacity,
                              child: Transform.translate(
                                offset: Offset(
                                        0,
                                        -2 - (10 * (1 - miniHeaderOpacity)),
                                      ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen.withOpacity(
                                          0.12,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: hasValidIcon
                                          ? SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: AppNetworkImage(
                                                imageUrl: currentIconUrl,
                                                circular: false,
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : Icon(
                                              _getFallbackIcon(),
                                              color: AppColors.primaryGreen,
                                              size: 16,
                                            ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          widget.specialtyName,
                                          style: TextStyle(
                                            color: isDark ? Colors.white : const Color(0xFF1D1D1F),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.3,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // THE FIX: Permanently fused to the glass! It will never detach on drag.
                        if (_isLoading && _doctors.isNotEmpty)
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              color: AppColors.primaryGreen,
                              minHeight: 2.0,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              if (_isLoading && !_hasEverLoaded && _doctors.isEmpty)
                const DoctorListSkeletonSliver(
                  padding: EdgeInsets.only(top: 20, bottom: 120),
                  itemPadding: EdgeInsets.only(left: 24, right: 24, bottom: 16),
                )
              else if (_doctors.isEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Text(
                        "No ${widget.specialtyName.toLowerCase()}${widget.specialtyName.endsWith('s') ? '' : 's'} found.",
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF86868B),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 20, bottom: 120),
                  sliver: SliverList(
                    // THE FIX: The Intent Hash!
                    key: ValueKey(
                      'specialty_${widget.specialtyId}_${_selectedFilter}_${_searchController.text}',
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doctor = _doctors[index];
                      final docId = int.tryParse(doctor['id'].toString()) ?? index;
                      final specialtyName =
                          doctor['specialties']?['name'] ??
                          widget.specialtyName;

                      return PremiumListAnimator(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: 16,
                          ),
                          child: DoctorListCard(
                            id: docId,
                            name: doctor['full_name'] ?? 'Unknown',
                            specialty: " $specialtyName",
                            rating: doctor['rating']?.toString() ?? '0.0',
                            views: (doctor['views_count'] ?? 0).toString(),
                            imageUrl: doctor['profile_picture_url'],
                            isFavorite: _favNotifier.isFavorite(docId),
                            heroTagPrefix: 'specialty-$docId-$index-',
                            onFavoriteTap: () {
                              _favNotifier.toggle(doctor);
                            },
                            onCardTap: () {
                              context.push(
                                AppRoutes.doctorDetailsById('$docId'),
                                extra: doctor,
                              );
                            },
                          ),
                        ),
                      );
                    }, childCount: _doctors.length),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
