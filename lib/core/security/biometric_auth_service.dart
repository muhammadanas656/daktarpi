import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth;

  BiometricAuthService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> canUseBiometricUnlock() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canCheck || !supported) {
        return false;
      }

      final biometrics = await _localAuth.getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'Unlock DaktarPai to continue',
  }) async {
    return _localAuth.authenticate(
      localizedReason: localizedReason,
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
      ),
    );
  }
}
