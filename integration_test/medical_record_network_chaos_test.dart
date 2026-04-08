import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:aeviapulse/core/constants/app_routes.dart';
import 'package:aeviapulse/core/router/app_router.dart';
import 'package:aeviapulse/features/medical_records/data/medical_record.dart';
import 'package:aeviapulse/features/medical_records/presentation/models/medical_record_route_args.dart';
import 'package:aeviapulse/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class FakeConnectivityPlatform extends ConnectivityPlatform {
  FakeConnectivityPlatform({required List<ConnectivityResult> initial})
    : _current = initial;

  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> _current;

  void emit(List<ConnectivityResult> next) {
    _current = next;
    _controller.add(next);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  Future<void> dispose() => _controller.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Medical record chaos scenario', () {
    late ConnectivityPlatform originalPlatform;
    late FakeConnectivityPlatform fakePlatform;

    setUp(() {
      originalPlatform = ConnectivityPlatform.instance;
      fakePlatform = FakeConnectivityPlatform(
        initial: [ConnectivityResult.wifi],
      );
      ConnectivityPlatform.instance = fakePlatform;
    });

    tearDown(() async {
      ConnectivityPlatform.instance = originalPlatform;
      await fakePlatform.dispose();
    });

    testWidgets(
      'drops network on submit, shows offline banner, and does not crash',
      (tester) async {
        app.main();
        await tester.pumpAndSettle(const Duration(seconds: 3));

        final record = MedicalRecord(
          id: 99,
          userId: 'local-chaos-user',
          recordFor: 'Existing Patient',
          recordType: 'Prescription',
          recordDate: DateTime(2026, 2, 20),
          fileUrls: const ['local/report.pdf'],
          createdAt: DateTime(2026, 2, 20),
        );

        appRouter.go(
          AppRoutes.addMedicalRecord,
          extra: MedicalRecordRouteArgs(record: record),
        );
        await tester.pumpAndSettle(const Duration(seconds: 2));

        fakePlatform.emit([ConnectivityResult.none]);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(
          find.text('Offline Mode: Viewing cached records.'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byType(EditableText).first,
          'Chaos Patient',
        );
        await tester.tap(find.text('Update record').first);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        expect(tester.takeException(), isNull);
        expect(
          find.text('Offline Mode: Viewing cached records.'),
          findsOneWidget,
        );
      },
      skip: const bool.fromEnvironment('RUN_E2E', defaultValue: false) == false,
    );
  });
}
