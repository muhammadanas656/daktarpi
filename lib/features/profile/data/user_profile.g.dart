// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  id: json['id'] as String,
  fullName: json['full_name'] as String? ?? '',
  phoneNumber: json['phone_number'] as String?,
  countryCode: json['country_code'] as String? ?? '+92',
  countryIso: json['country_iso'] as String?,
  dateOfBirth: _nullableDateFromJson(json['date_of_birth']),
  location: json['location'] as String?,
  profilePictureUrl: json['profile_picture_url'] as String?,
  updatedAt: _nullableDateFromJson(json['updated_at']),
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'full_name': instance.fullName,
      'phone_number': instance.phoneNumber,
      'country_code': instance.countryCode,
      'country_iso': instance.countryIso,
      'date_of_birth': instance.dateOfBirth?.toIso8601String(),
      'location': instance.location,
      'profile_picture_url': instance.profilePictureUrl,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
