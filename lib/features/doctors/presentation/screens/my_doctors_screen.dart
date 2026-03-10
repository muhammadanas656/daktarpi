import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/doctor_repository.dart';
import '../../presentation/favorites_notifier.dart';
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

  late Future<List<Map<String, dynamic>>> _favoritesFuture;
  late Future<List<Map<String, dynamic>>> _recentFuture;

  final Set<int> _pendingRemovalIds = {};

  @override
  void initState() {
    super.initState();
    _refreshData();
    _favNotifier.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    for (final id in _pendingRemovalIds) {
      _favNotifier.toggle(id);
    }
    _favNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) {
      setState(() {
        _favoritesFuture = _doctorRepo.fetchFavoriteDoctors();
      });
    }
  }

  void _refreshData() {
    setState(() {
      _favoritesFuture = _doctorRepo.fetchFavoriteDoctors();
      _recentFuture = _doctorRepo.fetchRecentDoctors();
    });
  }

  void _navigateToDoctorDetails(int doctorId) {
    context
        .push(AppRoutes.doctorDetailsById('$doctorId'))
        .then((_) => _refreshData());
  }

  // --- PRO FIX: Perfectly Consistent Dark/Light Mode Confirmation Dialog ---
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
              padding: const EdgeInsets.all(28), // Slightly more breathing room
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                // PRO FIX: Dynamic border matching ComplaintDialog
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
                    "Are you sure you want to remove Dr. $doctorName from your favorites?",
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
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
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
                            // PRO FIX: Dynamic shadow intensity
                            boxShadow: AppStyles.primaryShadow(
                              context,
                              Colors.redAccent,
                              alpha: isDark ? 0.4 : 0.35,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _favNotifier.toggle(doctorId);
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

  // --- PRO FIX: Adaptive SnackBar ---
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
              // PRO FIX: Add a subtle border in dark mode to separate it from dark backgrounds
              side:
                  isDark
                      ? BorderSide(color: Colors.white.withValues(alpha: 0.1))
                      : BorderSide.none,
            ),
            // PRO FIX: Dynamic premium colors for Light/Dark
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
                    "Removed Dr. $doctorName",
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
            _favNotifier.toggle(doctorId);
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
        appBar: AppBar(
          title: Text("My Doctors", style: AppTextStyles.h2(context)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: context.colorTextDark,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: context.colorTextGrey,
            labelStyle: AppTextStyles.bodyBold(context),
            indicatorColor: AppColors.primaryGreen,
            dividerColor:
                Colors
                    .transparent, // PRO FIX: Removes the default harsh line under the tabs
            tabs: const [Tab(text: "Favorites"), Tab(text: "Recent Visits")],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
          child: SafeArea(
            child: TabBarView(
              children: [
                _buildDoctorList(_favoritesFuture, isFavoritesTab: true),
                _buildDoctorList(_recentFuture, isFavoritesTab: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorList(
    Future<List<Map<String, dynamic>>> future, {
    required bool isFavoritesTab,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryGreen),
          );
        }

        var doctors = snapshot.data ?? [];
        if (isFavoritesTab) {
          doctors =
              doctors
                  .where((doc) => _favNotifier.isFavorite(doc['id'] as int))
                  .toList();
        }

        if (doctors.isEmpty) {
          return Center(
            child: Text(
              isFavoritesTab ? 'No favorites yet.' : 'No recent visits.',
              style: AppTextStyles.body(
                context,
              ).copyWith(color: context.colorTextGrey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: doctors.length,
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            final docId = doctor['id'] as int;
            final isBeingRemoved =
                isFavoritesTab && _pendingRemovalIds.contains(docId);

            Widget? trailing;
            if (!isFavoritesTab) {
              trailing = Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
            }

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
                            rating:
                                (doctor['rating'] as num?)?.toString() ?? '0.0',
                            views: (doctor['views_count'] ?? 0).toString(),
                            imageUrl: doctor['profile_picture_url'],
                            isFavorite:
                                isFavoritesTab
                                    ? true
                                    : _favNotifier.isFavorite(docId),
                            onFavoriteTap: () {
                              if (isFavoritesTab) {
                                _handleUnlikeWithUndo(
                                  docId,
                                  doctor['full_name'] ?? 'Unknown',
                                  doctors.length,
                                );
                              } else {
                                _favNotifier.toggle(docId);
                              }
                            },
                            onCardTap: () => _navigateToDoctorDetails(docId),
                            trailingWidget: trailing,
                          ),
                        ),
              ),
            );
          },
        );
      },
    );
  }
}
