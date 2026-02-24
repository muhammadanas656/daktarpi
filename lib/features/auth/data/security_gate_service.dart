import 'auth_repository.dart';

enum SecurityGateStatus { allow, requiresStepUp, unauthenticated }

class SecurityGateDecision {
  final SecurityGateStatus status;

  const SecurityGateDecision._(this.status);

  const SecurityGateDecision.allow() : this._(SecurityGateStatus.allow);

  const SecurityGateDecision.requiresStepUp()
    : this._(SecurityGateStatus.requiresStepUp);

  const SecurityGateDecision.unauthenticated()
    : this._(SecurityGateStatus.unauthenticated);

  bool get isAllowed => status == SecurityGateStatus.allow;
  bool get needsStepUp => status == SecurityGateStatus.requiresStepUp;
  bool get isUnauthenticated => status == SecurityGateStatus.unauthenticated;
}

abstract class SecurityAuthProvider {
  bool get isSignedIn;
  bool get requiresAal2StepUp;

  Future<void> verifyTotpCode(String code);
  Future<bool> useRecoveryCode(String code);
  Future<void> refreshSession();
}

class AuthRepositorySecurityProvider implements SecurityAuthProvider {
  final AuthRepository _authRepository;

  AuthRepositorySecurityProvider(this._authRepository);

  @override
  bool get isSignedIn => _authRepository.isSignedIn;

  @override
  bool get requiresAal2StepUp => _authRepository.requiresAal2StepUp;

  @override
  Future<void> verifyTotpCode(String code) =>
      _authRepository.verifyTotpCode(code);

  @override
  Future<bool> useRecoveryCode(String code) =>
      _authRepository.useRecoveryCode(code);

  @override
  Future<void> refreshSession() => _authRepository.refreshSession();
}

class SecurityGateService {
  final SecurityAuthProvider _authProvider;

  SecurityGateService({required SecurityAuthProvider authProvider})
    : _authProvider = authProvider;

  SecurityGateDecision evaluateAal2Gate() {
    if (!_authProvider.isSignedIn) {
      return const SecurityGateDecision.unauthenticated();
    }

    if (_authProvider.requiresAal2StepUp) {
      return const SecurityGateDecision.requiresStepUp();
    }

    return const SecurityGateDecision.allow();
  }

  Future<void> verifyWithTotp(String code) async {
    await _authProvider.verifyTotpCode(code);
    // Suppressed refreshSession() because challengeAndVerify already promotes AAL on the native channel
  }

  Future<bool> verifyWithRecoveryCode(String code) async {
    final success = await _authProvider.useRecoveryCode(code);
    return success;
  }
}
