import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';

import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/profileview_screen.dart';
import '../../core/main_wrapper/main_wrapper.dart';

// --- COMMON IMPORTS ---
import '../../features/common/presentation/screens/enable_location_screen.dart'; // Assume moved or check

// --- NEW IMPORTS: Privacy Policy & Appointments ---
import '../../features/menu/presentation/screens/privacy_policy_screen.dart';
import '../../features/appointments/presentation/screens/my_appointments_screen.dart';
import '../../features/appointments/presentation/screens/appointment_confirmation_screen.dart';
import '../../features/appointments/presentation/screens/patient_details_screen.dart';

// --- DOCTOR SCREENS ---
import '../../features/doctors/presentation/screens/popular_doctors_screen.dart';
import '../../features/doctors/presentation/screens/featured_doctors_screen.dart';
import '../../features/doctors/presentation/screens/doctor_details_screen.dart';
import '../../features/doctors/presentation/screens/specialty_doctors_screen.dart';
import '../../features/doctors/presentation/screens/clinic_doctors_screen.dart';
import '../../features/doctors/presentation/screens/doctors_screen.dart';

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
  routes: [
    GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
    GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
    GoRoute(path: AppRoutes.signup, builder: (context, state) => const SignUpScreen()),

    GoRoute(
      path: AppRoutes.privacyPolicy,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PrivacyPolicyScreen(),
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
        final extra = state.extra as Map<String, dynamic>;
        return PatientDetailsScreen(
          doctor: extra['doctor'],
          clinic: extra['clinic'],
          initialDate: extra['initialDate'],
          timeSlot: extra['timeSlot'],
        );
      },
    ),

    GoRoute(
      path: AppRoutes.paymentMethod,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return AppointmentConfirmationScreen(
          doctor: extra['doctor'],
          clinic: extra['clinic'],
          patientDetails: extra['patientDetails'],
          initialDate: extra['appointmentDate'],
          appointmentId: extra['appointmentId'],
          timeSlot: extra['timeSlot'],
        );
      },
    ),

    GoRoute(
      path: '${AppRoutes.specialtyDoctors}/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        final name = extra?['name'] as String? ?? 'Doctors';
        return SpecialtyDoctorsScreen(specialtyId: id, specialtyName: name);
      },
    ),

    GoRoute(
      path: '${AppRoutes.clinicDoctors}/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        final name = extra?['name'] as String? ?? 'Clinic Doctors';
        return ClinicDoctorsScreen(clinicId: int.parse(id), clinicName: name);
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
