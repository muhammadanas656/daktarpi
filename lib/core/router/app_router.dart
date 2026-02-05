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

// --- MAKE SURE THESE FILES EXIST AND ARE IMPORTED ---
import '../../features/doctors/popular_doctors_screen.dart';
import '../../features/doctors/feature_doctors_screen.dart';

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

    // 2. "SEE ALL" ROUTES (These must exist here to fix your error)
    GoRoute(
      path: '/popular_doctors',
      parentNavigatorKey: _rootNavigatorKey, // Covers bottom bar
      builder: (context, state) => const PopularDoctorsScreen(),
    ),
    GoRoute(
      path: '/feature_doctors',
      parentNavigatorKey: _rootNavigatorKey, // Covers bottom bar
      builder: (context, state) => const FeatureDoctorsScreen(),
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
