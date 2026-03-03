import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/doctor_repository.dart';
import '../../presentation/favorites_notifier.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';

class MyDoctorsScreen extends StatefulWidget {
  const MyDoctorsScreen({super.key});

  @override
  State<MyDoctorsScreen> createState() => _MyDoctorsScreenState();
}

class _MyDoctorsScreenState extends State<MyDoctorsScreen> {
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;

  // Futures for data
  late Future<List<Map<String, dynamic>>> _favoritesFuture;
  late Future<List<Map<String, dynamic>>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _favNotifier.addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    _favNotifier.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    // Reload favorites when the notifier changes (e.g. un-favoriting from another screen)
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
        .then((_) => _refreshData()); // Refresh on return in case of changes
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        appBar: AppBar(
          title: Text("My Doctors", style: AppTextStyles.h2),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: AppColors.textDark,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          bottom: TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: AppColors.textGrey,
            labelStyle: AppTextStyles.bodyBold,
            indicatorColor: AppColors.primaryGreen,
            tabs: const [Tab(text: "Favorites"), Tab(text: "Recent Visits")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDoctorList(_favoritesFuture, isFavoritesTab: true),
            _buildDoctorList(_recentFuture, isFavoritesTab: false),
          ],
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
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading doctors',
              style: AppTextStyles.body.copyWith(color: AppColors.dangerRed),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              isFavoritesTab ? 'No favorite doctors yet.' : 'No recent visits.',
              style: AppTextStyles.body.copyWith(color: AppColors.textGrey),
            ),
          );
        }

        final doctors = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: doctors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final doctor = doctors[index];
            final docId = doctor['id'] as int;
            final specialtyName =
                doctor['specialties'] != null
                    ? doctor['specialties']['name']
                    : 'Specialist';

            // For favorites tab, we want to show the heart (filled).
            // For recent tab, we might show a "Book Again" or just the card.
            // The prompt says:
            // Favorites: Show solid red heart. Tapping it removes.
            // Recent: Show "Book Again" or arrow.

            // DoctorListCard expects 'isFavorite' and 'onFavoriteTap'.
            // We can customize the icon if needed, but DoctorListCard might not support changing the icon logic yet.
            // Let's check DoctorListCard.
            // It has `isFavorite` bool.
            // If isFavoritesTab is true, isFavorite is true.
            // If isFavoritesTab is false, we might want to hide the heart or show something else.
            // But DoctorListCard currently just shows a heart.
            // The prompt says "Reuse the doctor card design you already have, but with small tweaks for context".
            // I should probably pass `showFavoriteIcon` or similar if I can modify DoctorListCard,
            // OR just use the existing logic where Recent tab doesn't show it as favorite unless it IS a favorite.

            // Re-reading prompt: "Recent Visits Tab: Icon: Instead of a heart, show a "Book Again" button or a simple arrow icon"
            // This implies I need to modify DoctorListCard to support a custom action/icon.

            // For now I will use the existing card.
            // Favorites tab: Always isFavorite=true.
            // Recent tab: Check actual favorite status.

            // WAIT, prompt says: "Recent Visits Tab ... Icon: Instead of a heart, show a "Book Again" button ... as favorites logic doesn't apply here."
            // I should modify DoctorListCard to allow hiding the heart or replacing it.
            // But currently I'm creating the screen. I will assume I can modify DoctorListCard later or use what I have.
            // Let's stick to standard behavior for now to avoid breaking changes in the card file unless I see it.
            // Actually, I can use the existing `isFavorite` for the Favorites tab (it will be true).
            // For Recent tab, I'll just check `_favNotifier.isFavorite(docId)`.
            // The prompt asks for specific UI changes ("Book Again" icon).
            // Only way to do that is to add a parameter to DoctorListCard.

            final isFavorite =
                isFavoritesTab ? true : _favNotifier.isFavorite(docId);

            Widget? trailing;
            if (!isFavoritesTab) {
              // Recent Visits: Show "Book Again" (arrow or simple button)
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
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primaryGreen,
                    fontSize: 12,
                  ),
                ),
              );
            }

            return DoctorListCard(
              id: docId,
              name: doctor['full_name'] ?? 'Unknown',
              specialty: specialtyName,
              rating: (doctor['rating'] as num?)?.toString() ?? '0.0',
              views: (doctor['views_count'] ?? 0).toString(),
              imageUrl: doctor['profile_picture_url'],
              isFavorite: isFavorite,
              onFavoriteTap: () {
                if (isFavoritesTab) {
                  _favNotifier.toggle(docId);
                  // setState happens via listener
                } else {
                  _favNotifier.toggle(docId);
                }
              },
              onCardTap: () => _navigateToDoctorDetails(docId),
              trailingWidget: trailing,
            );
          },
        );
      },
    );
  }
}
