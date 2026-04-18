import 'dart:io';

void main() {
  final file = File('lib/features/doctors/presentation/widgets/smart_filter_bar.dart');
  var content = file.readAsStringSync();
  
  if (!content.contains('import \'../../../../core/constants/app_routes.dart\';')) {
    content = content.replaceFirst(
      'import \'../../../../core/theme/app_colors.dart\';',
      'import \'package:go_router/go_router.dart\';\nimport \'package:geolocator/geolocator.dart\';\nimport \'../../../../core/constants/app_routes.dart\';\nimport \'../../../../core/theme/app_colors.dart\';'
    );
  }

  final targetMethod = '''  void _checkAndFetchRadiusIfNeeded() {
    // Always fire the callback immediately with whatever radius we have (or null).
    // This ensures pill taps are never silently dropped, even mid-GPS-fetch.
    widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
    // If we don't have a radius yet, kick off the GPS fetch in the background,
    // which will fire onFilterChanged again once radius arrives.
    if (_activeRadiusKm == null && _isRadiusAutoCalculated && !_isFetchingRadius) {
      _fetchOptimalRadius();
    }
  }''';

  final replaceMethod = '''  void _checkAndFetchRadiusIfNeeded() async {
    final needsGps = _selectedFilter == 'Nearest' ||
        _selectedFilter == 'Available Today' ||
        _selectedFilter == 'Hospital' ||
        _selectedFilter == 'Clinic';

    if (needsGps && !widget.isBackgroundLayer) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        // Automatically present the Location Permission Screen with Fallback if GPS is disabled!
        await context.push(AppRoutes.location);
      }
    }

    if (!mounted) return;

    // Always fire the callback immediately with whatever radius we have (or null).
    // This ensures pill taps are never silently dropped, even mid-GPS-fetch.
    widget.onFilterChanged(_selectedFilter, _activeRadiusKm);
    
    // If we don't have a radius yet, kick off the GPS fetch in the background,
    // which will fire onFilterChanged again once radius arrives.
    if (_activeRadiusKm == null && _isRadiusAutoCalculated && !_isFetchingRadius) {
      _fetchOptimalRadius();
    }
  }''';

  if (content.contains(targetMethod)) {
    content = content.replaceFirst(targetMethod, replaceMethod);
    file.writeAsStringSync(content);
    print('smart_filter_bar.dart patched successfully!');
  } else {
    print('Failed to find target method in smart_filter_bar.dart');
  }
}
