import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../models/event.dart';
import '../services/supabase_service.dart';
import '../services/google_calendar_service.dart';
import '../services/local_database_service.dart';
import '../services/auth_service.dart';

class CalendarProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  
  List<Event> _events = [];
  List<CalendarEvent> _calendarEvents = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;
  bool _isOnline = true; // オンライン状態を追跡
  bool _isGuestUser = false; // ゲストユーザーかどうか
  bool _isRealtimeSyncActive = false; // リアルタイム同期の状態

  List<Event> get events => _events;
  List<CalendarEvent> get calendarEvents => _calendarEvents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _currentUserId;
  bool get isOnline => _isOnline;
  bool get isGuestUser => _isGuestUser;
  bool get isRealtimeSyncActive => _isRealtimeSyncActive;

  // 初期化
  Future<void> initialize() async {
    try {
      // ユーザーIDを取得
      _currentUserId = await AuthService.getCurrentUserId();
      _isGuestUser = await AuthService.isGuestUser(_currentUserId!);
      
      // リアルタイム同期を開始
      await _startRealtimeSync();
      
      // イベントを読み込み
      await loadEvents();
      
      print('CalendarProvider初期化完了: $_currentUserId (ゲスト: $_isGuestUser)');
    } catch (e) {
      print('CalendarProvider初期化エラー: $e');
      _error = '初期化に失敗しました: $e';
    }
  }

  // リアルタイム同期を開始
  Future<void> _startRealtimeSync() async {
    if (_isOnline && !_isRealtimeSyncActive) {
      try {
        await _supabaseService.startRealtimeSync();
        _isRealtimeSyncActive = true;
        print('リアルタイム同期を開始しました');
      } catch (e) {
        print('リアルタイム同期開始エラー: $e');
      }
    }
  }

  // リアルタイム同期を停止
  void _stopRealtimeSync() {
    if (_isRealtimeSyncActive) {
      _supabaseService.stopRealtimeSync();
      _isRealtimeSyncActive = false;
      print('リアルタイム同期を停止しました');
    }
  }

  // ユーザーIDを設定
  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    notifyListeners();
  }

  // オンライン状態を設定
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
    if (isOnline) {
      _startRealtimeSync();
    } else {
      _stopRealtimeSync();
    }
    notifyListeners();
  }

  // ゲストユーザー状態を設定
  void setGuestUserStatus(bool isGuest) {
    _isGuestUser = isGuest;
    notifyListeners();
  }

  // イベントを取得（ローカルデータベースを優先）
  Future<void> loadEvents() async {
    _setLoading(true);
    try {
      if (_isOnline) {
        // オンライン時はSupabaseから取得
        final supabaseEvents = await _supabaseService.getEvents();
        _events = supabaseEvents;
        // ローカルデータベースに同期
        await _syncToLocalDatabase();
      } else {
        // オフライン時はローカルデータベースから取得
        _events = await LocalDatabaseService.getAllEvents();
      }
      _error = null;
    } catch (e) {
      // オンライン取得に失敗した場合、ローカルデータベースから取得
      try {
        _events = await LocalDatabaseService.getAllEvents();
        _error = null;
        print('オンライン取得に失敗、ローカルデータベースから取得: $e');
      } catch (localError) {
        _error = 'イベントの取得に失敗しました: $e';
        print('ローカルデータベース取得にも失敗: $localError');
      }
    } finally {
      _setLoading(false);
    }
  }

  // ローカルデータベースに同期
  Future<void> _syncToLocalDatabase() async {
    try {
      for (final event in _events) {
        await LocalDatabaseService.insertEvent(event);
      }
      print('ローカルデータベースへの同期完了: ${_events.length}件');
    } catch (e) {
      print('ローカルデータベースへの同期に失敗: $e');
    }
  }

  // Supabaseとの同期
  Future<void> syncWithSupabase() async {
    if (!_isOnline) return;

    try {
      await _supabaseService.syncWithLocalDatabase();
      
      // 最新のイベントを再読み込み
      await loadEvents();
      
      print('Supabaseとの同期が完了しました');
    } catch (e) {
      _error = 'Supabaseとの同期に失敗しました: $e';
      notifyListeners();
    }
  }

  // 競合解決
  Future<void> resolveConflicts() async {
    if (!_isOnline) return;

    try {
      await _supabaseService.resolveConflicts();
      await loadEvents();
      print('競合解決が完了しました');
    } catch (e) {
      _error = '競合解決に失敗しました: $e';
      notifyListeners();
    }
  }

  // 既存のカレンダーイベントを取得（互換性のため）
  Future<void> loadCalendarEvents() async {
    _setLoading(true);
    try {
      _calendarEvents = await _supabaseService.getCalendarEvents();
      _error = null;
    } catch (e) {
      _error = 'カレンダーイベントの取得に失敗しました: $e';
    } finally {
      _setLoading(false);
    }
  }

  // 新しいEventクラスでイベントを追加
  Future<void> addEvent(Event event) async {
    try {
      // ローカルデータベースに追加
      await LocalDatabaseService.insertEvent(event);
      _events.add(event);
      notifyListeners();

      // オンライン時はSupabaseにも追加
      if (_isOnline) {
        try {
          await _supabaseService.addEvent(event);
          // Google Calendarにも追加
          await _googleCalendarService.addEventToGoogleCalendar(
            CalendarEvent.fromEvent(event)
          );
          // 同期済みとしてマーク
          await LocalDatabaseService.markEventAsSynced(event.id, null);
        } catch (e) {
          print('オンライン同期に失敗: $e');
        }
      }
    } catch (e) {
      _error = 'イベントの追加に失敗しました: $e';
      notifyListeners();
    }
  }

  // 既存のCalendarEventクラスでイベントを追加（互換性のため）
  Future<void> addCalendarEvent(CalendarEvent event) async {
    try {
      await _supabaseService.addCalendarEvent(event);
      await _googleCalendarService.addEventToGoogleCalendar(event);
      _calendarEvents.add(event);
      notifyListeners();
    } catch (e) {
      _error = 'カレンダーイベントの追加に失敗しました: $e';
      notifyListeners();
    }
  }

  // イベントを更新（新しいEventクラス）
  Future<void> updateEvent(Event event) async {
    try {
      // ローカルデータベースを更新
      await LocalDatabaseService.updateEvent(event);
      final index = _events.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _events[index] = event;
        notifyListeners();
      }

      // オンライン時はSupabaseも更新
      if (_isOnline) {
        try {
          await _supabaseService.updateEvent(event);
        } catch (e) {
          print('オンライン更新に失敗: $e');
        }
      }
    } catch (e) {
      _error = 'イベントの更新に失敗しました: $e';
      notifyListeners();
    }
  }

  // 既存のCalendarEventクラスでイベントを更新（互換性のため）
  Future<void> updateCalendarEvent(CalendarEvent event) async {
    try {
      await _supabaseService.updateCalendarEvent(event);
      final index = _calendarEvents.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        _calendarEvents[index] = event;
        notifyListeners();
      }
    } catch (e) {
      _error = 'カレンダーイベントの更新に失敗しました: $e';
      notifyListeners();
    }
  }

  // イベントを削除（新しいEventクラス）
  Future<void> deleteEvent(String eventId) async {
    try {
      // ローカルデータベースから削除
      await LocalDatabaseService.deleteEvent(eventId);
      _events.removeWhere((event) => event.id == eventId);
      notifyListeners();

      // オンライン時はSupabaseも削除
      if (_isOnline) {
        try {
          await _supabaseService.deleteEvent(eventId);
          await _googleCalendarService.deleteEventFromGoogleCalendar(eventId);
        } catch (e) {
          print('オンライン削除に失敗: $e');
        }
      }
    } catch (e) {
      _error = 'イベントの削除に失敗しました: $e';
      notifyListeners();
    }
  }

  // 既存のCalendarEventクラスでイベントを削除（互換性のため）
  Future<void> deleteCalendarEvent(String eventId) async {
    try {
      await _supabaseService.deleteCalendarEvent(eventId);
      await _googleCalendarService.deleteEventFromGoogleCalendar(eventId);
      _calendarEvents.removeWhere((event) => event.id == eventId);
      notifyListeners();
    } catch (e) {
      _error = 'カレンダーイベントの削除に失敗しました: $e';
      notifyListeners();
    }
  }

  // 特定の日付のイベントを取得（新しいEventクラス）
  List<Event> getEventsForDate(DateTime date) {
    return _events.where((event) {
      final eventDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      return eventDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  // 特定の日付のカレンダーイベントを取得（既存の互換性のため）
  List<CalendarEvent> getCalendarEventsForDate(DateTime date) {
    return _calendarEvents.where((event) {
      final eventDate = DateTime(event.startTime.year, event.startTime.month, event.startTime.day);
      final targetDate = DateTime(date.year, date.month, date.day);
      return eventDate.isAtSameMomentAs(targetDate);
    }).toList();
  }

  // 今月のイベントを取得（新しいEventクラス）
  List<Event> getEventsForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return _events.where((event) {
      return event.startTime.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
             event.startTime.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();
  }

  // 今月のカレンダーイベントを取得（既存の互換性のため）
  List<CalendarEvent> getCalendarEventsForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return _calendarEvents.where((event) {
      return event.startTime.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
             event.startTime.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();
  }

  // ユーザーIDでイベントを取得
  Future<void> loadEventsByUserId(String userId) async {
    _setLoading(true);
    try {
      if (_isOnline) {
        _events = await _supabaseService.getEventsByUserId(userId);
      } else {
        _events = await LocalDatabaseService.getEventsByUserId(userId);
      }
      _currentUserId = userId;
      _error = null;
    } catch (e) {
      _error = 'ユーザーイベントの取得に失敗しました: $e';
    } finally {
      _setLoading(false);
    }
  }

  // 日付範囲でイベントを取得
  Future<List<Event>> getEventsByDateRange(DateTime start, DateTime end) async {
    try {
      if (_isOnline) {
        return await _supabaseService.getEventsByDateRange(start, end);
      } else {
        return await LocalDatabaseService.getEventsByDateRange(start, end);
      }
    } catch (e) {
      _error = '日付範囲でのイベント取得に失敗しました: $e';
      return [];
    }
  }

  // 今日のイベントを取得
  List<Event> getTodayEvents() {
    final today = DateTime.now();
    return _events.where((event) => event.isToday).toList();
  }

  // 今週のイベントを取得
  List<Event> getThisWeekEvents() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return _events.where((event) {
      return event.startTime.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
             event.startTime.isBefore(endOfWeek.add(const Duration(days: 1)));
    }).toList();
  }

  // 今月のイベントを取得
  List<Event> getThisMonthEvents() {
    final now = DateTime.now();
    return getEventsForMonth(now);
  }

  // ローカルデータベースをクリア
  Future<void> clearLocalDatabase() async {
    try {
      await LocalDatabaseService.clearDatabase();
      _events.clear();
      notifyListeners();
    } catch (e) {
      _error = 'ローカルデータベースのクリアに失敗しました: $e';
      notifyListeners();
    }
  }

  // 未同期のイベントを取得
  Future<List<Event>> getUnsyncedEvents() async {
    try {
      return await LocalDatabaseService.getUnsyncedEvents();
    } catch (e) {
      _error = '未同期イベントの取得に失敗しました: $e';
      return [];
    }
  }

  // オフラインで作成されたイベントをオンラインに同期
  Future<void> syncOfflineEvents() async {
    if (!_isOnline) return;

    try {
      final unsyncedEvents = await LocalDatabaseService.getUnsyncedEvents();
      for (final event in unsyncedEvents) {
        try {
          await _supabaseService.addEvent(event);
          await LocalDatabaseService.markEventAsSynced(event.id, null);
        } catch (e) {
          print('イベントの同期に失敗: ${event.id} - $e');
        }
      }
    } catch (e) {
      _error = 'オフラインイベントの同期に失敗しました: $e';
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
} 