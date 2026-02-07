import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- IMPORTS ---
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/profileview_screen.dart';
import '../../core/main_wrapper/main_wrapper.dart';

// --- COMMON IMPORTS ---
import '../../features/common/enable_location_screen.dart'; // <--- NEW IMPORT

// --- DOCTOR SCREENS ---
import '../../features/doctors/popular_doctors_screen.dart';
import '../../features/doctors/feature_doctors_screen.dart';
import '../../features/doctors/doctor_details_screen.dart';
import '../../features/doctors/specialty_doctors_screen.dart';

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
    // 1. PUBLIC ROUTES
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),

    // --- NEW: Location Permission Route ---
    GoRoute(
      path: '/location_permission',
      parentNavigatorKey: _rootNavigatorKey, // Covers bottom bar
      builder: (context, state) => const EnableLocationScreen(),
    ),

    // 2. DOCTOR & DETAILS ROUTES (Cover Bottom Bar)
    GoRoute(
      path: '/popular_doctors',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PopularDoctorsScreen(),
    ),
    GoRoute(
      path: '/feature_doctors',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FeatureDoctorsScreen(),
    ),
    GoRoute(
      path: '/doctor_details/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final doctorId = state.pathParameters['id']!;
        return DoctorDetailsScreen(doctorId: doctorId);
      },
    ),

    // --- Specialty Doctors Route ---
    GoRoute(
      path: '/specialty_doctors/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        final name = extra?['name'] as String? ?? 'Doctors';

        return SpecialtyDoctorsScreen(specialtyId: id, specialtyName: name);
      },
    ),

    // 3. SHELL ROUTE (Bottom Navigation)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainWrapper(navigationShell: navigationShell);
      },
      branches: [
        // HOME
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // DOCTORS
        StatefulShellBranch(
          navigatorKey: _shellNavigatorDoctorsKey,
          routes: [
            GoRoute(
              path: '/doctors',
              builder:
                  (context, state) =>
                      const Scaffold(body: Center(child: Text("Doctors"))),
            ),
          ],
        ),
        // APPOINTMENTS
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAppointmentsKey,
          routes: [
            GoRoute(
              path: '/appointments',
              builder:
                  (context, state) =>
                      const Scaffold(body: Center(child: Text("Appointments"))),
            ),
          ],
        ),
        // PROFILE
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            GoRoute(
              path: '/profile',
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
