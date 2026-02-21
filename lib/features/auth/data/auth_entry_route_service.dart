import '../../../core/constants/app_routes.dart';
import 'auth_repository.dart';
import 'auth_route_resolver.dart';
import 'trusted_device_repository.dart';

/// Resolves initial/post-auth navigation while honoring trusted-device bypass.
class AuthEntryRouteService {
  final AuthRepository _authRepository;
  final TrustedDeviceRepository _trustedDeviceRepository;

  AuthEntryRouteService({
    AuthRepository? authRepository,
    TrustedDeviceRepository? trustedDeviceRepository,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _trustedDeviceRepository =
           trustedDeviceRepository ?? TrustedDeviceRepository();

  Future<String> resolvePostAuthRoute() async {
    final route =
        AuthRouteResolver(
          AuthRepositoryRouteProvider(_authRepository),
        ).resolvePostAuthRoute();

    if (route != AppRoutes.verify2fa) {
      return route;
    }

    final userId = _authRepository.currentUserId;
    if (userId == null) {
      return AppRoutes.login;
    }

    final trusted = await _trustedDeviceRepository.isTrustedDeviceValid(
      userId: userId,
    );
    if (!trusted) {
      return route;
    }

    return _authRepository.hasCompletedProfileDob
        ? AppRoutes.home
        : AppRoutes.profileEdit;
  }
}
