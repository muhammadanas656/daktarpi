import 'dart:io';

import 'package:daktarpi/core/errors/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AppFailure.fromError', () {
    test('maps SocketException to network failure', () {
      final failure = AppFailure.fromError(
        const SocketException('No route to host'),
        fallbackUserMessage: 'Fallback',
      );

      expect(failure.type, AppFailureType.network);
      expect(failure.userMessage, contains('No internet connection'));
      expect(failure.code, 'network_unreachable');
    });

    test('maps AuthException to auth failure', () {
      final failure = AppFailure.fromError(
        const AuthException('Invalid login credentials', statusCode: '400'),
        fallbackUserMessage: 'Fallback',
      );

      expect(failure.type, AppFailureType.auth);
      expect(failure.userMessage, 'Invalid email or password.');
      expect(failure.code, '400');
    });

    test('maps AAL2 requirement auth errors to requiresRecentMfa', () {
      final failure = AppFailure.fromError(
        const AuthException(
          'AAL2 is required to complete this request',
          statusCode: '400',
        ),
        fallbackUserMessage: 'Fallback',
      );

      expect(failure.type, AppFailureType.auth);
      expect(failure.code, 'requires_recent_mfa');
      expect(failure.isRequiresRecentMfa, isTrue);
    });

    test('maps unknown error to fallback', () {
      final failure = AppFailure.fromError(
        StateError('unexpected'),
        fallbackUserMessage: 'Something went wrong.',
      );

      expect(failure.type, AppFailureType.unknown);
      expect(failure.userMessage, 'Something went wrong.');
      expect(failure.code, 'unknown');
    });
  });
}
