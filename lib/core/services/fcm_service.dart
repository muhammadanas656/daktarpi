import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/router/app_router.dart';
import '../../features/notifications/presentation/notification_notifier.dart';
import 'appointment_notification_service.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _initialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (!_isSupportedPlatform) return;

    try {
      // 1. Request permission from the user
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ User granted push notification permission');

        await _fetchAndSaveToken();
        await AppointmentNotificationService.instance.requestPermissions();

        _messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToSupabase(newToken);
        });

        // 2. Foreground Messages (App is open)
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('📩 Got a message whilst in the foreground!');
          unawaited(_saveToInbox(message, message.messageId));

          if (message.notification != null) {
            AppointmentNotificationService.instance.showPushNotification(
              title: message.notification!.title ?? 'New Notification',
              body: message.notification!.body ?? '',
              payload: message.data['type'] ?? message.data.toString(),
            );
          }
        });

        // 3. Background Messages (User taps notification from background)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('📩 App opened from background via notification!');
          unawaited(_saveToInbox(message, message.messageId));

          // --- PRO FIX: Route the user based on the FCM data payload! ---
          final payloadStr = message.data['type'] ?? message.data.toString();
          handleNotificationTap(payloadStr);
        });

        // 4. Terminated Messages (User taps notification to cold-boot the app)
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('📩 App opened from terminated state via notification!');
          unawaited(_saveToInbox(initialMessage, initialMessage.messageId));

          // --- PRO FIX: Delay routing slightly so the app has time to draw the first frame! ---
          Future.delayed(const Duration(milliseconds: 500), () {
            final payloadStr =
                initialMessage.data['type'] ?? initialMessage.data.toString();
            handleNotificationTap(payloadStr);
          });
        }
        _initialized = true;
      } else {
        debugPrint('⚠️ User declined push notification permission');
      }
    } catch (e) {
      debugPrint('FcmService.initialize failed: $e');
    }
  }

  // --- Centralized Inbox Saver with FCM deduplication ---
  Future<void> _saveToInbox(RemoteMessage message, String? messageId) async {
    if (message.notification == null) return;

    try {
      final title = message.notification!.title ?? 'New Notification';
      final body = message.notification!.body ?? '';

      await NotificationNotifier.instance.addNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('❌ Failed to save FCM message to inbox: $e');
    }
  }

  Future<void> _fetchAndSaveToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📲 FCM Token: $token');
        await _saveTokenToSupabase(token);
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch FCM token: $e');
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);

      debugPrint('✅ FCM Token securely saved to Supabase');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }
}
