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

  Future<void> initialize() async {
    // 1. Request permission from the user
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted push notification permission');

      await _fetchAndSaveToken();
      await AppointmentNotificationService.instance.requestPermissions();

      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToSupabase(newToken);
      });

      // 2. Foreground Messages (App is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 Got a message whilst in the foreground!');
        _saveToInbox(message); // PRO FIX: Abstracted save logic

        if (message.notification != null) {
          AppointmentNotificationService.instance.showPushNotification(
            title: message.notification!.title ?? 'New Notification',
            body: message.notification!.body ?? '',
            payload: message.data.toString(),
          );
        }
      });

      // 3. Background Messages (User taps notification from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📩 App opened from background via notification!');
        _saveToInbox(message); // PRO FIX: Now it actually saves!

        // --- PRO FIX: Route the user based on the FCM data payload! ---
        final payload = message.data['type'] ?? message.data.toString();
        handleNotificationTap(payload);
      });

      // 4. Terminated Messages (User taps notification to cold-boot the app)
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📩 App opened from terminated state via notification!');
        _saveToInbox(initialMessage); // PRO FIX: Now it actually saves!

        // --- PRO FIX: Delay routing slightly so the app has time to draw the first frame! ---
        Future.delayed(const Duration(milliseconds: 500), () {
          final payload =
              initialMessage.data['type'] ?? initialMessage.data.toString();
          handleNotificationTap(payload);
        });
      }
    } else {
      debugPrint('⚠️ User declined push notification permission');
    }
  }

  // --- PRO FIX: Centralized Inbox Saver ---
  void _saveToInbox(RemoteMessage message) {
    if (message.notification != null) {
      final title = message.notification!.title ?? 'New Notification';
      final body = message.notification!.body ?? '';

      NotificationNotifier.instance.addNotification(
        title: title,
        body: body,
        payload: message.data.toString(),
      );
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
