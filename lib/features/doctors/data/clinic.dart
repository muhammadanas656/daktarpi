import 'package:freezed_annotation/freezed_annotation.dart';

part 'clinic.freezed.dart';
part 'clinic.g.dart';

/// Clinic model representing a medical clinic from the `clinics` table.
@freezed
abstract class Clinic with _$Clinic {
  const factory Clinic({
    required int id,
    @Default('Unknown Clinic') String name,
    @Default('Unknown Address') String address,
    @JsonKey(name: 'logo_url') String? logoUrl,
  }) = _Clinic;

  factory Clinic.fromJson(Map<String, dynamic> json) => _$ClinicFromJson(json);
}
