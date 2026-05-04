import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/network_notifier.dart';

class NotificationRepository {
  static const String _boxName = 'notifications_box';
  static const String _keyPrefix = 'notifs_';
  static const String _unsyncedKey = 'unsynced_notifs';

  final SupabaseClient _client = Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  // ─── UNSYNCED QUEUE (for background isolate entries) ────────────────────────

  /// Adds a notification to the unsynced queue (called from background isolate).
  Future<void> addToUnsyncedQueue(Map<String, dynamic> notif) async {
    final box = await _getBox();
    final List<dynamic> queue = box.get(_unsyncedKey) ?? [];
    queue.add(notif);
    await box.put(_unsyncedKey, queue);
  }

  /// Syncs all unsynced entries to Supabase and clears the queue.
  /// Called BEFORE fetching from Supabase so the remote list includes them.
  Future<void> _syncUnsyncedQueue() async {
    final userId = _userId;
    if (userId == null || NetworkNotifier.instance.isOffline) return;

    final box = await _getBox();
    final List<dynamic>? queue = box.get(_unsyncedKey);
    if (queue == null || queue.isEmpty) return;

    final entries = queue.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    for (int i = 0; i < entries.length; i++) {
      try {
        await _client.from('notifications').upsert({
          'id': entries[i]['id'],
          'user_id': userId,
          'title': entries[i]['title'],
          'body': entries[i]['body'],
          'created_at': entries[i]['timestamp'],
          'is_read': entries[i]['is_read'] ?? false,
          'payload': entries[i]['payload'],
          'message_id': entries[i]['message_id'],
        }, onConflict: 'id');
        // Mark as synced by removing from the list
        entries.removeAt(i);
        i--; // Adjust index after removal
      } catch (e) {
        debugPrint('❌ Failed to sync unsynced notification: $e');
        // Continue with next entry instead of returning
      }
    }

    // Update the queue with only the entries that failed
    if (entries.isEmpty) {
      await box.delete(_unsyncedKey);
      debugPrint('✅ All background notifications synced to Supabase');
    } else {
      await box.put(_unsyncedKey, entries);
      debugPrint('⚠️ ${entries.length} notifications still unsynced');
    }
  }

  // ─── MAIN FETCH ─────────────────────────────────────────────────────────────

  /// Supabase is the SINGLE SOURCE OF TRUTH.
  /// 1. Sync any background-isolate entries UP to Supabase first.
  /// 2. Fetch from Supabase and REPLACE the Hive cache entirely.
  /// 3. Fallback to Hive only when offline.
  Future<List<Map<String, dynamic>>> getNotifications() async {
    final userId = _userId;
    if (userId == null) return [];

    final box = await _getBox();
    final cacheKey = '$_keyPrefix$userId';

    // 1. Try to fetch fresh from Supabase
    if (!NetworkNotifier.instance.isOffline) {
      try {
        // Step A: Push any unsynced background entries to Supabase FIRST
        await _syncUnsyncedQueue();

        // Step B: Fetch the canonical list from Supabase
        final response = await _client
            .from('notifications')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        
        // Map the Supabase response back to our frontend format
        final List<Map<String, dynamic>> remoteList = (response as List).map((row) => <String, dynamic>{
          'id': row['id'],
          'title': row['title'],
          'body': row['body'],
          'timestamp': row['created_at'],
          'is_read': row['is_read'],
          'payload': row['payload'],
          'message_id': row['message_id'],
        }).toList();

        // Step C: Merge any STILL-unsynced entries into the list for display
        final List<dynamic>? remainingUnsynced = box.get(_unsyncedKey);
        if (remainingUnsynced != null && remainingUnsynced.isNotEmpty) {
          final remoteIds = remoteList.map((r) => r['id']).toSet();
          for (final item in remainingUnsynced) {
            final map = Map<String, dynamic>.from(item as Map);
            if (!remoteIds.contains(map['id'])) {
              remoteList.add(map);
            }
          }
          remoteList.sort((a, b) =>
              DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
        }

        // Step D: Replace local cache with the merged truth
        await box.put(cacheKey, remoteList);
        return remoteList;
      } catch (e) {
        debugPrint('⚠️ getNotifications remote fetch failed: $e');
        // Silently fallback to local cache if network fails
      }
    }

    // 2. Offline: return local cache + any unsynced entries merged together
    final List<dynamic>? rawList = box.get(cacheKey);
    final List<dynamic>? unsyncedQueue = box.get(_unsyncedKey);

    final List<Map<String, dynamic>> result = [];
    if (rawList != null) {
      result.addAll(rawList.map((e) => Map<String, dynamic>.from(e as Map)));
    }
    if (unsyncedQueue != null && unsyncedQueue.isNotEmpty) {
      final existingIds = result.map((e) => e['id']).toSet();
      for (final item in unsyncedQueue) {
        final map = Map<String, dynamic>.from(item as Map);
        if (!existingIds.contains(map['id'])) {
          result.add(map);
        }
      }
      result.sort((a, b) =>
          DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
    }
    return result;
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
    if (userId == null) return;

    // If offline, queue for later sync instead of silently dropping
    if (NetworkNotifier.instance.isOffline) {
      await addToUnsyncedQueue(notif);
      return;
    }

    try {
      await _client.from('notifications').upsert({
        'id': notif['id'],
        'user_id': userId,
        'title': notif['title'],
        'body': notif['body'],
        'created_at': notif['timestamp'],
        'is_read': notif['is_read'] ?? false,
        'payload': notif['payload'],
        'message_id': notif['message_id'],
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('❌ insertRemote failed, queuing for retry: $e');
      // Fallback: add to unsynced queue so it's retried on next fetch
      await addToUnsyncedQueue(notif);
    }
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

  // THE FIX: Bulk Delete for Inbox Zero
  Future<void> deleteAllReadRemote() async {
     final userId = _userId;
     if (userId == null || NetworkNotifier.instance.isOffline) return;
     try {
       await _client.from('notifications')
           .delete()
           .eq('user_id', userId)
           .eq('is_read', true);
     } catch (_) {}
  }
}
