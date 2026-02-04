import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- IMPORTS ---
// Make sure these paths match your actual file structure
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart'; // Edit Form
import '../../features/profile/profileview_screen.dart'; // Read-Only View (Check file name if it is profileview_screen.dart)
import '../main_wrapper/main_wrapper.dart'; // The Shell Wrapper we created in Step 1

// --- NAVIGATOR KEYS ---
// These are required to control the navigation stack of each tab independently
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
  initialLocation: '/', // Start at Splash Screen
  routes: [
    // ====================================================
    // 1. PUBLIC ROUTES (No Bottom Bar)
    // ====================================================
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),

    // ====================================================
    // 2. AUTHENTICATED SHELL ROUTE (With Bottom Bar)
    // ====================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        // This returns the Scaffold with the BottomNavigationBar
        return MainWrapper(navigationShell: navigationShell);
      },
      branches: [
        // --- BRANCH 1: HOME ---
        StatefulShellBranch(
          navigatorKey: _shellNavigatorHomeKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),

        // --- BRANCH 2: DOCTORS (Placeholder) ---
        StatefulShellBranch(
          navigatorKey: _shellNavigatorDoctorsKey,
          routes: [
            GoRoute(
              path: '/doctors',
              builder:
                  (context, state) => const Scaffold(
                    body: Center(child: Text("Doctors Screen")),
                  ),
            ),
          ],
        ),

        // --- BRANCH 3: APPOINTMENTS (Placeholder) ---
        StatefulShellBranch(
          navigatorKey: _shellNavigatorAppointmentsKey,
          routes: [
            GoRoute(
              path: '/appointments',
              builder:
                  (context, state) => const Scaffold(
                    body: Center(child: Text("Appointments Screen")),
                  ),
            ),
          ],
        ),

        // --- BRANCH 4: PROFILE ---
        StatefulShellBranch(
          navigatorKey: _shellNavigatorProfileKey,
          routes: [
            // 4a. Profile View (Read-Only) - Shows Bottom Bar
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileViewScreen(),
              routes: [
                // 4b. Edit Profile (Form) - HIDES Bottom Bar
                // We use parentNavigatorKey: _rootNavigatorKey to push it *over* the shell
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
