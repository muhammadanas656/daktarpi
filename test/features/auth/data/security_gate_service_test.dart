import 'package:flutter_test/flutter_test.dart';
import 'package:daktarpi/features/auth/data/security_gate_service.dart';

class _FakeSecurityAuthProvider implements SecurityAuthProvider {
  @override
  bool isSignedIn;

  @override
  bool requiresAal2StepUp;

  bool totpVerified = false;
  bool refreshed = false;
  bool recoveryWillSucceed = false;

  _FakeSecurityAuthProvider({
    required this.isSignedIn,
    required this.requiresAal2StepUp,
  });

  @override
  Future<void> refreshSession() async {
    refreshed = true;
  }

  @override
  Future<bool> useRecoveryCode(String code) async {
    return recoveryWillSucceed;
  }

  @override
  Future<void> verifyTotpCode(String code) async {
    totpVerified = true;
  }
}

void main() {
  group('SecurityGateService', () {
    test('returns unauthenticated when user is not signed in', () {
      final provider = _FakeSecurityAuthProvider(
        isSignedIn: false,
        requiresAal2StepUp: false,
      );
      final service = SecurityGateService(authProvider: provider);

      final decision = service.evaluateAal2Gate();

      expect(decision.isUnauthenticated, isTrue);
    });

    test('returns requiresStepUp when AAL2 step-up is required', () {
      final provider = _FakeSecurityAuthProvider(
        isSignedIn: true,
        requiresAal2StepUp: true,
      );
      final service = SecurityGateService(authProvider: provider);

      final decision = service.evaluateAal2Gate();

      expect(decision.needsStepUp, isTrue);
    });

    test('returns allow when signed in and AAL2 not required', () {
      final provider = _FakeSecurityAuthProvider(
        isSignedIn: true,
        requiresAal2StepUp: false,
      );
      final service = SecurityGateService(authProvider: provider);

      final decision = service.evaluateAal2Gate();

      expect(decision.isAllowed, isTrue);
    });

    test('verifyWithTotp verifies and refreshes session', () async {
      final provider = _FakeSecurityAuthProvider(
        isSignedIn: true,
        requiresAal2StepUp: true,
      );
      final service = SecurityGateService(authProvider: provider);

      await service.verifyWithTotp('123456');

      expect(provider.totpVerified, isTrue);
      expect(provider.refreshed, isTrue);
    });

    test('verifyWithRecoveryCode refreshes session only on success', () async {
      final provider = _FakeSecurityAuthProvider(
        isSignedIn: true,
        requiresAal2StepUp: true,
      );
      final service = SecurityGateService(authProvider: provider);

      provider.recoveryWillSucceed = false;
      final first = await service.verifyWithRecoveryCode('ABCD-1234');
      expect(first, isFalse);
      expect(provider.refreshed, isFalse);

      provider.recoveryWillSucceed = true;
      final second = await service.verifyWithRecoveryCode('WXYZ-9999');
      expect(second, isTrue);
      expect(provider.refreshed, isTrue);
    });
  });
}
