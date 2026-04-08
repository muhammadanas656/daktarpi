import 'dart:convert';

import 'package:aeviapulse/core/constants/app_routes.dart';
import 'package:aeviapulse/core/router/app_router.dart';
import 'package:aeviapulse/presentation/widgets/doctor_list_card.dart';
import 'package:aeviapulse/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final secureStorage = <String, String>{};
  var biometricAuthenticateCalls = 0;

  Map<String, dynamic> callArgs(MethodCall call) {
    final raw = call.arguments;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, (call) async {
          switch (call.method) {
            case 'isDeviceSupported':
            case 'canCheckBiometrics':
              return true;
            case 'getAvailableBiometrics':
            case 'getEnrolledBiometrics':
              return <String>['fingerprint'];
            case 'authenticate':
              biometricAuthenticateCalls += 1;
              await Future<void>.delayed(const Duration(milliseconds: 120));
              return true;
            case 'stopAuthentication':
              return true;
            default:
              return null;
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          final args = callArgs(call);
          final key = args['key']?.toString();

          switch (call.method) {
            case 'write':
              if (key != null) {
                secureStorage[key] = (args['value'] ?? '').toString();
              }
              return null;
            case 'read':
              if (key == null) {
                return null;
              }
              return secureStorage[key];
            case 'delete':
              if (key != null) {
                secureStorage.remove(key);
              }
              return null;
            case 'containsKey':
              if (key == null) {
                return false;
              }
              return secureStorage.containsKey(key);
            case 'readAll':
              return Map<String, String>.from(secureStorage);
            case 'deleteAll':
              secureStorage.clear();
              return null;
            default:
              return null;
          }
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

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

    if (!on2faScreen) {
      return;
    }

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

  Finder timeSlotFinder() {
    final slotPattern = RegExp(r'^\d{1,2}:\d{2}\s-\s\d{1,2}:\d{2}$');
    return find.byWidgetPredicate((widget) {
      return widget is Text &&
          widget.data != null &&
          slotPattern.hasMatch(widget.data!.trim());
    });
  }

  Future<void> navigateToPatientDetails(WidgetTester tester) async {
    appRouter.go(AppRoutes.doctors);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.byType(DoctorListCard), findsWidgets);
    await tester.tap(find.byType(DoctorListCard).first);
    await tester.pumpAndSettle(const Duration(seconds: 4));

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
  }

  group('Booking lock-resume flow', () {
    testWidgets(
      'locks mid-booking, unlocks via biometric mock, and preserves autosaved draft',
      (tester) async {
        await pumpAppAndLogin(tester);
        await complete2faIfRequired(tester);
        await navigateToPatientDetails(tester);

        final formInputs = find.byType(EditableText);
        expect(formInputs, findsAtLeastNWidgets(3));

        await tester.enterText(formInputs.at(0), 'Lock Resume Patient');
        await tester.enterText(formInputs.at(1), '+8801700000001');
        await tester.enterText(formInputs.at(2), 'lock.resume@example.com');

        await tester.pump(const Duration(milliseconds: 900));

        final draftBefore = secureStorage['appointment_booking_draft_v1'];
        expect(draftBefore, isNotNull);
        final decodedBefore = jsonDecode(draftBefore!) as Map<String, dynamic>;
        expect(decodedBefore['name'], 'Lock Resume Patient');
        expect(decodedBefore['phone'], '+8801700000001');
        expect(decodedBefore['email'], 'lock.resume@example.com');

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(biometricAuthenticateCalls, greaterThan(0));
        expect(find.text('App Locked'), findsNothing);

        final editableFields =
            tester.widgetList<EditableText>(find.byType(EditableText)).toList();
        expect(editableFields, isNotEmpty);
        expect(editableFields[0].controller.text, 'Lock Resume Patient');
        expect(editableFields[1].controller.text, '+8801700000001');
        expect(editableFields[2].controller.text, 'lock.resume@example.com');

        final draftAfter = secureStorage['appointment_booking_draft_v1'];
        expect(draftAfter, isNotNull);
        final decodedAfter = jsonDecode(draftAfter!) as Map<String, dynamic>;
        expect(decodedAfter['name'], 'Lock Resume Patient');
        expect(decodedAfter['phone'], '+8801700000001');
        expect(decodedAfter['email'], 'lock.resume@example.com');
      },
      skip: const bool.fromEnvironment('RUN_E2E', defaultValue: false) == false,
    );
  });
}
