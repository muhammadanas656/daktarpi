import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../favorites_notifier.dart';
import '../../../profile/presentation/profile_notifier.dart';
import '../../data/doctor_repository.dart';
import '../../../../presentation/widgets/doctor_list_card.dart';
import '../../../../presentation/widgets/custom_search_bar.dart';
import '../models/doctors_route_args.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  final _doctorRepo = DoctorRepository();
  final _favNotifier = FavoritesNotifier.instance;
  final _profileNotifier = ProfileNotifier.instance;
  Timer? _debounce;

  // Data State
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _specialties = [];
  List<String> _recentSearches = [];

  // NEW: Hint States
  Map<String, List<Map<String, dynamic>>> _allHints = {
    'specialties': [],
    'doctors': [],
    'clinics': [],
  };
  bool _isShowingHints = false;

  bool _isLoading = false;
  bool _showClearIcon = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadSpecialties();
    _favNotifier.addListener(_onStateChanged);
    _profileNotifier.addListener(_onStateChanged);

    _searchController.addListener(() {
      setState(() {
        _showClearIcon = _searchController.text.isNotEmpty;
      });
      _onSearchChanged();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _favNotifier.removeListener(_onStateChanged);
    _profileNotifier.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final searches = prefs.getStringList('recent_searches') ?? [];

    searches.remove(query);
    searches.insert(0, query);

    if (searches.length > 5) {
      searches.removeLast();
    }

    await prefs.setStringList('recent_searches', searches);
    if (mounted) {
      setState(() => _recentSearches = searches);
    }
  }

  Future<void> _loadSpecialties() async {
    try {
      _specialties = await _doctorRepo.fetchSpecialties(limit: 50);
    } catch (_) {}
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final query = _searchController.text.trim();

    // NEW: Character Threshold & Focus Guard
    // This prevents the search from "activating" on a simple click
    // or when the text is too short to be useful.
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _doctors = [];
          _allHints = {'specialties': [], 'doctors': [], 'clinics': []};
          _hasSearched = false;
          _isLoading = false;
          _isShowingHints = false; // Hide hints if they just clicked/cleared
        });
      }
      return;
    }

    // 1. Instant Specialty Hints (Local)
    final localSpecs =
        _specialties
            .where((s) {
              return (s['name'] as String).toLowerCase().contains(
                query.toLowerCase(),
              );
            })
            .take(2)
            .toList();

    setState(() {
      _isShowingHints = true;
      _allHints = {'specialties': localSpecs, 'doctors': [], 'clinics': []};
    });

    _debounce = Timer(Duration(milliseconds: 300), () async {
      final remoteHints = await _doctorRepo.fetchSearchHints(query: query);

      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _allHints = {
            'specialties': localSpecs,
            'doctors': List<Map<String, dynamic>>.from(
              remoteHints['doctors'] ?? [],
            ),
            'clinics': List<Map<String, dynamic>>.from(
              remoteHints['clinics'] ?? [],
            ),
          };
        });
      }
    });
  }

  void _onSearchSubmitted(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    // NEW: Force the keyboard to close BEFORE processing navigation
    FocusScope.of(context).unfocus();

    // Lock in the search, hide the hints
    setState(() {
      _isShowingHints = false;
    });

    // 1. Save to history immediately
    await _saveRecentSearch(trimmedQuery);

    // 2. Strict check for Specialty Redirect
    final lowerQuery = trimmedQuery.toLowerCase();
    for (var spec in _specialties) {
      if ((spec['name'] as String).toLowerCase() == lowerQuery) {
        if (mounted) {
          context.push(
            AppRoutes.specialtyDoctorsById('${spec['id']}'),
            extra: SpecialtyRouteArgs(name: spec['name']),
          );
        }
        return;
      }
    }

    // 3. Perform the full, heavy search
    _performSearch(trimmedQuery);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasSearched = true;
      });
    }

    try {
      final countryIso = _profileNotifier.profile?.countryIso;
      final userLocation = _profileNotifier.profile?.location;

      final doctors = await _doctorRepo.fetchGlobalSearch(
        query: query,
        userLocation: userLocation,
        countryIso: countryIso,
      );

      if (!_favNotifier.isLoaded) {
        await _favNotifier.loadFavorites();
      }

      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _doctors = doctors;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
  }

  void _handleHintTap(String query, {bool submit = true}) {
    _searchController.text = query;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    if (submit) {
      _onSearchSubmitted(query);
      FocusScope.of(context).unfocus();
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.h2(context).copyWith(
          fontSize: 12,
          color: context.colorTextLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHintTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryGreen, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.body(
          context,
        ).copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: context.colorTextLight),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: context.colorTextLight,
      ),
      onTap: onTap,
    );
  }

  void _handleSpecialtyTap(Map<String, dynamic> spec) {
    FocusScope.of(context).unfocus(); // Force close keyboard
    _saveRecentSearch(spec['name']); // Cache it for next time
    context.push(
      AppRoutes.specialtyDoctorsById('${spec['id']}'),
      extra: SpecialtyRouteArgs(name: spec['name']),
    );
  }

  void _handleDoctorTap(Map<String, dynamic> doc) {
    FocusScope.of(context).unfocus(); // Force close keyboard
    _saveRecentSearch(doc['full_name']);
    context.push(AppRoutes.doctorDetailsById('${doc['id']}'), extra: doc);
  }

  void _handleClinicTap(Map<String, dynamic> clinic) {
    FocusScope.of(context).unfocus(); // Force close keyboard
    _saveRecentSearch(clinic['name']);
    context.push(AppRoutes.clinicDoctorsById('${clinic['id']}'));
  }

  @override
  Widget build(BuildContext context) {
    // A query is "active" only if it meets our 2-character requirement
    final queryText = _searchController.text.trim();
    final isQueryLongEnough = queryText.length >= 2;

    // Show recent searches if the box is empty OR if they just started typing (1 char)
    final showRecentSearches = !isQueryLongEnough && _recentSearches.isNotEmpty;

    return Scaffold(
      backgroundColor: context.colorScaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color:
                    Theme.of(
                      context,
                    ).colorScheme.surface, // Removed Colors.white
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
                boxShadow: AppStyles.cardShadow(context), // Added context
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: context.colorTextDark,
              ),
            ),
          ),
        ),
        title: Text(
          "Global Search",
          style: AppTextStyles.h1(context).copyWith(fontSize: 22),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppStyles.pageGradient(context),
        ), // Added context
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: CustomSearchBar(
                controller: _searchController,
                hintText: "Search doctors, specialties, clinics...",
                showClearIcon: _showClearIcon,
                onClear: _clearSearch,
                onSubmitted: _onSearchSubmitted,
              ),
            ),

            // 1. Default State: Recent Searches
            if (showRecentSearches) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      color: context.colorTextLight,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Recent Searches",
                      style: AppTextStyles.h2(context).copyWith(fontSize: 16),
                    ),
                  ],
                ),
              ),
              ..._recentSearches.map(
                (query) => ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 48),
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    query,
                    style: TextStyle(color: context.colorTextDark),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: context.colorTextLight,
                  ),
                  onTap: () => _handleHintTap(query),
                ),
              ),
              Spacer(),
            ]
            // 2. Progressive Typing State: Live Hints
            else if (_isShowingHints)
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    if (_allHints['specialties']!.isNotEmpty)
                      _buildSectionHeader("Specialties"),
                    ..._allHints['specialties']!.map(
                      (s) => _buildHintTile(
                        s['name'],
                        "Specialty",
                        Icons.category,
                        () => _handleSpecialtyTap(s),
                      ),
                    ),

                    if (_allHints['doctors']!.isNotEmpty)
                      _buildSectionHeader("Doctors"),
                    ..._allHints['doctors']!.map(
                      (d) => _buildHintTile(
                        d['full_name'],
                        d['specialties']?['name'] ?? 'Doctor',
                        Icons.person,
                        () => _handleDoctorTap(d),
                      ),
                    ),

                    if (_allHints['clinics']!.isNotEmpty)
                      _buildSectionHeader("Clinics"),
                    ..._allHints['clinics']!.map(
                      (c) => _buildHintTile(
                        c['name'],
                        c['address'] ?? 'Clinic',
                        Icons.location_on,
                        () => _handleClinicTap(c),
                      ),
                    ),
                  ],
                ),
              )
            // 3. Submitted State: Heavy Full Cards
            else
              Expanded(
                child:
                    _isLoading
                        ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGreen,
                          ),
                        )
                        : (!_hasSearched)
                        ? Center(child: Text("Type to start searching..."))
                        : _doctors.isEmpty
                        ? Center(child: Text("No results found"))
                        : ListView.separated(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                          itemCount: _doctors.length,
                          separatorBuilder:
                              (context, index) => SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final doctor = _doctors[index];
                            final docId = doctor['id'] as int;
                            final specialtyName =
                                doctor['specialties'] != null
                                    ? doctor['specialties']['name']
                                    : 'Specialist';
                            final views =
                                doctor['views_count']?.toString() ?? '0';

                            final isFavorite = _favNotifier.isFavorite(docId);

                            return DoctorListCard(
                              id: docId,
                              name: doctor['full_name'] ?? 'Unknown',
                              specialty: " $specialtyName",
                              rating: doctor['rating']?.toString() ?? '0.0',
                              views: views,
                              imageUrl: doctor['profile_picture_url'],
                              isFavorite: isFavorite,
                              heroTagPrefix: 'search-',
                              onFavoriteTap: () => _favNotifier.toggle(doctor),
                              onCardTap:
                                  () => context.push(
                                    AppRoutes.doctorDetailsById('$docId'),
                                    extra: doctor,
                                  ),
                            );
                          },
                        ),
              ),
          ],
        ),
      ),
    );
  }
}
