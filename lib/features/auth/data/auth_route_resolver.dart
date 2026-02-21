import '../../../core/constants/app_routes.dart';
import 'auth_repository.dart';

abstract class AuthRouteStateProvider {
  bool get isSignedIn;
  bool get requiresAal2StepUp;
  bool get hasCompletedProfileDob;
}

class AuthRepositoryRouteProvider implements AuthRouteStateProvider {
  final AuthRepository _authRepository;

  AuthRepositoryRouteProvider(this._authRepository);

  @override
  bool get isSignedIn => _authRepository.isSignedIn;

  @override
  bool get requiresAal2StepUp => _authRepository.requiresAal2StepUp;

  @override
  bool get hasCompletedProfileDob => _authRepository.hasCompletedProfileDob;
}

class AuthRouteResolver {
  final AuthRouteStateProvider _authState;

  AuthRouteResolver(this._authState);

  String resolvePostAuthRoute() {
    if (!_authState.isSignedIn) {
      return AppRoutes.login;
    }

    if (_authState.requiresAal2StepUp) {
      return AppRoutes.verify2fa;
    }

    if (!_authState.hasCompletedProfileDob) {
      return AppRoutes.profileEdit;
    }

    return AppRoutes.home;
  }
}
