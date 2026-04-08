import 'package:aeviapulse/features/appointments/data/appointment.dart';
import 'package:aeviapulse/features/appointments/data/appointment_secure_cache_repository.dart';
import 'package:aeviapulse/features/doctors/data/clinic.dart';
import 'package:aeviapulse/features/doctors/data/doctor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

List<Appointment> _buildHeavyAppointments(int count) {
  final startDate = DateTime(2026, 1, 1);

  return List<Appointment>.generate(count, (index) {
    final date = startDate.add(Duration(days: index % 365));
    final startHour = 8 + (index % 10);
    final minute = (index % 2) * 30;
    final endMinute = minute == 30 ? 0 : 30;
    final endHour = minute == 30 ? startHour + 1 : startHour;

    final doctor = Doctor(
      id: index + 1,
      fullName: 'Dr. Heavy Load ${index + 1}',
      profilePictureUrl: null,
      specialty: index % 2 == 0 ? 'Cardiology' : 'Neurology',
      rating: 3.8 + ((index % 12) / 10),
      reviewsCount: 200 + index,
      experienceYears: 5 + (index % 20),
      patientsServed: 1200 + (index * 7),
      viewsCount: 5000 + (index * 5),
      visitPrice: 500 + ((index % 15) * 50),
      about:
          'High-volume synthetic profile for stress testing long list rendering.',
      phoneNumber: '+1-555-${(100000 + index).toString().substring(1)}',
    );

    final clinic = Clinic(
      id: (index % 40) + 1,
      name: 'Clinic ${(index % 40) + 1}',
      address: 'Block ${index % 12 + 1}, Test Medical Avenue',
    );

    return Appointment(
      id: index + 1,
      scheduleDate: date.toIso8601String().split('T').first,
      startTime:
          '${startHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      endTime:
          '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}',
      status: 'confirmed',
      patientName: 'Patient ${index + 1}',
      patientPhone: '+1-202-${(100000 + index).toString().substring(1)}',
      patientEmail: 'patient${index + 1}@example.com',
      patientGender: index.isEven ? 'Male' : 'Female',
      patientDob: '1990-01-01',
      doctor: doctor,
      clinic: clinic,
    );
  });
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'heavy cached list scrolls without crashes and stays within frame budget',
    (tester) async {
      final cacheRepository = AppointmentSecureCacheRepository();
      addTearDown(() async {
        await cacheRepository.clear();
      });

      final heavyAppointments = _buildHeavyAppointments(550);
      await cacheRepository.saveAppointments(heavyAppointments);
      final loaded = await cacheRepository.loadAppointments();
      expect(loaded.length, greaterThanOrEqualTo(500));

      final listKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              key: listKey,
              itemCount: loaded.length,
              itemBuilder: (context, index) {
                final appointment = loaded[index];
                return ListTile(
                  title: Text(appointment.doctor?.fullName ?? 'Unknown Doctor'),
                  subtitle: Text(
                    '${appointment.scheduleDate}  ${appointment.startTime}-${appointment.endTime}',
                  ),
                  trailing: Text(appointment.clinic?.name ?? 'Clinic'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await binding.watchPerformance(() async {
        final listFinder = find.byKey(listKey);
        for (int i = 0; i < 20; i++) {
          await tester.fling(listFinder, const Offset(0, -1600), 12000);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.fling(listFinder, const Offset(0, 1600), 12000);
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();
      }, reportKey: 'heavy_load_scroll');

      final report = binding.reportData?['heavy_load_scroll'];
      expect(report, isA<Map<String, dynamic>>());
      final perf = Map<String, dynamic>.from(report as Map);

      final averageBuildMillis =
          (perf['average_frame_build_time_millis'] as num?)?.toDouble() ?? 999;
      final averageRasterMillis =
          (perf['average_frame_rasterizer_time_millis'] as num?)?.toDouble() ??
          999;
      final frameCount = (perf['frame_count'] as num?)?.toInt() ?? 0;

      // Practical thresholds for integration environments while still guarding
      // against severe regressions and OOM-like frame collapse.
      expect(frameCount, greaterThan(30));
      expect(averageBuildMillis, lessThan(16.7));
      expect(averageRasterMillis, lessThan(16.7));
      expect(tester.takeException(), isNull);
    },
    skip: const bool.fromEnvironment('RUN_E2E', defaultValue: false) == false,
  );
}
