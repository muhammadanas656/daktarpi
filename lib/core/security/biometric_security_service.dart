import 'package:local_auth/local_auth.dart';

import '../errors/app_failure.dart';

/// Service abstraction for biometric capability checks and identity prompts.
class BiometricSecurityService {
  final LocalAuthentication _localAuth;

  BiometricSecurityService({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        return false;
      }
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> verifyBiometricIdentity(String reason) async {
    final available = await isBiometricAvailable();
    if (!available) {
      throw const AppFailure(
        type: AppFailureType.permission,
        userMessage: 'Biometrics are not available on this device.',
        technicalMessage:
            'Biometric verification requested without enrolled biometrics.',
        code: 'biometric_unavailable',
      );
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated) {
        throw AppFailure.biometricRejected();
      }
      return true;
    } catch (error) {
      if (error is AppFailure) {
        rethrow;
      }
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Biometric verification failed.',
        fallbackCode: 'biometric_error',
      );
    }
  }
}
