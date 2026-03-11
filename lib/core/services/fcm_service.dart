import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/notifications/presentation/notification_notifier.dart';
import 'appointment_notification_service.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    // 1. Request permission from the user (Required for iOS, good practice for Android)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted push notification permission');

      // 2. Fetch the unique device token
      await _fetchAndSaveToken();
      
      // Request local alarm permissions for appointment reminders
      await AppointmentNotificationService.instance.requestPermissions();

      // 3. Listen for token refreshes (in case the device assigns a new one)
      _messaging.onTokenRefresh.listen((newToken) {
        _saveTokenToSupabase(newToken);
      });

      // 4. Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 Got a message whilst in the foreground!');
        
        if (message.notification != null) {
          final title = message.notification!.title ?? 'New Notification';
          final body = message.notification!.body ?? '';

          // Save to local inbox
          NotificationNotifier.instance.addNotification(
            title: title,
            body: body,
          );

          // Show local heads-up notification
          AppointmentNotificationService.instance.showPushNotification(
            title: title,
            body: body,
            payload: message.data.toString(),
          );
        }
      });

      // 5. Listen for when user taps the notification from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📩 App opened from background via notification!');
      });

      // 6. Check if app was opened from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📩 App opened from terminated state via notification!');
      }
    } else {
      debugPrint('⚠️ User declined push notification permission');
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

    // Wrap the 'return' in curly braces to fix the warning
    if (user == null) {
      return;
    }

    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', user.id);

      debugPrint('✅ FCM Token securely saved to Supabase Profiles');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token to Supabase: $e');
    }
  }
}
