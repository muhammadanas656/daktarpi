import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<AuthState> _subscription;
  bool _wasSignedIn = false;

  GoRouterRefreshStream(Stream<AuthState> stream) {
    _wasSignedIn = Supabase.instance.client.auth.currentSession != null;

    _subscription = stream.asBroadcastStream().listen(
      (AuthState authState) async {
        final isSigningOut = _wasSignedIn && authState.session == null;
        _wasSignedIn = authState.session != null;

        if (isSigningOut) {
          await Future.delayed(const Duration(milliseconds: 400));
        }

        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
