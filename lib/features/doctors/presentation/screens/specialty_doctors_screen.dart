import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../favorites_notifier.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../data/doctor_repository.dart';
import '../../../../core/widgets/app_loader.dart';
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

class _SpecialtyDoctorsScreenState extends State<SpecialtyDoctorsScreen> {
  final _searchController = TextEditingController();
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  Timer? _debounce;

  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String? _specialtyIconUrl;

  @override
  void initState() {
    super.initState();
    _specialtyIconUrl = widget.specialtyIconUrl;
    _favNotifier.addListener(_onStateChanged);
    _profileNotifier.addListener(_onStateChanged);
    
    _fetchData();
    if (_specialtyIconUrl == null) {
      _fetchSpecialtyIcon();
    }
    _searchController.addListener(_onSearchChanged);
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
    if (_debounce?.isActive ?? false) _debounce!.cancel();
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

  Future<void> _fetchData({String? query}) async {
    if (!_favNotifier.isLoaded) await _favNotifier.loadFavorites();
    try {
      final countryIso = _profileNotifier.profile?.countryIso;
      final doctors = await _doctorRepo.fetchDoctorsBySpecialty(
        widget.specialtyId,
        query: query,
        countryIso: countryIso,
      );
      if (mounted) {
        setState(() {
          _doctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getFallbackIcon() {
    final lowerName = widget.specialtyName.toLowerCase();
    if (lowerName.contains('dentist')) return Icons.masks_rounded;
    if (lowerName.contains('cardio')) return Icons.favorite_rounded;
    if (lowerName.contains('eye')) return Icons.remove_red_eye_rounded;
    return Icons.medical_services_rounded;
  }

  Widget _buildSpecialtyInfoCard(int doctorCount, bool isLoading) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20), 
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 32,
            spreadRadius: 4,
            offset: const Offset(0, 12), 
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'specialty_icon_${widget.specialtyId}',
            child: Container(
              padding: _specialtyIconUrl != null && _specialtyIconUrl!.isNotEmpty ? const EdgeInsets.all(12) : const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: _specialtyIconUrl != null && _specialtyIconUrl!.isNotEmpty
                  ? SizedBox(
                      width: 36, height: 36,
                      child: AppNetworkImage(imageUrl: _specialtyIconUrl!, circular: false, fit: BoxFit.contain),
                    )
                  : Icon(_getFallbackIcon(), color: AppColors.primaryGreen, size: 32),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.specialtyName,
                  style: AppTextStyles.h2(context).copyWith(fontSize: 22, letterSpacing: -0.4, height: 1.2),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(isLoading ? Icons.hourglass_empty_rounded : Icons.people_alt_rounded, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isLoading ? "Searching roster..." : "$doctorCount ${widget.specialtyName}${doctorCount == 1 ? '' : 's'}",
                        style: const TextStyle(color: AppColors.primaryGreen, fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: 200, // 📌 POLISH: Reduced to 200px to kill all vacancy
            elevation: 0,
            backgroundColor: Colors.transparent,
            leadingWidth: 64,
            leading: Center(
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pop();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
            // 📌 POLISH: Added symmetrical action button to frame the top layout
            actions: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 24),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
                    onPressed: () => HapticFeedback.lightImpact(),
                  ),
                ),
              ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final top = constraints.biggest.height;
                final safeArea = MediaQuery.of(context).padding.top;
                final collapsedHeight = safeArea + kToolbarHeight;
                const expandedHeight = 200.0;

                final expandRatio = (expandedHeight - collapsedHeight) > 0 
                    ? ((top - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0)
                    : 1.0;
                
                final collapseRatio = 1.0 - expandRatio;

                final cardOpacity = ((expandRatio - 0.3) / 0.7).clamp(0.0, 1.0);
                final miniHeaderOpacity = ((collapseRatio - 0.4) / 0.6).clamp(0.0, 1.0);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -500, left: 0, right: 0, 
                      bottom: 40 * expandRatio, // 📌 Card deeply overlaps the curve
                      child: ClipPath(
                        clipper: ShapeBorderClipper(
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(80 * expandRatio),
                              bottomRight: Radius.circular(80 * expandRatio),
                            ),
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? [AppColors.primaryGreen.withValues(alpha: 0.8), AppColors.primaryGreen.withValues(alpha: 0.3)]
                                      : [AppColors.primaryGreen, const Color(0xFF00A884)], 
                                ),
                              ),
                            ),
                            // 📌 POLISH: The massive, subtle background watermark
                            Positioned(
                              right: -30,
                              top: safeArea - 20,
                              child: Transform.rotate(
                                angle: -0.2,
                                child: Icon(
                                  _getFallbackIcon(),
                                  size: 220,
                                  color: Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0, right: 0, bottom: 0, // 📌 Lifted to absolute bottom 0 
                      child: IgnorePointer(
                        ignoring: cardOpacity == 0.0,
                        child: Opacity(
                          opacity: cardOpacity,
                          child: Transform.scale(
                            scale: 0.95 + (0.05 * expandRatio),
                            child: SafeArea(
                              bottom: false,
                              child: _buildSpecialtyInfoCard(_doctors.length, _isLoading),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 📌 POLISH: The "Eyebrow Morph" (Fades out, Mini-Header fades in)
                    Positioned(
                      top: safeArea,
                      left: 64, right: 64,
                      height: kToolbarHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. The Expanded "Eyebrow" Pill
                          IgnorePointer(
                            ignoring: cardOpacity == 0.0,
                            child: Opacity(
                              opacity: cardOpacity,
                              child: Transform.translate(
                                offset: Offset(0, -10 * (1 - cardOpacity)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        "VERIFIED SPECIALISTS",
                                        style: AppTextStyles.bodySmall(context).copyWith(
                                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 2. The Collapsed Mini-Header
                          IgnorePointer(
                            ignoring: miniHeaderOpacity == 0.0,
                            child: Transform.translate(
                              offset: Offset(0, 15 * (1 - miniHeaderOpacity)), 
                              child: Opacity(
                                opacity: miniHeaderOpacity,
                                child: Transform.scale(
                                  scale: 0.9 + (0.1 * miniHeaderOpacity), 
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.15), 
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: _specialtyIconUrl != null && _specialtyIconUrl!.isNotEmpty
                                            ? AppNetworkImage(imageUrl: _specialtyIconUrl!, circular: true, fit: BoxFit.cover)
                                            : Icon(_getFallbackIcon(), color: Colors.white, size: 16),
                                      ),
                                      const SizedBox(width: 10),
                                      Flexible(
                                        child: Text(
                                          widget.specialtyName,
                                          style: AppTextStyles.h3(context).copyWith(color: Colors.white, fontSize: 18, letterSpacing: 0.3),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SliverPersistentHeader(
            pinned: true, 
            delegate: _DynamicGlassShelfDelegate(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: CustomSearchBar(
                  controller: _searchController,
                  hintText: "Search ${widget.specialtyName}s...",
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

          if (_isLoading)
            const SliverFillRemaining(child: Center(child: AppLoader(color: AppColors.primaryGreen)))
          else if (_doctors.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text("No ${widget.specialtyName.toLowerCase()}s found.", style: AppTextStyles.h3(context))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final doctor = _doctors[index];
                    final docId = doctor['id'] as int;
                    final specialtyName = doctor['specialties']?['name'] ?? 'Specialist';
                    
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(docId), 
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index.clamp(0, 8) * 40)), 
                      curve: Curves.easeOutQuart,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)), 
                          child: Opacity(opacity: value, child: child),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SquishableDoctorCard(
                          doctor: doctor,
                          docId: docId,
                          specialtyName: specialtyName,
                          favNotifier: _favNotifier,
                          heroTagPrefix: 'specialty-',
                        ),
                      ),
                    );
                  },
                  childCount: _doctors.length,
                ),
              ),
            ),
          if (!_isLoading && _doctors.isNotEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: const SizedBox(
                height: 250,
              ),
            ),
        ],
      ),
    );
  }
}

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
          specialty: " ${widget.specialtyName}",
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
            context.push(AppRoutes.doctorDetailsById('${widget.docId}'), extra: widget.doctor);
          }, 
        ),
      ),
    );
  }
}

class _DynamicGlassShelfDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _DynamicGlassShelfDelegate({required this.child});
  
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isPinned = shrinkOffset > 0 || overlapsContent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isPinned 
            ? Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85)
            : Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.0),
        boxShadow: isPinned
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: isPinned ? 16.0 : 0.0, 
            sigmaY: isPinned ? 16.0 : 0.0,
          ),
          child: child,
        ),
      ),
    );
  }
  
  @override
  double get maxExtent => 88.0; 
  @override
  double get minExtent => 88.0;
  @override
  bool shouldRebuild(covariant _DynamicGlassShelfDelegate oldDelegate) => oldDelegate.child != child;
}
