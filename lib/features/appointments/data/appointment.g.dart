// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'appointment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Appointment _$AppointmentFromJson(Map<String, dynamic> json) => _Appointment(
  id: (json['id'] as num).toInt(),
  scheduleDate: json['schedule_date'] as String,
  startTime: json['start_time'] as String,
  endTime: json['end_time'] as String,
  status: json['status'] as String? ?? 'pending',
  patientName: json['patient_name'] as String? ?? '',
  patientPhone: json['patient_phone'] as String? ?? '',
  patientEmail: json['patient_email'] as String? ?? '',
  patientGender: json['patient_gender'] as String? ?? 'Male',
  patientDob: json['patient_dob'] as String? ?? '',
  doctor:
      json['doctors'] == null
          ? null
          : Doctor.fromJson(json['doctors'] as Map<String, dynamic>),
  clinic:
      json['clinics'] == null
          ? null
          : Clinic.fromJson(json['clinics'] as Map<String, dynamic>),
  deletedAt:
      json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at'] as String),
  attachedRecordIds:
      (json['attached_record_ids'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$AppointmentToJson(_Appointment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'schedule_date': instance.scheduleDate,
      'start_time': instance.startTime,
      'end_time': instance.endTime,
      'status': instance.status,
      'patient_name': instance.patientName,
      'patient_phone': instance.patientPhone,
      'patient_email': instance.patientEmail,
      'patient_gender': instance.patientGender,
      'patient_dob': instance.patientDob,
      'doctors': instance.doctor?.toJson(),
      'clinics': instance.clinic?.toJson(),
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'attached_record_ids': instance.attachedRecordIds,
    };
