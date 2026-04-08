import 'package:aeviapulse/features/medical_records/data/medical_record.dart';
import 'package:aeviapulse/features/medical_records/presentation/models/medical_record_route_args.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MedicalRecordRouteArgs', () {
    test('supports null record for add flow', () {
      const args = MedicalRecordRouteArgs();
      expect(args.record, isNull);
    });

    test('carries record for edit flow', () {
      final record = MedicalRecord(
        id: 42,
        userId: 'user-123',
        recordFor: 'John Doe',
        recordType: 'Report',
        recordDate: DateTime(2026, 2, 21),
        fileUrls: const ['path/to/report.pdf'],
        createdAt: DateTime(2026, 2, 21, 10, 0),
      );

      final args = MedicalRecordRouteArgs(record: record);
      expect(args.record, isNotNull);
      expect(args.record!.id, 42);
      expect(args.record!.recordType, 'Report');
    });
  });
}
