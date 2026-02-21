import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:daktarpi/main.dart' as app;
import 'package:daktarpi/core/constants/app_routes.dart';
import 'package:daktarpi/core/router/app_router.dart';
import 'package:daktarpi/presentation/widgets/doctor_list_card.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAppAndLogin(WidgetTester tester) async {
    const email = String.fromEnvironment('E2E_EMAIL', defaultValue: '');
    const password = String.fromEnvironment('E2E_PASSWORD', defaultValue: '');

    expect(
      email,
      isNotEmpty,
      reason:
          'E2E_EMAIL is required. Run with --dart-define=E2E_EMAIL=patient@example.com',
    );
    expect(
      password,
      isNotEmpty,
      reason:
          'E2E_PASSWORD is required. Run with --dart-define=E2E_PASSWORD=secret',
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.textContaining('Welcome back'), findsWidgets);

    await tester.enterText(find.byType(EditableText).first, email);
    await tester.enterText(find.byType(EditableText).at(1), password);
    await tester.tap(find.text('Login').first);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  }

  Future<void> complete2faIfRequired(WidgetTester tester) async {
    final on2faScreen =
        find.textContaining('Security Check').evaluate().isNotEmpty ||
        find.textContaining('Account Recovery').evaluate().isNotEmpty;

    if (!on2faScreen) return;

    const totp = String.fromEnvironment('E2E_TOTP', defaultValue: '');
    expect(
      totp.length,
      6,
      reason:
          'This account requires 2FA. Provide --dart-define=E2E_TOTP=<6-digit-code>.',
    );

    await tester.enterText(find.byType(EditableText).first, totp);
    await tester.tap(find.text('Verify').first);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  }

  Future<void> selectDropdownValue(
    WidgetTester tester, {
    required String fieldHint,
    required String value,
  }) async {
    await tester.tap(find.text(fieldHint).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  Finder timeSlotFinder() {
    final slotPattern = RegExp(r'^\d{1,2}:\d{2}\s-\s\d{1,2}:\d{2}$');
    return find.byWidgetPredicate((widget) {
      return widget is Text &&
          widget.data != null &&
          slotPattern.hasMatch(widget.data!.trim());
    });
  }

  group('Booking flow', () {
    testWidgets(
      'completes end-to-end booking and lands in appointments',
      (tester) async {
        await pumpAppAndLogin(tester);
        await complete2faIfRequired(tester);

        appRouter.go(AppRoutes.doctors);
        await tester.pumpAndSettle(const Duration(seconds: 4));

        expect(find.byType(DoctorListCard), findsWidgets);
        await tester.tap(find.byType(DoctorListCard).first);
        await tester.pumpAndSettle(const Duration(seconds: 4));

        expect(find.textContaining('Book Now'), findsWidgets);

        final doctorSlots = timeSlotFinder();
        expect(
          doctorSlots.evaluate().isNotEmpty,
          isTrue,
          reason:
              'No bookable doctor slot found. Ensure E2E seed data has open schedules.',
        );
        await tester.tap(doctorSlots.first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Book Now').first);
        await tester.pumpAndSettle(const Duration(seconds: 4));

        expect(find.textContaining('Patient Details'), findsWidgets);

        final formInputs = find.byType(EditableText);
        expect(formInputs, findsAtLeastNWidgets(3));
        await tester.enterText(formInputs.at(0), 'E2E Patient');
        await tester.enterText(formInputs.at(1), '+8801700000000');
        await tester.enterText(formInputs.at(2), 'e2e.patient@example.com');

        await selectDropdownValue(tester, fieldHint: 'Day', value: '10');
        await selectDropdownValue(tester, fieldHint: 'Month', value: 'January');
        await selectDropdownValue(
          tester,
          fieldHint: 'Year',
          value: '${DateTime.now().year - 30}',
        );

        await tester.tap(find.text('Continue').first);
        await tester.pumpAndSettle(const Duration(seconds: 4));

        expect(find.textContaining('Available Time'), findsWidgets);

        final confirmationSlots = timeSlotFinder();
        expect(
          confirmationSlots.evaluate().isNotEmpty,
          isTrue,
          reason:
              'No confirmation time slot available for selected date. Seed at least one open slot.',
        );
        await tester.tap(confirmationSlots.first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm').first);
        await tester.pumpAndSettle(const Duration(seconds: 6));

        expect(
          find
                  .textContaining('Your Appointment Successful')
                  .evaluate()
                  .isNotEmpty ||
              find.textContaining('Thank You').evaluate().isNotEmpty,
          isTrue,
        );

        await tester.tap(find.text('Done').first);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.textContaining('My Appointments'), findsWidgets);
      },
      skip: const bool.fromEnvironment('RUN_E2E', defaultValue: false) == false,
    );
  });
}
