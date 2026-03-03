import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_refresh_stream.dart';
import '../constants/app_routes.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/verify_2fa_screen.dart';
import '../../features/auth/presentation/models/verify_2fa_route_args.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profileview_screen.dart';
import '../../core/main_wrapper/main_wrapper.dart';

// --- COMMON IMPORTS ---
import '../../features/common/presentation/screens/enable_location_screen.dart'; // Assume moved or check

// --- NEW IMPORTS: Privacy Policy & Appointments ---
import '../../features/menu/presentation/screens/privacy_policy_screen.dart';
import '../../features/menu/presentation/screens/settings_screen.dart';
import '../../features/support/presentation/screens/help_center_screen.dart';
import '../../features/legal/presentation/screens/terms_of_service_screen.dart';
import '../../features/appointments/presentation/screens/my_appointments_screen.dart';
import '../../features/appointments/presentation/screens/appointment_confirmation_screen.dart';
import '../../features/appointments/presentation/screens/patient_details_screen.dart';
import '../../features/appointments/presentation/screens/dummy_payment_screen.dart';
import '../../features/appointments/presentation/models/booking_route_args.dart';
import '../../features/menu/presentation/screens/linked_accounts_screen.dart';

// --- DOCTOR SCREENS ---
import '../../features/doctors/presentation/screens/popular_doctors_screen.dart';
import '../../features/doctors/presentation/screens/featured_doctors_screen.dart';
import '../../features/doctors/presentation/screens/doctor_details_screen.dart';
import '../../features/doctors/presentation/screens/specialty_doctors_screen.dart';
import '../../features/doctors/presentation/screens/clinic_doctors_screen.dart';
import '../../features/doctors/presentation/screens/doctors_screen.dart';
import '../../features/doctors/presentation/models/doctors_route_args.dart';
import '../../features/doctors/presentation/screens/my_doctors_screen.dart';
import '../../features/medical_records/presentation/screens/medical_records_screen.dart';
import '../../features/medical_records/presentation/screens/add_record_screen.dart';
import '../../features/medical_records/data/medical_record.dart';
import '../../features/medical_records/presentation/models/medical_record_route_args.dart';

// --- NAVIGATOR KEYS ---
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final _shellNavigatorDoctorsKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellDoctors',
);
final _shellNavigatorAppointmentsKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellAppointments',
);
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellProfile',
);

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final loc = state.matchedLocation;
    final isGoingToAuthScreen =
        loc == AppRoutes.login ||
        loc == AppRoutes.signup ||
        loc == AppRoutes.splash ||
        loc == AppRoutes.verify2fa;

    final isSignedIn = Supabase.instance.client.auth.currentSession != null;

    if (!isSignedIn && !isGoingToAuthScreen) {
      final target = state.uri.toString();
      return '${AppRoutes.login}?from=${Uri.encodeComponent(target)}';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder:
          (context, state) =>
              LoginScreen(intendedRoute: state.uri.queryParameters['from']),
    ),
    GoRoute(
      path: AppRoutes.signup,
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: AppRoutes.verify2fa,
      builder: (context, state) {
        final extra = state.extra;
        final args =
            extra is Verify2FARouteArgs ? extra : const Verify2FARouteArgs();
        return Verify2FAScreen(routeArgs: args);
      },
    ),

    GoRoute(
      path: AppRoutes.privacyPolicy,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),

    GoRoute(
      path: AppRoutes.settings,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),

    GoRoute(
      path: AppRoutes.linkedAccounts,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LinkedAccountsScreen(),
    ),

    GoRoute(
      path: AppRoutes.helpCenter,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HelpCenterScreen(),
    ),

    GoRoute(
      path: AppRoutes.termsOfService,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TermsOfServiceScreen(),
    ),

    GoRoute(
      path: AppRoutes.locationPermission,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EnableLocationScreen(),
    ),

    GoRoute(
      path: AppRoutes.popularDoctors,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PopularDoctorsScreen(),
    ),

    GoRoute(
      path: AppRoutes.featuredDoctors,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FeaturedDoctorsScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.doctorDetails}/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final doctorId = state.pathParameters['id']!;
        return DoctorDetailsScreen(doctorId: doctorId);
      },
    ),

    GoRoute(
      path: AppRoutes.appointmentBooking,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as AppointmentBookingArgs;
        return PatientDetailsScreen(
          doctor: extra.doctor,
          clinic: extra.clinic,
          initialDate: extra.initialDate,
          timeSlot: extra.timeSlot,
          idempotencyKey: extra.idempotencyKey,
        );
      },
    ),

    GoRoute(
      path: AppRoutes.paymentMethod,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as PaymentMethodArgs;
        return AppointmentConfirmationScreen(
          doctor: extra.doctor,
          clinic: extra.clinic,
          patientDetails: extra.patientDetails,
          initialDate: extra.appointmentDate,
          appointmentId: extra.appointmentId,
          timeSlot: extra.timeSlot,
          idempotencyKey: extra.idempotencyKey,
        );
      },
    ),

    GoRoute(
      path: AppRoutes.dummyPayment,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as DummyPaymentRouteArgs;
        return DummyPaymentScreen(args: extra);
      },
    ),

    GoRoute(
      path: '${AppRoutes.specialtyDoctors}/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as SpecialtyRouteArgs?;
        final name = extra?.name ?? 'Doctors';
        return SpecialtyDoctorsScreen(specialtyId: id, specialtyName: name);
      },
    ),

    GoRoute(
      path: '${AppRoutes.clinicDoctors}/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as ClinicRouteArgs?;
        final name = extra?.name ?? 'Clinic Doctors';
        return ClinicDoctorsScreen(clinicId: int.parse(id), clinicName: name);
      },
    ),

    GoRoute(
      path: AppRoutes.myDoctors,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MyDoctorsScreen(),
    ),

    GoRoute(
      path: AppRoutes.medicalRecords,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MedicalRecordsScreen(),
    ),
    GoRoute(
      path: AppRoutes.addMedicalRecord,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final args =
            extra is MedicalRecordRouteArgs
                ? extra
                : extra is MedicalRecord
                ? MedicalRecordRouteArgs(record: extra)
                : const MedicalRecordRouteArgs();
        return AddRecordScreen(recordToEdit: args.record);
      },
    ),

    // 3. SHELL ROUTE (Bottom Navigation)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainWrapper(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorDoctorsKey,
          routes: [
            GoRoute(
              path: AppRoutes.doctors,
              builder: (context, state) => const DoctorsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAppointmentsKey,
          routes: [
            GoRoute(
              path: AppRoutes.appointments,
              builder: (context, state) => const MyAppointmentsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileViewScreen(),
              routes: [
                GoRoute(
                  path: 'edit',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
