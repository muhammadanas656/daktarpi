import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../favorites_notifier.dart';
import '../doctors_notifier.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../data/doctor_repository.dart';
import '../../../../presentation/widgets/app_network_image.dart';

class ClinicDoctorsScreen extends StatefulWidget {
  final int clinicId;
  final String clinicName;
  final String? logoUrl;

  const ClinicDoctorsScreen({
    super.key,
    required this.clinicId,
    required this.clinicName,
    this.logoUrl,
  });

  @override
  State<ClinicDoctorsScreen> createState() => _ClinicDoctorsScreenState();
}

class _ClinicDoctorsScreenState extends State<ClinicDoctorsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  Timer? _debounce;

  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String? _clinicLogoUrl;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _clinicLogoUrl = widget.logoUrl;
    _favNotifier.addListener(_onStateChanged);
    if (_clinicLogoUrl == null) _fetchClinicMedia();
    _searchController.addListener(_onSearchChanged);

    // THE FIX: Because the SmartFilterBar is silent on this specific screen,
    // we MUST manually trigger the initial data fetch here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchData(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _favNotifier.removeListener(_onStateChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
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

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchData(query: _searchController.text);
    });
  }

  Future<void> _fetchClinicMedia() async {
    try {
      final response = await Supabase.instance.client
          .from('clinics')
          .select('logo_url, image_url')
          .eq('id', widget.clinicId)
          .maybeSingle();
      if (response != null && mounted) {
        final logoUrl = response['logo_url']?.toString().trim();
        final imageUrl = response['image_url']?.toString().trim();
        
        // ─── INTERCHANGEABLE IMAGE MATRIX ───
        final String? resolvedPrimary = (logoUrl != null && logoUrl.isNotEmpty) ? logoUrl : ((imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null);
        
        setState(() {
          _clinicLogoUrl = resolvedPrimary;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch clinic logo: $e');
    }
  }

  Future<void> _fetchData({String? query, bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoading = true);
    if (!_favNotifier.isLoaded) await _favNotifier.loadFavorites();
    try {
      double? userLat;
      double? userLng;

      // Only fetch GPS for filters that actually need it
      if (_selectedFilter == 'Nearest' ||
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

      final doctors = await _doctorRepo.fetchDoctorsByClinic(
        widget.clinicId,
        query: query,
        filterType: _selectedFilter,
        userLat: userLat,
        userLng: userLng,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _doctors = _applySortOverlay(doctors, _selectedFilter);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Clinic fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLogo = _clinicLogoUrl != null && _clinicLogoUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background ambient glow
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
                expandedHeight: 228.0,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leadingWidth: 72,
                leading: Container(
                  padding: const EdgeInsets.only(left: 24),
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: isDark
                        ? Colors.white12
                        : Colors.black.withOpacity(0.05),
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(72.0),
                  child: Container(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: CustomSearchBar(
                        controller: _searchController,
                        hintText: 'Search ${widget.clinicName} roster...',
                        showClearIcon: _searchController.text.isNotEmpty,
                        onClear: () {
                          HapticFeedback.lightImpact();
                          _searchController.clear();
                          _fetchData();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                  ),
                ),
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
                    child: Container(
                      decoration: BoxDecoration(
                        // Permanent glass so the ambient gradient can keep showing through.
                        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.70),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.05),
                            width: 1,
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final top = constraints.biggest.height;
                          final safeArea = MediaQuery.of(context).padding.top;
                          final collapsedHeight = safeArea + kToolbarHeight + 72.0;
                          final expandRatio =
                              ((top - collapsedHeight) / 100.0).clamp(0.0, 1.0);
                          final collapseRatio = 1.0 - expandRatio;

                          final largeHeaderOpacity =
                              ((expandRatio - 0.3) / 0.7).clamp(0.0, 1.0);
                          final miniHeaderOpacity =
                              ((collapseRatio - 0.5) / 0.5).clamp(0.0, 1.0);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned(
                                left: 24,
                                right: 24,
                                bottom: 114.0,
                                child: IgnorePointer(
                                  ignoring: largeHeaderOpacity == 0.0,
                                  child: Opacity(
                                    opacity: largeHeaderOpacity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        10 * (3.4 - largeHeaderOpacity),
                                      ),
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
                                              boxShadow: isDark
                                                  ? []
                                                  : [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.06),
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
                                                  color: isDark
                                                      ? Colors.white.withOpacity(0.08)
                                                      : Colors.black.withOpacity(0.03),
                                                ),
                                              ),
                                              child: hasLogo
                                                  ? SizedBox(
                                                      width: 72,
                                                      height: 72,
                                                      child: ClipOval(
                                                        child: AppNetworkImage(
                                                          imageUrl: _clinicLogoUrl,
                                                          circular: false,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.domain_rounded,
                                                      color: AppColors.primaryGreen,
                                                      size: 32,
                                                    ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  widget.clinicName,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : const Color(0xFF1D1D1F),
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.6,
                                                    height: 1.05,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryGreen.withOpacity(
                                                      0.12,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    _isLoading
                                                        ? 'Searching...'
                                                        : '${_doctors.length} Specialist${_doctors.length == 1 ? '' : 's'}',
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
                                height: kToolbarHeight - 1,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            alignment: Alignment.center,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen.withOpacity(
                                                0.12,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: hasLogo
                                                ? AppNetworkImage(
                                                    imageUrl: _clinicLogoUrl,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    circular: false,
                                                    fit: BoxFit.cover,
                                                  )
                                                : const Icon(
                                                    Icons.domain_rounded,
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
                                                widget.clinicName,
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1D1D1F),
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
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              if (_isLoading && _doctors.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
                )
              else if (_doctors.isEmpty && !_isLoading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 300,
                    child: Center(
                      child: Text(
                        'No doctors found in this facility.',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF86868B),
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
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doctor = _doctors[index];
                      final docId =
                          int.tryParse(doctor['id'].toString()) ?? index;
                      final specialtyName =
                          doctor['specialties']?['name'] ?? 'Specialist';

                      return Padding(
                        padding: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          bottom: 16,
                        ),
                        child: _SquishableDoctorCard(
                          doctor: doctor,
                          docId: docId,
                          specialtyName: specialtyName,
                          favNotifier: _favNotifier,
                          heroTagPrefix: 'clinic-$docId-$index-',
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

// ─── Squishable Card (identical pattern to Specialty screen) ──────────────────

class _SquishableDoctorCard extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final int docId;
  final String specialtyName;
  final FavoritesNotifier favNotifier;
  final String heroTagPrefix;

  const _SquishableDoctorCard({
    required this.doctor,
    required this.docId,
    required this.specialtyName,
    required this.favNotifier,
    required this.heroTagPrefix,
  });

  @override
  State<_SquishableDoctorCard> createState() => _SquishableDoctorCardState();
}

class _SquishableDoctorCardState extends State<_SquishableDoctorCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) => setState(() => _isPressed = false),
      onPointerCancel: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: DoctorListCard(
          id: widget.docId,
          name: widget.doctor['full_name'] ?? 'Unknown',
          specialty: ' ${widget.specialtyName}',
          rating: widget.doctor['rating']?.toString() ?? '0.0',
          views: (widget.doctor['views_count'] ?? 0).toString(),
          imageUrl: widget.doctor['profile_picture_url'],
          isFavorite: widget.favNotifier.isFavorite(widget.docId),
          heroTagPrefix: widget.heroTagPrefix,
          onFavoriteTap: () {
            HapticFeedback.selectionClick();
            widget.favNotifier.toggle(widget.doctor);
          },
          onCardTap: () {
            HapticFeedback.lightImpact();
            context.push(
              AppRoutes.doctorDetailsById('${widget.docId}'),
              extra: widget.doctor,
            );
          },
        ),
      ),
    );
  }
}

// ─── Glass Capsule Delegate (identical to Specialty screen) ───────────────────
