// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Doctor _$DoctorFromJson(Map<String, dynamic> json) => _Doctor(
  id: (json['id'] as num).toInt(),
  fullName: json['full_name'] as String? ?? 'Unknown Doctor',
  profilePictureUrl: json['profile_picture_url'] as String?,
  specialty:
      _readDoctorSpecialty(json, 'specialty') == null
          ? 'Specialist'
          : _specialtyFromJson(_readDoctorSpecialty(json, 'specialty')),
  rating: json['rating'] == null ? 0.0 : _doubleFromJson(json['rating']),
  reviewsCount:
      json['reviews_count'] == null ? 0 : _intFromJson(json['reviews_count']),
  experienceYears:
      json['experience_years'] == null
          ? 0
          : _intFromJson(json['experience_years']),
  patientsServed:
      json['patients_served'] == null
          ? 0
          : _intFromJson(json['patients_served']),
  uniquePatientsCount:
      json['unique_patients_count'] == null
          ? 0
          : _intFromJson(json['unique_patients_count']),
  viewsCount:
      json['views_count'] == null ? 0 : _intFromJson(json['views_count']),
  visitPrice:
      json['hourly_rate'] == null ? 0 : _intFromJson(json['hourly_rate']),
  about: json['about'] as String?,
  location: json['location'] as String?,
  phoneNumber: json['phone_number'] as String?,
);

Map<String, dynamic> _$DoctorToJson(_Doctor instance) => <String, dynamic>{
  'id': instance.id,
  'full_name': instance.fullName,
  'profile_picture_url': instance.profilePictureUrl,
  'specialty': instance.specialty,
  'rating': instance.rating,
  'reviews_count': instance.reviewsCount,
  'experience_years': instance.experienceYears,
  'patients_served': instance.patientsServed,
  'unique_patients_count': instance.uniquePatientsCount,
  'views_count': instance.viewsCount,
  'hourly_rate': instance.visitPrice,
  'about': instance.about,
  'location': instance.location,
  'phone_number': instance.phoneNumber,
};
