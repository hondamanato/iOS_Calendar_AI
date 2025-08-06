import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_event.dart';
import '../models/chat_message.dart';
import '../models/event.dart';
import '../utils/config.dart';
import '../services/local_database_service.dart';

class SupabaseService {
  late final SupabaseClient _client;
  bool _isListening = false;

  SupabaseService() {
    _client = Supabase.instance.client;
  }

  // 接続テスト
  Future<bool> testConnection() async {
    try {
      await _client.from('events').select('count').limit(1);
      return true;
    } catch (e) {
      print('Supabase接続テスト失敗: $e');
      return false;
    }
  }

  // リアルタイム同期の開始（簡略版）
  Future<void> startRealtimeSync() async {
    if (_isListening) return;
    
    try {
      _isListening = true;
      print('リアルタイム同期を開始しました（簡略版）');
    } catch (e) {
      print('リアルタイム同期開始エラー: $e');
      _isListening = false;
    }
  }

  // リアルタイム同期の停止
  void stopRealtimeSync() {
    _isListening = false;
    print('リアルタイム同期を停止しました');
  }

  // 新しいEventクラスを使用したイベントの取得
  Future<List<Event>> getEvents() async {
    try {
      final response = await _client
          .from('events')
          .select()
          .order('start_time');
      
      return response.map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  // 新しいEventクラスを使用したイベントの追加
  Future<void> addEvent(Event event) async {
    try {
      await _client
          .from('events')
          .insert(event.toJson());
      print('Supabaseにイベントを追加: ${event.title}');
    } catch (e) {
      print('Error adding event: $e');
      rethrow;
    }
  }

  // 新しいEventクラスを使用したイベントの更新
  Future<void> updateEvent(Event event) async {
    try {
      await _client
          .from('events')
          .update(event.toJson())
          .eq('id', event.id);
      print('Supabaseでイベントを更新: ${event.title}');
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // 新しいEventクラスを使用したイベントの削除
  Future<void> deleteEvent(String eventId) async {
    try {
      await _client
          .from('events')
          .delete()
          .eq('id', eventId);
      print('Supabaseでイベントを削除: $eventId');
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // 特定の日付範囲のイベントを取得
  Future<List<Event>> getEventsByDateRange(DateTime start, DateTime end) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .gte('start_time', start.toIso8601String())
          .lte('end_time', end.toIso8601String())
          .order('start_time');
      
      return response.map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching events by date range: $e');
      return [];
    }
  }

  // ユーザーIDでイベントを取得
  Future<List<Event>> getEventsByUserId(String userId) async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('user_id', userId)
          .order('start_time');
      
      return response.map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching events by user ID: $e');
      return [];
    }
  }

  // 同期されていないイベントを取得
  Future<List<Event>> getUnsyncedEvents() async {
    try {
      final response = await _client
          .from('events')
          .select()
          .eq('is_synced_with_google', false)
          .order('created_at');
      
      return response.map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching unsynced events: $e');
      return [];
    }
  }

  // イベントを同期済みとしてマーク
  Future<void> markEventAsSynced(String eventId, String? googleEventId) async {
    try {
      await _client
          .from('events')
          .update({
            'is_synced_with_google': true,
            'google_event_id': googleEventId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventId);
    } catch (e) {
      print('Error marking event as synced: $e');
      rethrow;
    }
  }

  // バッチでイベントを追加
  Future<void> addEventsBatch(List<Event> events) async {
    try {
      final eventsJson = events.map((e) => e.toJson()).toList();
      await _client
          .from('events')
          .insert(eventsJson);
      print('Supabaseにバッチでイベントを追加: ${events.length}件');
    } catch (e) {
      print('Error adding events batch: $e');
      rethrow;
    }
  }

  // バッチでイベントを更新
  Future<void> updateEventsBatch(List<Event> events) async {
    try {
      for (final event in events) {
        await updateEvent(event);
      }
      print('Supabaseでバッチでイベントを更新: ${events.length}件');
    } catch (e) {
      print('Error updating events batch: $e');
      rethrow;
    }
  }

  // ローカルデータベースとSupabaseの同期
  Future<void> syncWithLocalDatabase() async {
    try {
      // ローカルの未同期イベントをSupabaseに送信
      final localEvents = await LocalDatabaseService.getAllEvents();
      final unsyncedEvents = await LocalDatabaseService.getUnsyncedEvents();
      
      if (unsyncedEvents.isNotEmpty) {
        await addEventsBatch(unsyncedEvents);
        for (final event in unsyncedEvents) {
          await LocalDatabaseService.markEventAsSynced(event.id, null);
        }
        print('ローカルからSupabaseへの同期完了: ${unsyncedEvents.length}件');
      }

      // Supabaseから最新のイベントを取得してローカルに同期
      final supabaseEvents = await getEvents();
      for (final event in supabaseEvents) {
        await LocalDatabaseService.insertEvent(event);
      }
      print('Supabaseからローカルへの同期完了: ${supabaseEvents.length}件');
    } catch (e) {
      print('同期エラー: $e');
      rethrow;
    }
  }

  // 競合解決（同じイベントが複数デバイスで編集された場合）
  Future<void> resolveConflicts() async {
    try {
      final localEvents = await LocalDatabaseService.getAllEvents();
      final supabaseEvents = await getEvents();
      
      // ローカルとSupabaseのイベントを比較
      for (final localEvent in localEvents) {
        final supabaseEvent = supabaseEvents.firstWhere(
          (e) => e.id == localEvent.id,
          orElse: () => localEvent,
        );
        
        // 更新日時を比較して競合を解決
        if (localEvent.updatedAt.isAfter(supabaseEvent.updatedAt)) {
          await updateEvent(localEvent);
        } else if (supabaseEvent.updatedAt.isAfter(localEvent.updatedAt)) {
          await LocalDatabaseService.updateEvent(supabaseEvent);
        }
      }
      
      print('競合解決完了');
    } catch (e) {
      print('競合解決エラー: $e');
    }
  }

  // 既存のCalendarEventクラスとの互換性のため
  Future<List<CalendarEvent>> getCalendarEvents() async {
    try {
      final response = await _client
          .from('calendar_events')
          .select()
          .order('start_time');
      
      return response.map((json) => CalendarEvent.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching calendar events: $e');
      return [];
    }
  }

  // 既存のCalendarEventクラスとの互換性のため
  Future<void> addCalendarEvent(CalendarEvent event) async {
    try {
      await _client
          .from('calendar_events')
          .insert(event.toJson());
    } catch (e) {
      print('Error adding calendar event: $e');
      rethrow;
    }
  }

  // 既存のCalendarEventクラスとの互換性のため
  Future<void> updateCalendarEvent(CalendarEvent event) async {
    try {
      await _client
          .from('calendar_events')
          .update(event.toJson())
          .eq('id', event.id);
    } catch (e) {
      print('Error updating calendar event: $e');
      rethrow;
    }
  }

  // 既存のCalendarEventクラスとの互換性のため
  Future<void> deleteCalendarEvent(String eventId) async {
    try {
      await _client
          .from('calendar_events')
          .delete()
          .eq('id', eventId);
    } catch (e) {
      print('Error deleting calendar event: $e');
      rethrow;
    }
  }

  // チャットメッセージの取得
  Future<List<ChatMessage>> getChatMessages() async {
    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .order('timestamp');
      
      return response.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching chat messages: $e');
      return [];
    }
  }

  // チャットメッセージの追加
  Future<void> addChatMessage(ChatMessage message) async {
    try {
      await _client
          .from('chat_messages')
          .insert(message.toJson());
    } catch (e) {
      print('Error adding chat message: $e');
      rethrow;
    }
  }

  // リアルタイムでイベントの変更を監視
  Stream<List<Event>> watchEvents() {
    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .map((response) => response.map((json) => Event.fromJson(json)).toList());
  }

  // リアルタイムでカレンダーイベントの変更を監視
  Stream<List<CalendarEvent>> watchCalendarEvents() {
    return _client
        .from('calendar_events')
        .stream(primaryKey: ['id'])
        .map((response) => response.map((json) => CalendarEvent.fromJson(json)).toList());
  }
} 