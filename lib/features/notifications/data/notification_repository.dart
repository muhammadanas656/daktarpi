import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/network_notifier.dart';

class NotificationRepository {
  static const String _boxName = 'notifications_box';
  static const String _keyPrefix = 'notifs_';

  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  /// Fetches fresh data from Supabase, caches it locally, and returns it.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = _userId;
    if (userId == null) return [];

    final box = await _getBox();
    final cacheKey = '$_keyPrefix$userId';

    // 1. Try to fetch fresh from Supabase
    if (!NetworkNotifier.instance.isOffline) {
      try {
        final response = await _client
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        
        // Map the Supabase response back to our frontend format
        final List<Map<String, dynamic>> remoteList = (response as List).map((row) => {
          'id': row['id'],
          'title': row['title'],
          'body': row['body'],
          'timestamp': row['created_at'],
          'is_read': row['is_read'],
          'payload': row['payload'],
          'message_id': row['message_id'],
        }).toList();

        // Update the local Hive cache
        await box.put(cacheKey, remoteList);
        return remoteList;
      } catch (e) {
        // Silently fallback to local cache if network fails
      }
    }

    // 2. Fallback to local cache for offline viewing
    final List<dynamic>? rawList = box.get(cacheKey);
    if (rawList == null) return [];
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Saves the list locally (for immediate UI updates and offline cache)
  Future<void> saveLocalCache(List<Map<String, dynamic>> notifications) async {
    final userId = _userId;
    if (userId == null) return;
    final box = await _getBox();
    await box.put('$_keyPrefix$userId', notifications);
  }

  // --- SUPABASE SYNC METHODS ---

  Future<void> insertRemote(Map<String, dynamic> notif) async {
    final userId = _userId;
    if (userId == null || NetworkNotifier.instance.isOffline) return;
    try {
      await _client.from('notifications').insert({
        'id': notif['id'], // We send our generated UUID to Supabase
        'user_id': userId,
        'title': notif['title'],
        'body': notif['body'],
        'created_at': notif['timestamp'],
        'is_read': notif['is_read'] ?? false,
        'payload': notif['payload'],
        'message_id': notif['message_id'],
      });
    } catch (_) {}
  }

  Future<void> updateReadStatusRemote(String id, bool isRead) async {
     if (NetworkNotifier.instance.isOffline) return;
     try {
       await _client.from('notifications').update({'is_read': isRead}).eq('id', id);
     } catch (_) {}
  }

  Future<void> markAllReadRemote() async {
     final userId = _userId;
     if (userId == null || NetworkNotifier.instance.isOffline) return;
     try {
       await _client.from('notifications')
           .update({'is_read': true})
           .eq('user_id', userId)
           .eq('is_read', false);
     } catch (_) {}
  }

  Future<void> deleteRemote(String id) async {
     if (NetworkNotifier.instance.isOffline) return;
     try {
       await _client.from('notifications').delete().eq('id', id);
     } catch (_) {}
  }
}