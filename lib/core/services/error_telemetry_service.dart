import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorTelemetryService {
  ErrorTelemetryService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const _edgeFunctionName = 'client-error-log';

  Future<void> logFlutterError(
    FlutterErrorDetails details, {
    String source = 'flutter_error',
  }) {
    return logError(
      details.exception,
      details.stack ?? StackTrace.empty,
      source: source,
      context: details.context?.toDescription(),
      library: details.library,
    );
  }

  Future<void> logError(
    Object error,
    StackTrace stackTrace, {
    String source = 'unhandled',
    String? context,
    String? library,
  }) async {
    final payload = <String, dynamic>{
      'source': source,
      'message': _trim(error.toString(), 1000),
      'stack_trace': _trim(stackTrace.toString(), 6000),
      'context': _trim(context, 300),
      'library': _trim(library, 120),
      'platform': defaultTargetPlatform.name,
      'build_mode':
          kReleaseMode
              ? 'release'
              : kProfileMode
              ? 'profile'
              : 'debug',
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client.functions.invoke(_edgeFunctionName, body: payload);
    } catch (_) {
      // Never throw from the telemetry path.
    }
  }

  String? _trim(String? value, int maxLength) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value.length <= maxLength
        ? value
        : '${value.substring(0, maxLength)}...';
  }
}
