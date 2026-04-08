import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aeviapulse/main.dart' as app;
import 'package:aeviapulse/core/constants/app_routes.dart';
import 'package:aeviapulse/core/router/app_router.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> loginWith2faUser(WidgetTester tester) async {
    const email = String.fromEnvironment('E2E_EMAIL', defaultValue: '');
    const password = String.fromEnvironment('E2E_PASSWORD', defaultValue: '');
    const totp = String.fromEnvironment('E2E_TOTP', defaultValue: '');

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
    expect(
      totp.length,
      6,
      reason:
          'E2E_TOTP is required for this flow. Run with --dart-define=E2E_TOTP=<6-digit-code>',
    );

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.textContaining('Welcome back'), findsWidgets);

    await tester.enterText(find.byType(EditableText).first, email);
    await tester.enterText(find.byType(EditableText).at(1), password);
    await tester.tap(find.text('Login').first);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }

  group('Auth -> 2FA -> Medical Records flow', () {
    testWidgets(
      'logs in, passes 2FA, and loads medical records',
      (tester) async {
        await loginWith2faUser(tester);

        // 1) App must gate to verify-2fa before shell access when AAL1.
        expect(
          find.textContaining('Security Check').evaluate().isNotEmpty ||
              find.textContaining('Account Recovery').evaluate().isNotEmpty,
          isTrue,
        );

        // 2) Negative path: wrong 2FA should keep user on verification surface.
        await tester.enterText(find.byType(EditableText).first, '000000');
        await tester.tap(find.text('Verify').first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(
          find.textContaining('Security Check').evaluate().isNotEmpty ||
              find.textContaining('Account Recovery').evaluate().isNotEmpty,
          isTrue,
        );

        // 3) Enter valid TOTP and verify.
        const totp = String.fromEnvironment('E2E_TOTP', defaultValue: '');
        await tester.enterText(find.byType(EditableText).first, totp);
        await tester.tap(find.text('Verify').first);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // 4) Post-step-up user should now be in shell.
        expect(find.textContaining('Home').evaluate().isNotEmpty, isTrue);

        // 5) Open protected medical records route and assert data surface is reachable.
        appRouter.go(AppRoutes.medicalRecords);
        await tester.pumpAndSettle(const Duration(seconds: 5));

        expect(find.textContaining('Medical Records'), findsWidgets);
        expect(
          find.textContaining('Add a record').evaluate().isNotEmpty ||
              find.textContaining('No Records Found').evaluate().isNotEmpty,
          isTrue,
        );
      },
      skip: const bool.fromEnvironment('RUN_E2E', defaultValue: false) == false,
    );
  });
}
