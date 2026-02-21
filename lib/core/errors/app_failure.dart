import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AppFailureType { auth, network, permission, validation, backend, unknown }

class AppFailure implements Exception {
  final AppFailureType type;
  final String userMessage;
  final String technicalMessage;
  final String? code;

  const AppFailure({
    required this.type,
    required this.userMessage,
    required this.technicalMessage,
    this.code,
  });

  factory AppFailure.requiresRecentMfa({String? technicalMessage}) {
    return AppFailure(
      type: AppFailureType.auth,
      userMessage:
          'Please verify with your authenticator to continue this security change.',
      technicalMessage:
          technicalMessage ?? 'Sensitive action blocked: recent MFA required.',
      code: 'requires_recent_mfa',
    );
  }

  bool get isRequiresRecentMfa => code == 'requires_recent_mfa';

  factory AppFailure.fromError(
    Object error, {
    required String fallbackUserMessage,
    String? fallbackCode,
  }) {
    if (error is AppFailure) {
      return error;
    }

    if (error is SocketException || error is TimeoutException) {
      return AppFailure(
        type: AppFailureType.network,
        userMessage:
            'No internet connection. Check your network and try again.',
        technicalMessage: error.toString(),
        code: 'network_unreachable',
      );
    }

    if (error is AuthException) {
      final raw = error.message.toLowerCase();
      if (raw.contains('aal2') ||
          raw.contains('assurance level') ||
          raw.contains('requires aal') ||
          raw.contains('mfa') && raw.contains('required')) {
        return AppFailure.requiresRecentMfa(technicalMessage: error.toString());
      }

      return AppFailure(
        type: AppFailureType.auth,
        userMessage: _authFriendlyMessage(error.message),
        technicalMessage: error.toString(),
        code: error.statusCode,
      );
    }

    if (error is PostgrestException) {
      return AppFailure(
        type: AppFailureType.backend,
        userMessage:
            'We could not complete your request right now. Please try again.',
        technicalMessage: _composePostgrestDetails(error),
        code: error.code,
      );
    }

    if (error is StorageException) {
      return AppFailure(
        type: AppFailureType.backend,
        userMessage: 'File operation failed. Please try again.',
        technicalMessage: error.message,
        code: error.statusCode,
      );
    }

    if (error is FormatException) {
      return AppFailure(
        type: AppFailureType.validation,
        userMessage: 'Received invalid data. Please try again.',
        technicalMessage: error.toString(),
        code: 'invalid_format',
      );
    }

    return AppFailure(
      type: AppFailureType.unknown,
      userMessage: fallbackUserMessage,
      technicalMessage: error.toString(),
      code: fallbackCode ?? 'unknown',
    );
  }

  static String _authFriendlyMessage(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (msg.contains('too many requests')) {
      return 'Too many attempts. Please wait and try again.';
    }
    return 'Authentication failed. Please try again.';
  }

  static String _composePostgrestDetails(PostgrestException error) {
    final details = error.details?.toString();
    final hint = error.hint?.toString();
    final parts = <String>[
      error.message,
      if (details != null && details.isNotEmpty) details,
      if (hint != null && hint.isNotEmpty) hint,
    ];
    return parts.join(' | ');
  }

  @override
  String toString() => userMessage;
}
