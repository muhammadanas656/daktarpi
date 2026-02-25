import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://zaxwypsexokpnbtgasoh.supabase.co',
    anonKey: 'sb_publishable_i-sv4vhvJXu-szfIikz86g_QF3ZkrFB',
  );
  try {
    await Supabase.instance.client.from('trusted_devices').select().limit(1);
  } catch (e) {
    // ignore: empty_catches
  }
  exit(0);
}
