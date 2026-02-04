import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/profile/profile_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
