import 'package:freezed_annotation/freezed_annotation.dart';

part 'doctor.freezed.dart';
part 'doctor.g.dart';

// REPLACE YOUR EXISTING FUNCTION WITH THIS:
Object? _readDoctorSpecialty(Map<dynamic, dynamic> json, String key) {
  final nested = json['specialties'];
  if (nested is Map && nested['name'] != null) {
    return nested['name'];
  }
  // PRO FIX: Properly catch List data from Supabase joins
  if (nested is List &&
      nested.isNotEmpty &&
      nested.first is Map &&
      nested.first['name'] != null) {
    return nested.first['name'];
  }
  return json['specialty'] ?? json[key];
}

String _specialtyFromJson(Object? value) {
  final parsed = value?.toString().trim();
  if (parsed == null || parsed.isEmpty) {
    return 'Specialist';
  }
  return parsed;
}

double _doubleFromJson(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _intFromJson(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Doctor model representing a medical practitioner from the `doctors` table.
@freezed
abstract class Doctor with _$Doctor {
  const Doctor._();

  const factory Doctor({
    required int id,
    @JsonKey(name: 'full_name', defaultValue: 'Unknown Doctor')
    required String fullName,
    @JsonKey(name: 'profile_picture_url') String? profilePictureUrl,
    @JsonKey(readValue: _readDoctorSpecialty, fromJson: _specialtyFromJson)
    @Default('Specialist')
    String specialty,
    @JsonKey(fromJson: _doubleFromJson) @Default(0.0) double rating,
    @JsonKey(name: 'reviews_count', fromJson: _intFromJson)
    @Default(0)
    int reviewsCount,
    @JsonKey(name: 'experience_years', fromJson: _intFromJson)
    @Default(0)
    int experienceYears,
    @JsonKey(name: 'patients_served', fromJson: _intFromJson)
    @Default(0)
    int patientsServed,
    @JsonKey(name: 'views_count', fromJson: _intFromJson)
    @Default(0)
    int viewsCount,
    @JsonKey(name: 'hourly_rate', fromJson: _intFromJson)
    @Default(0)
    int visitPrice,
    String? about,
    @JsonKey(name: 'location') String? location,
    @JsonKey(name: 'phone_number') String? phoneNumber,
  }) = _Doctor;

  factory Doctor.fromJson(Map<String, dynamic> json) => _$DoctorFromJson(json);
}
