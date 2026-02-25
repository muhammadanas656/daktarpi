import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Check if trusted_devices exists', () async {
    const supabaseUrl = 'https://zaxwypsexokpnbtgasoh.supabase.co';
    const supabaseKey = 'sb_publishable_i-sv4vhvJXu-szfIikz86g_QF3ZkrFB';

    final client = SupabaseClient(supabaseUrl, supabaseKey);

    try {
      await client.from('trusted_devices').select().limit(1);
    } catch (e) {
      fail(e.toString());
    }
  });
}
