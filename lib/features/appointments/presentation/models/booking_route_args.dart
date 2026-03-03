class AppointmentBookingArgs {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> clinic;
  final DateTime initialDate;
  final String? timeSlot;
  final String idempotencyKey;

  const AppointmentBookingArgs({
    required this.doctor,
    required this.clinic,
    required this.initialDate,
    this.timeSlot,
    required this.idempotencyKey,
  });

  factory AppointmentBookingArgs.fromMap(Map<String, dynamic> map) {
    final rawDate = map['initialDate'];
    final date =
        rawDate is DateTime
            ? rawDate
            : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();

    return AppointmentBookingArgs(
      doctor: Map<String, dynamic>.from(map['doctor'] as Map),
      clinic: Map<String, dynamic>.from(map['clinic'] as Map),
      initialDate: date,
      timeSlot: map['timeSlot'] as String?,
      idempotencyKey:
          map['idempotencyKey']?.toString().isNotEmpty == true
              ? map['idempotencyKey'].toString()
              : 'legacy-${DateTime.now().microsecondsSinceEpoch}',
    );
  }
}

class PaymentMethodArgs {
  final Map<String, dynamic> doctor;
  final Map<String, dynamic> clinic;
  final Map<String, dynamic> patientDetails;
  final DateTime appointmentDate;
  final int? appointmentId;
  final String? timeSlot;
  final String idempotencyKey;

  const PaymentMethodArgs({
    required this.doctor,
    required this.clinic,
    required this.patientDetails,
    required this.appointmentDate,
    this.appointmentId,
    this.timeSlot,
    required this.idempotencyKey,
  });

  factory PaymentMethodArgs.fromMap(Map<String, dynamic> map) {
    final rawDate = map['appointmentDate'];
    final date =
        rawDate is DateTime
            ? rawDate
            : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();

    return PaymentMethodArgs(
      doctor: Map<String, dynamic>.from(map['doctor'] as Map),
      clinic: Map<String, dynamic>.from(map['clinic'] as Map),
      patientDetails: Map<String, dynamic>.from(map['patientDetails'] as Map),
      appointmentDate: date,
      appointmentId: map['appointmentId'] as int?,
      timeSlot: map['timeSlot'] as String?,
      idempotencyKey:
          map['idempotencyKey']?.toString().isNotEmpty == true
              ? map['idempotencyKey'].toString()
              : 'legacy-${DateTime.now().microsecondsSinceEpoch}',
    );
  }
}

class AppointmentsRouteArgs {
  final bool refresh;

  const AppointmentsRouteArgs({this.refresh = false});
}

class DummyPaymentRouteArgs {
  final Map<String, dynamic> appointmentData;
  final DateTime appointmentDateTime;
  final int reminderMinutes;
  final String doctorName;
  final int? appointmentId;
  final String displayDate;
  final String displayTime;

  const DummyPaymentRouteArgs({
    required this.appointmentData,
    required this.appointmentDateTime,
    required this.reminderMinutes,
    required this.doctorName,
    required this.displayDate,
    required this.displayTime,
    this.appointmentId,
  });
}
