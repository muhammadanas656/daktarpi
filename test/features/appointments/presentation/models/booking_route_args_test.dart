import 'package:flutter_test/flutter_test.dart';
import 'package:aeviapulse/features/appointments/presentation/models/booking_route_args.dart';

void main() {
  group('AppointmentBookingArgs', () {
    test('fromMap parses expected fields', () {
      final args = AppointmentBookingArgs.fromMap({
        'doctor': {'id': 1, 'full_name': 'Dr. A'},
        'clinic': {'id': 10, 'name': 'Main Clinic'},
        'initialDate': DateTime(2026, 2, 20),
        'timeSlot': '10:00 - 10:30',
        'idempotencyKey': 'booking-abc-123',
      });

      expect(args.doctor['id'], 1);
      expect(args.clinic['id'], 10);
      expect(args.initialDate, DateTime(2026, 2, 20));
      expect(args.timeSlot, '10:00 - 10:30');
      expect(args.idempotencyKey, 'booking-abc-123');
    });
  });

  group('PaymentMethodArgs', () {
    test('fromMap parses expected fields', () {
      final args = PaymentMethodArgs.fromMap({
        'doctor': {'id': 2},
        'clinic': {'id': 11},
        'patientDetails': {'name': 'John Doe'},
        'appointmentDate': DateTime(2026, 3, 1),
        'appointmentId': 55,
        'timeSlot': '11:00 - 11:30',
        'idempotencyKey': 'payment-xyz-456',
      });

      expect(args.doctor['id'], 2);
      expect(args.clinic['id'], 11);
      expect(args.patientDetails['name'], 'John Doe');
      expect(args.appointmentDate, DateTime(2026, 3, 1));
      expect(args.appointmentId, 55);
      expect(args.timeSlot, '11:00 - 11:30');
      expect(args.idempotencyKey, 'payment-xyz-456');
    });
  });

  group('AppointmentsRouteArgs', () {
    test('defaults refresh to false', () {
      const args = AppointmentsRouteArgs();
      expect(args.refresh, isFalse);
    });

    test('accepts refresh=true explicitly', () {
      const args = AppointmentsRouteArgs(refresh: true);
      expect(args.refresh, isTrue);
    });
  });
}
