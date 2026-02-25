import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

DateTime? _nullableDateFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  final parsed = DateTime.tryParse(value.toString());
  return parsed;
}

@freezed
abstract class UserProfile with _$UserProfile {
  const UserProfile._();

  const factory UserProfile({
    required String id,
    @JsonKey(name: 'full_name', defaultValue: '') required String fullName,
    @JsonKey(name: 'phone_number') String? phoneNumber,
    @JsonKey(name: 'country_code', defaultValue: '+92') String? countryCode,

    // NEW: Added country_iso to fix the getter/parameter errors
    @JsonKey(name: 'country_iso') String? countryIso,

    @JsonKey(name: 'date_of_birth', fromJson: _nullableDateFromJson)
    DateTime? dateOfBirth,
    String? location,
    @JsonKey(name: 'profile_picture_url') String? profilePictureUrl,
    @JsonKey(name: 'updated_at', fromJson: _nullableDateFromJson)
    DateTime? updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}
