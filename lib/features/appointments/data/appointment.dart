import '../../doctors/data/doctor.dart';
import '../../doctors/data/clinic.dart';

/// Appointment model representing a booked appointment from the `appointments` table.
class Appointment {
  final int id;
  final String scheduleDate;
  final String startTime;
  final String endTime;
  final String status;
  final String patientName;
  final String patientPhone;
  final String patientEmail;
  final String patientGender;
  final String patientDob;
  final Doctor? doctor;
  final Clinic? clinic;

  Appointment({
    required this.id,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.patientName,
    required this.patientPhone,
    required this.patientEmail,
    required this.patientGender,
    required this.patientDob,
    this.doctor,
    this.clinic,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as int,
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
          json['doctors'] != null
              ? Doctor.fromJson(json['doctors'] as Map<String, dynamic>)
              : null,
      clinic:
          json['clinics'] != null
              ? Clinic.fromJson(json['clinics'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schedule_date': scheduleDate,
      'start_time': startTime,
      'end_time': endTime,
      'status': status,
      'patient_name': patientName,
      'patient_phone': patientPhone,
      'patient_email': patientEmail,
      'patient_gender': patientGender,
      'patient_dob': patientDob,
      if (doctor != null) 'doctors': doctor!.toJson(),
      if (clinic != null) 'clinics': clinic!.toJson(),
    };
  }
}
