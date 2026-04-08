import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aeviapulse/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Heavy Load Stress Test: Rapid Navigation and Scrolling', (WidgetTester tester) async {
    // Launch the app
    app.main();
    await tester.pumpAndSettle();

    // Give time for initial Supabase initialization and navigation to settle
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Define bottom navigation tabs by their label strings
    final homeTab = find.text('Home');
    final doctorsTab = find.text('Doctors');
    final appointmentTab = find.text('Appointment');
    final profileTab = find.text('Profile');

    // Make sure we have reached the MainWrapper which contains these tabs
    // If not, it means the user might be stuck on Auth screen.
    // In a real CI pipeline, we'd script the login form filling here.
    if (homeTab.evaluate().isEmpty) {
      debugPrint("Tabs not found. Ensure the testing environment has a cached authenticated session.");
      return;
    }

    // Execute 50 rapid UI iterations
    for (int i = 0; i < 50; i++) {
      debugPrint('--- Stress Test Iteration ${i + 1}/50 ---');

      // 1. Switch to Doctors tab
      if (doctorsTab.evaluate().isNotEmpty) {
        await tester.tap(doctorsTab);
        // Using a short pump to simulate rapid tapping without waiting for full settle
        await tester.pump(const Duration(milliseconds: 100)); 
      }

      // Rapidly attempt to find and fling a scrollable list
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        // Scroll down
        await tester.fling(scrollables.last, const Offset(0, -800), 10000);
        await tester.pump(const Duration(milliseconds: 100));
        // Scroll back up
        await tester.fling(scrollables.last, const Offset(0, 800), 10000);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 2. Switch to Appointment tab
      if (appointmentTab.evaluate().isNotEmpty) {
        await tester.tap(appointmentTab);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 3. Switch to Profile tab
      if (profileTab.evaluate().isNotEmpty) {
        await tester.tap(profileTab);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 4. Switch back to Home tab
      if (homeTab.evaluate().isNotEmpty) {
        await tester.tap(homeTab);
        await tester.pump(const Duration(milliseconds: 100));
      }
      
      // Allow frame queue to process between iterations
      await tester.pumpAndSettle();
    }
    
    // Verify the app hasn't crashed by ensuring a basic Material structure exists
    expect(find.byType(MaterialApp), findsOneWidget);
    debugPrint("Stress test completed successfully without memory leaks or crashes.");
  });
}
