import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class OfflineModeGuard extends StatefulWidget {
  final Widget child;

  const OfflineModeGuard({super.key, required this.child});

  @override
  State<OfflineModeGuard> createState() => _OfflineModeGuardState();
}

class _OfflineModeGuardState extends State<OfflineModeGuard> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _subscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateOfflineState,
    );
  }

  Future<void> _initConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    _updateOfflineState(current);
  }

  void _updateOfflineState(dynamic result) {
    final bool isOffline;
    if (result is ConnectivityResult) {
      isOffline = result == ConnectivityResult.none;
    } else if (result is List<ConnectivityResult>) {
      isOffline = !result.any((value) => value != ConnectivityResult.none);
    } else {
      isOffline = false;
    }

    if (!mounted || _isOffline == isOffline) {
      return;
    }
    setState(() => _isOffline = isOffline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          height: _isOffline ? 40 : 0,
          width: double.infinity,
          color: const Color(0xFFF8C146),
          alignment: Alignment.center,
          child:
              _isOffline
                  ? const Text(
                    'Offline Mode: Viewing cached records.',
                    style: TextStyle(
                      color: Color(0xFF3A2A00),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                  : null,
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
