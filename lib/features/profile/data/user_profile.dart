class UserProfile {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? location;
  final String? profilePictureUrl;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.dateOfBirth,
    this.location,
    this.profilePictureUrl,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'] as String)
          : null,
      location: json['location'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'location': location,
      'profile_picture_url': profilePictureUrl,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
