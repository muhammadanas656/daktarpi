import 'package:local_auth/local_auth.dart';

/// Lightweight helper for querying enrolled biometric methods.
class BiometricHelperService {
  final LocalAuthentication _localAuth;

  BiometricHelperService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        return const [];
      }
      return _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }
}
