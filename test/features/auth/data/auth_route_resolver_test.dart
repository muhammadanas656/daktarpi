import 'package:flutter_test/flutter_test.dart';
import 'package:daktarpi/core/constants/app_routes.dart';
import 'package:daktarpi/features/auth/data/auth_route_resolver.dart';

class _FakeAuthRouteStateProvider implements AuthRouteStateProvider {
  @override
  final bool isSignedIn;

  @override
  final bool requiresAal2StepUp;

  @override
  final bool hasCompletedProfileDob;

  const _FakeAuthRouteStateProvider({
    required this.isSignedIn,
    required this.requiresAal2StepUp,
    required this.hasCompletedProfileDob,
  });
}

void main() {
  group('AuthRouteResolver', () {
    test('routes unauthenticated users to login', () {
      final resolver = AuthRouteResolver(
        const _FakeAuthRouteStateProvider(
          isSignedIn: false,
          requiresAal2StepUp: false,
          hasCompletedProfileDob: false,
        ),
      );

      expect(resolver.resolvePostAuthRoute(), AppRoutes.login);
    });

    test('routes signed-in AAL1 users with 2FA enabled to verify-2fa', () {
      final resolver = AuthRouteResolver(
        const _FakeAuthRouteStateProvider(
          isSignedIn: true,
          requiresAal2StepUp: true,
          hasCompletedProfileDob: true,
        ),
      );

      expect(resolver.resolvePostAuthRoute(), AppRoutes.verify2fa);
    });

    test('routes signed-in users without dob to profile edit', () {
      final resolver = AuthRouteResolver(
        const _FakeAuthRouteStateProvider(
          isSignedIn: true,
          requiresAal2StepUp: false,
          hasCompletedProfileDob: false,
        ),
      );

      expect(resolver.resolvePostAuthRoute(), AppRoutes.profileEdit);
    });

    test('routes signed-in AAL2 users with profile complete to home', () {
      final resolver = AuthRouteResolver(
        const _FakeAuthRouteStateProvider(
          isSignedIn: true,
          requiresAal2StepUp: false,
          hasCompletedProfileDob: true,
        ),
      );

      expect(resolver.resolvePostAuthRoute(), AppRoutes.home);
    });
  });
}
