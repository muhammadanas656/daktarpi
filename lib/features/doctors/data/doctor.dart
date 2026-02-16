/// Doctor model representing a medical practitioner from the `doctors` table.
class Doctor {
  final int id;
  final String fullName;
  final String? profilePictureUrl;
  final String specialty;
  final double rating;
  final int reviewsCount;
  final int experienceYears;
  final int patientsServed;
  final int viewsCount;
  final int visitPrice;
  final String? about;
  final String? phoneNumber;

  Doctor({
    required this.id,
    required this.fullName,
    this.profilePictureUrl,
    required this.specialty,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.experienceYears = 0,
    this.patientsServed = 0,
    this.viewsCount = 0,
    this.visitPrice = 0,
    this.about,
    this.phoneNumber,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    String specialtyName = 'Specialist';
    if (json['specialties'] != null && json['specialties']['name'] != null) {
      specialtyName = json['specialties']['name'];
    }

    return Doctor(
      id: (json['id'] as num).toInt(),
      fullName: json['full_name'] as String? ?? 'Unknown Doctor',
      profilePictureUrl: json['profile_picture_url'] as String?,
      specialty: specialtyName,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
      patientsServed: (json['patients_served'] as num?)?.toInt() ?? 0,
      viewsCount: (json['views_count'] as num?)?.toInt() ?? 0,
      visitPrice: (json['hourly_rate'] as num?)?.toInt() ?? 0,
      about: json['about'] as String?,
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'profile_picture_url': profilePictureUrl,
      'specialties': {'name': specialty},
      'rating': rating,
      'reviews_count': reviewsCount,
      'experience_years': experienceYears,
      'patients_served': patientsServed,
      'views_count': viewsCount,
      'hourly_rate': visitPrice,
      'about': about,
      'phone_number': phoneNumber,
    };
  }
}
