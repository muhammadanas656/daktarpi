import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void checkProfileAndNavigate(BuildContext context) {
  final user = Supabase.instance.client.auth.currentUser;

  if (user != null) {
    final metadata = user.userMetadata;

    // Check if critical data is missing (e.g., DOB or Phone)
    // You can add more checks here (e.g. metadata?['full_name'] == null)
    final hasDob =
        metadata?['dob'] != null && metadata!['dob'].toString().isNotEmpty;
    final hasPhone =
        metadata?['phone'] != null && metadata!['phone'].toString().isNotEmpty;

    if (!hasDob || !hasPhone) {
      // Data missing -> Force Profile Setup
      context.go('/profile');
    } else {
      // Data exists -> Go Home
      context.go('/home');
    }
  }
}
