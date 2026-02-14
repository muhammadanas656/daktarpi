import '../../doctors/data/specialty.dart';
import '../../doctors/data/doctor_repository.dart';

/// Thin facade that provides home-screen-specific data.
///
/// Delegates to [DoctorRepository] under the hood so the home
/// screen does not couple directly to raw DB queries.
class HomeRepository {
  final DoctorRepository _doctorRepo;

  HomeRepository({DoctorRepository? doctorRepo})
      : _doctorRepo = doctorRepo ?? DoctorRepository();

  /// Fetches the list of specialties for the home screen.
  Future<List<Specialty>> fetchSpecialties({int limit = 10}) async {
    final raw = await _doctorRepo.fetchSpecialties(limit: limit);
    return raw.map((json) => Specialty.fromJson(json)).toList();
  }

  /// Fetches popular doctors (limited for the home carousel).
  Future<List<Map<String, dynamic>>> fetchPopularDoctors({int limit = 5}) async {
    return _doctorRepo.fetchPopularDoctors(limit: limit);
  }

  /// Fetches featured doctors (limited for the home carousel).
  Future<List<Map<String, dynamic>>> fetchFeaturedDoctors({int limit = 5}) async {
    return _doctorRepo.fetchFeaturedDoctors(limit: limit);
  }
}
