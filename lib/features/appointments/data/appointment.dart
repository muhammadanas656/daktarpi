import 'package:freezed_annotation/freezed_annotation.dart';
import '../../doctors/data/doctor.dart';
import '../../doctors/data/clinic.dart';

part 'appointment.freezed.dart';
part 'appointment.g.dart';

/// Appointment model representing a booked appointment from the `appointments` table.
@freezed
abstract class Appointment with _$Appointment {
  @JsonSerializable(explicitToJson: true)
  const factory Appointment({
    required int id,
    @JsonKey(name: 'schedule_date') required String scheduleDate,
    @JsonKey(name: 'start_time') required String startTime,
    @JsonKey(name: 'end_time') required String endTime,
    @Default('pending') String status,
    @JsonKey(name: 'patient_name') @Default('') String patientName,
    @JsonKey(name: 'patient_phone') @Default('') String patientPhone,
    @JsonKey(name: 'patient_email') @Default('') String patientEmail,
    @JsonKey(name: 'patient_gender') @Default('Male') String patientGender,
    @JsonKey(name: 'patient_dob') @Default('') String patientDob,
    @JsonKey(name: 'doctors') Doctor? doctor,
    @JsonKey(name: 'clinics') Clinic? clinic,
    @JsonKey(name: 'deleted_at') DateTime? deletedAt,
    @JsonKey(name: 'attached_record_ids') @Default([]) List<int> attachedRecordIds,
  }) = _Appointment;

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      _$AppointmentFromJson(json);
}
