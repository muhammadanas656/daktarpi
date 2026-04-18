import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/doctor_repository.dart';
import '../../presentation/favorites_notifier.dart';
import '../../../../core/widgets/app_loader.dart'; 
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../core/theme/app_styles.dart';

class MyDoctorsScreen extends StatefulWidget {
  const MyDoctorsScreen({super.key});

  @override
  State<MyDoctorsScreen> createState() => _MyDoctorsScreenState();
}

class _MyDoctorsScreenState extends State<MyDoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;

  late Future<List<Map<String, dynamic>>> _recentFuture;
  final Set<int> _pendingRemovalIds = {};

  @override
  void initState() {
    super.initState();
    // Ensures favorites are loaded into RAM if they haven't been yet
    if (!_favNotifier.isLoaded) {
      _favNotifier.loadFavorites();
    }
    _recentFuture = _doctorRepo.fetchRecentDoctors();
    _favNotifier.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    for (final id in _pendingRemovalIds) {
      // Actually delete them from DB if the user leaves the screen before Undo expires
      _favNotifier.toggle({'id': id});
    }
    _favNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  // PRO FIX: Pass the whole doctor object so it works perfectly offline!
  void _navigateToDoctorDetails(Map<String, dynamic> doctor) {
    final doctorId = doctor['id'];
    // When returning, refresh the recent list. Favorites updates instantly via Notifier.
    context.push(
      AppRoutes.doctorDetailsById('$doctorId'),
      extra: doctor, // <--- Passing the offline data!
    ).then((_) {
      if (mounted) {
        setState(() => _recentFuture = _doctorRepo.fetchRecentDoctors());
      }
    });
  }

  void _showUnlikeConfirmationDialog(
    BuildContext context,
    int doctorId,
    String doctorName,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Theme.of(context).colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: isDark ? 0.2 : 0.1),
                  width: 1.5,
                ),
                boxShadow: AppStyles.elevatedShadow(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.heart_broken_rounded,
                      color: Colors.redAccent,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Remove Favorite?",
                    style: AppTextStyles.h2(
                      context,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Are you sure you want to remove $doctorName from your favorites?",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      context,
                    ).copyWith(color: context.colorTextLight, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              color: context.colorTextLight,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppStyles.primaryShadow(
                              context,
                              Colors.redAccent,
                              alpha: isDark ? 0.4 : 0.35,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              // Needs full object for the new Notifier logic!
                              _favNotifier.toggle({'id': doctorId});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Remove",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _handleUnlikeWithUndo(
    int doctorId,
    String doctorName,
    int currentCount,
  ) {
    if (currentCount <= 1) {
      _showUnlikeConfirmationDialog(context, doctorId, doctorName);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _pendingRemovalIds.add(doctorId));
    ScaffoldMessenger.of(context).clearSnackBars();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  isDark
                      ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                      : BorderSide.none,
            ),
            backgroundColor:
                isDark ? const Color(0xFF1E293B) : const Color(0xFF2C3E50),
            elevation: 6,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(
                  Icons.auto_delete_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Removed $doctorName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: "UNDO",
              textColor: AppColors.primaryGreen,
              onPressed: () {
                HapticFeedback.lightImpact();
                if (mounted) {
                  setState(() => _pendingRemovalIds.remove(doctorId));
                }
              },
            ),
          ),
        )
        .closed
        .then((reason) {
          if (reason != SnackBarClosedReason.action &&
              _pendingRemovalIds.contains(doctorId)) {
            _favNotifier.toggle({'id': doctorId});
            if (mounted) setState(() => _pendingRemovalIds.remove(doctorId));
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: CustomAppBar(
          title: "My Doctors",
          onBackPressed: () => context.pop(),
          bottom: TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: context.colorTextGrey,
            labelStyle: AppTextStyles.bodyBold(context),
            indicatorColor: AppColors.primaryGreen,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: "Favorites"), Tab(text: "Recent Visits")],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
          child: TabBarView(
            children: [
              _buildFavoritesList(),
              _buildRecentList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesList() {
    final dynamicTopPadding = MediaQuery.paddingOf(context).top + 130.0;
    final loaderTopPadding = MediaQuery.paddingOf(context).top + 104.0;

    if (!_favNotifier.isLoaded) {
      return Stack(
        children: [
          Positioned(
            top: loaderTopPadding,
            left: 0,
            right: 0,
            child: const LinearProgressIndicator(
              color: AppColors.primaryGreen,
              backgroundColor: Colors.transparent,
              minHeight: 1.5,
            ),
          ),
        ],
      );
    }

    final doctors = _favNotifier.favoriteDoctors;

    if (doctors.isEmpty) {
      return Center(
        child: Text(
          'No favorites yet.',
          style: AppTextStyles.body(
            context,
          ).copyWith(color: context.colorTextGrey),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, dynamicTopPadding, 24, 24),
      itemCount: doctors.length,
      itemBuilder: (context, index) {
        final doctor = doctors[index];
        final docId = doctor['id'] as int;
        final isBeingRemoved = _pendingRemovalIds.contains(docId);

        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isBeingRemoved ? 0.0 : 1.0,
            child:
                isBeingRemoved
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DoctorListCard(
                        id: docId,
                        name: doctor['full_name'] ?? 'Unknown',
                        specialty:
                            doctor['specialties']?['name'] ?? 'Specialist',
                        rating: (doctor['rating'] as num?)?.toString() ?? '0.0',
                        views: (doctor['views_count'] ?? 0).toString(),
                        imageUrl: doctor['profile_picture_url'],
                        isFavorite: true,
                        onFavoriteTap:
                            () => _handleUnlikeWithUndo(
                              docId,
                              doctor['full_name'] ?? 'Unknown',
                              doctors.length,
                            ),
                        // PRO FIX: Navigating with the whole object
                        onCardTap: () => _navigateToDoctorDetails(doctor),
                      ),
                    ),
          ),
        );
      },
    );
  }

  Widget _buildRecentList() {
    final dynamicTopPadding = MediaQuery.paddingOf(context).top + 130.0;
    final loaderTopPadding = MediaQuery.paddingOf(context).top + 104.0;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Stack(
            children: [
              Positioned(
                top: loaderTopPadding,
                left: 0,
                right: 0,
                child: const LinearProgressIndicator(
                  color: AppColors.primaryGreen,
                  backgroundColor: Colors.transparent,
                  minHeight: 1.5,
                ),
              ),
            ],
          );
        }

        final doctors = snapshot.data ?? [];
        if (doctors.isEmpty) {
          return Center(
            child: Text(
              'No recent visits.',
              style: AppTextStyles.body(
                context,
              ).copyWith(color: context.colorTextGrey),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(24, dynamicTopPadding, 24, 24),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            final docId = doctor['id'] as int;

            final trailing = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Book",
                style: AppTextStyles.bodyBold(
                  context,
                ).copyWith(color: AppColors.primaryGreen, fontSize: 12),
              ),
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DoctorListCard(
                id: docId,
                name: doctor['full_name'] ?? 'Unknown',
                specialty: doctor['specialties']?['name'] ?? 'Specialist',
                rating: (doctor['rating'] as num?)?.toString() ?? '0.0',
                views: (doctor['views_count'] ?? 0).toString(),
                imageUrl: doctor['profile_picture_url'],
                isFavorite: _favNotifier.isFavorite(docId),
                onFavoriteTap: () => _favNotifier.toggle(doctor),
                // PRO FIX: Navigating with the whole object
                onCardTap: () => _navigateToDoctorDetails(doctor),
                trailingWidget: trailing,
              ),
            );
          },
        );
      },
    );
  }
}
