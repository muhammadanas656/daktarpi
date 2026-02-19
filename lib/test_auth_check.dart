import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient('url', 'key');
  await client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: 'token',
    accessToken: 'access',
  );
}
