import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  final LocalAuthentication _localAuth;

  BiometricAuthService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> canUseBiometricUnlock() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    return canCheck && supported;
  }

  Future<bool> authenticate() async {
    return _localAuth.authenticate(
      localizedReason: 'Unlock DaktarPai to continue',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
      ),
    );
  }
}
