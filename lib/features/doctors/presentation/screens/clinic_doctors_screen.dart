import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/doctor_repository.dart';
import '../../presentation/favorites_notifier.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../../../../core/widgets/app_loader.dart';

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

class _ClinicDoctorsScreenState extends State<ClinicDoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _doctorsFuture;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchDoctors();
    _searchController.addListener(_onSearchChanged);
    _favNotifier.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _favNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchDoctors();
    });
  }

  void _fetchDoctors() {
    setState(() {
      _doctorsFuture = _doctorRepo.fetchDoctorsByClinic(
        widget.clinicId,
        query: _searchController.text.trim(),
      );
    });
  }

  Widget _buildClinicInfoCard(int doctorCount, bool isLoading) {
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
            tag: 'clinic_logo_${widget.clinicId}',
            child: Container(
              width: 64, height: 64, 
              decoration: BoxDecoration(color: AppColors.primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: widget.logoUrl != null && widget.logoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.logoUrl!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      placeholder: (context, url) => const Icon(Icons.domain_rounded, color: AppColors.primaryGreen, size: 32),
                      errorWidget: (context, url, error) => const Icon(Icons.domain_rounded, color: AppColors.primaryGreen, size: 32),
                    )
                  : const Center(child: Icon(Icons.domain_rounded, color: AppColors.primaryGreen, size: 32)),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.clinicName,
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
                        isLoading ? "Searching roster..." : "$doctorCount Professional${doctorCount == 1 ? '' : 's'}",
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _doctorsFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final doctors = snapshot.data ?? [];

          return CustomScrollView(
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
                // 📌 POLISH: Symmetrical action button
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
                          bottom: 40 * expandRatio, // 📌 Deep overlap
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
                                // 📌 POLISH: Background Watermark
                                Positioned(
                                  right: -30,
                                  top: safeArea - 20,
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: Icon(
                                      Icons.local_hospital_rounded,
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
                          left: 0, right: 0, bottom: 0, // 📌 Absolute bottom for straddle
                          child: IgnorePointer(
                            ignoring: cardOpacity == 0.0,
                            child: Opacity(
                              opacity: cardOpacity,
                              child: Transform.scale(
                                scale: 0.95 + (0.05 * expandRatio),
                                child: SafeArea(
                                  bottom: false,
                                  child: _buildClinicInfoCard(doctors.length, isLoading),
                                ),
                              ),
                            ),
                          ),
                        ),

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
                                            "OFFICIAL FACILITY",
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
                                            clipBehavior: Clip.antiAlias,
                                            padding: EdgeInsets.all(widget.logoUrl == null || widget.logoUrl!.isEmpty ? 6 : 0),
                                            child: widget.logoUrl != null && widget.logoUrl!.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: widget.logoUrl!,
                                                    fit: BoxFit.cover,
                                                    filterQuality: FilterQuality.high,
                                                    errorWidget: (context, url, error) => const Icon(Icons.domain_rounded, color: Colors.white, size: 16),
                                                  )
                                                : const Icon(Icons.domain_rounded, color: Colors.white, size: 16),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              widget.clinicName,
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
                      hintText: "Search doctors...",
                      showClearIcon: _searchController.text.isNotEmpty,
                      onClear: () {
                        HapticFeedback.lightImpact();
                        _searchController.clear();
                        _fetchDoctors();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ),
                ),
              ),

              if (isLoading)
                const SliverFillRemaining(child: Center(child: AppLoader(color: AppColors.primaryGreen)))
              else if (doctors.isEmpty)
                 SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text("No doctors found.", style: AppTextStyles.h3(context))),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doctor = doctors[index]; 
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
                              heroTagPrefix: 'clinic-',
                            ),
                          ),
                        );
                      },
                      childCount: doctors.length,
                    ),
                  ),
                ),
              if (!isLoading && doctors.isNotEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: const SizedBox(
                    height: 250,
                  ),
                ),
            ],
          );
        },
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
          rating: (widget.doctor['rating'] as num?)?.toString() ?? '0.0',
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
