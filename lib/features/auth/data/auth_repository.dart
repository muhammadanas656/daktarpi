import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralised authentication repository.
///
/// Wraps all Supabase Auth calls so that no screen/service talks
/// to `Supabase.instance.client.auth` directly.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ─── Current User ──────────────────────────────────────────

  /// Returns the current authenticated user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// Convenience: returns just the user ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Whether the user is currently signed in.
  bool get isSignedIn => _client.auth.currentUser != null;

  // ─── Auth Actions ──────────────────────────────────────────

  /// Signs up with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
    } catch (e) {
      throw Exception('Sign-up failed: $e');
    }
  }

  /// Signs in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Sign-in failed: $e');
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('AuthRepository: sign-out error: $e');
    }
  }

  /// Updates user metadata (e.g. full_name, dob, phone).
  Future<UserResponse> updateUser(Map<String, dynamic> data) async {
    try {
      return await _client.auth.updateUser(
        UserAttributes(data: data),
      );
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
}
