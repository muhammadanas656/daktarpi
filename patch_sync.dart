import 'dart:io';

void main() {
  // 1. Doctor Details Screen
  final detailsFile = File('lib/features/doctors/presentation/screens/doctor_details_screen.dart');
  if (detailsFile.existsSync()) {
    var content = detailsFile.readAsStringSync();
    
    // Replace duplicate patients served
    final target = '''                      DoctorStatsRow(
                        patients:
                            (_doctor!['unique_patients_count'] ??
                                    _doctor!['patients_served'])
                                ?.toString() ??
                            '0',''';
    final replacement = '''                      DoctorStatsRow(
                        patients: _doctor!['unique_patients_count']?.toString() ?? '0',''';
                        
    content = content.replaceFirst(target, replacement);
    detailsFile.writeAsStringSync(content);
    print('Updated doctor_details_screen.dart');
  }

  // 2. Doctor Repository
  final repoFile = File('lib/features/doctors/data/doctor_repository.dart');
  if (repoFile.existsSync()) {
    var content = repoFile.readAsStringSync();
    
    // fetchFacilities
    content = content.replaceFirst(
      'Future<List<Map<String, dynamic>>> fetchFacilities({\n    required String type,\n    String? query,\n    double? userLat,\n    double? userLng,\n    double? maxRadiusKm,\n    String sortBy = \'views_count\',\n  }) async {',
      'Future<List<Map<String, dynamic>>> fetchFacilities({\n    required String type,\n    String? query,\n    double? userLat,\n    double? userLng,\n    double? maxRadiusKm,\n    bool forceRefresh = false,\n    String sortBy = \'views_count\',\n  }) async {'
    );
    
    content = content.replaceFirst(
      'final List<Map<String, dynamic>> rawFacilities = await _fetchWithCache(\n      cacheKey: isSearch ? null : \'facilities_\$type\', // Base cache key\n      fetcher: () async {',
      'final List<Map<String, dynamic>> rawFacilities = await _fetchWithCache(\n      cacheKey: isSearch ? null : \'facilities_\$type\',\n      forceRefresh: forceRefresh,\n      fetcher: () async {'
    );

    // fetchHospitals and fetchClinicsList
    content = content.replaceFirst(
      'Future<List<Map<String, dynamic>>> fetchHospitals({String? query, double? userLat, double? userLng, double? maxRadiusKm}) async =>\n      fetchFacilities(type: \'hospital\', query: query, userLat: userLat, userLng: userLng, maxRadiusKm: maxRadiusKm);',
      'Future<List<Map<String, dynamic>>> fetchHospitals({String? query, double? userLat, double? userLng, double? maxRadiusKm, bool forceRefresh = false}) async =>\n      fetchFacilities(type: \'hospital\', query: query, userLat: userLat, userLng: userLng, maxRadiusKm: maxRadiusKm, forceRefresh: forceRefresh);'
    );
    
    content = content.replaceFirst(
      'Future<List<Map<String, dynamic>>> fetchClinicsList({String? query, double? userLat, double? userLng, double? maxRadiusKm}) async =>\n      fetchFacilities(type: \'clinic\', query: query, userLat: userLat, userLng: userLng, maxRadiusKm: maxRadiusKm);',
      'Future<List<Map<String, dynamic>>> fetchClinicsList({String? query, double? userLat, double? userLng, double? maxRadiusKm, bool forceRefresh = false}) async =>\n      fetchFacilities(type: \'clinic\', query: query, userLat: userLat, userLng: userLng, maxRadiusKm: maxRadiusKm, forceRefresh: forceRefresh);'
    );

    repoFile.writeAsStringSync(content);
    print('Updated doctor_repository.dart');
  }

  // 3. Doctors Notifier
  final notifierFile = File('lib/features/doctors/presentation/doctors_notifier.dart');
  if (notifierFile.existsSync()) {
    var content = notifierFile.readAsStringSync();
    
    content = content.replaceFirst(
      '_doctorRepo.fetchAllDoctors(\n          query: query,\n          filterType: filter,\n          maxRadiusKm: maxRadiusKm, // <--- Passes dynamic boundary payload\n          userLat: userLat,\n          userLng: userLng,\n          userLocation: userLocation,\n          countryIso: countryIso,\n        )',
      '_doctorRepo.fetchAllDoctors(\n          query: query,\n          filterType: filter,\n          maxRadiusKm: maxRadiusKm,\n          userLat: userLat,\n          userLng: userLng,\n          userLocation: userLocation,\n          countryIso: countryIso,\n          forceRefresh: forceRefresh,\n        )'
    );

    content = content.replaceFirst(
      '_doctorRepo.fetchHospitals(\n          query: query,\n          userLat: userLat,\n          userLng: userLng,\n          maxRadiusKm: maxRadiusKm,\n        )',
      '_doctorRepo.fetchHospitals(\n          query: query,\n          userLat: userLat,\n          userLng: userLng,\n          maxRadiusKm: maxRadiusKm,\n          forceRefresh: forceRefresh,\n        )'
    );

    content = content.replaceFirst(
      '_doctorRepo.fetchClinicsList(\n          query: query,\n          userLat: userLat,\n          userLng: userLng,\n          maxRadiusKm: maxRadiusKm,\n        )',
      '_doctorRepo.fetchClinicsList(\n          query: query,\n          userLat: userLat,\n          userLng: userLng,\n          maxRadiusKm: maxRadiusKm,\n          forceRefresh: forceRefresh,\n        )'
    );

    notifierFile.writeAsStringSync(content);
    print('Updated doctors_notifier.dart');
  }
}
