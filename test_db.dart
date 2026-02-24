import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://zaxwypsexokpnbtgasoh.supabase.co',
    anonKey: 'sb_publishable_i-sv4vhvJXu-szfIikz86g_QF3ZkrFB',
  );
  try {
    await Supabase.instance.client.from('trusted_devices').select().limit(1);
    print('SUCCESS: trusted_devices table exists');
  } catch (e) {
    print('ERROR: $e');
  }
  exit(0);
}
