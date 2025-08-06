import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import '../models/event.dart';

class LocalDatabaseService {
  static Database? _database;
  static const String _databaseName = 'ai_calendar.db';
  static const int _databaseVersion = 1;

  // データベースインスタンスを取得
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // データベースの初期化
  static Future<Database> _initDatabase() async {
    // Flutter Web対応
    if (kIsWeb) {
      // Webの場合はインメモリデータベースを使用
      return await openDatabase(
        inMemoryDatabasePath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } else {
      // ネイティブプラットフォーム用
      try {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      } catch (e) {
        print('sqflite_common_ffi初期化エラー: $e');
        // エラーが発生した場合はデフォルトのdatabaseFactoryを使用
      }
      
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }
  }

  // データベース作成時の処理
  static Future<void> _onCreate(Database db, int version) async {
    // eventsテーブルの作成
    await db.execute('''
      CREATE TABLE events (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        location TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        is_all_day INTEGER NOT NULL DEFAULT 0,
        attendees TEXT,
        user_id TEXT NOT NULL,
        is_synced_with_google INTEGER NOT NULL DEFAULT 0,
        google_event_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // インデックスの作成
    await db.execute('CREATE INDEX idx_events_user_id ON events(user_id)');
    await db.execute('CREATE INDEX idx_events_start_time ON events(start_time)');
    await db.execute('CREATE INDEX idx_events_end_time ON events(end_time)');
    await db.execute('CREATE INDEX idx_events_created_at ON events(created_at)');
  }

  // データベースアップグレード時の処理
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // 将来のアップグレード処理をここに追加
    }
  }

  // イベントを追加
  static Future<void> insertEvent(Event event) async {
    final db = await database;
    await db.insert(
      'events',
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print('ローカルデータベースにイベントを追加: ${event.title}');
  }

  // イベントを更新
  static Future<void> updateEvent(Event event) async {
    final db = await database;
    await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
    print('ローカルデータベースでイベントを更新: ${event.title}');
  }

  // イベントを削除
  static Future<void> deleteEvent(String eventId) async {
    final db = await database;
    await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
    );
    print('ローカルデータベースでイベントを削除: $eventId');
  }

  // イベントの存在確認
  static Future<bool> eventExists(String eventId) async {
    final db = await database;
    final result = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // イベントの最終更新日時を取得
  static Future<DateTime?> getEventLastModified(String eventId) async {
    final db = await database;
    final result = await db.query(
      'events',
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return DateTime.parse(result.first['updated_at'] as String);
    }
    return null;
  }

  // 競合しているイベントを取得（同じIDで異なる更新日時）
  static Future<List<Event>> getConflictingEvents() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT e1.* FROM events e1
      INNER JOIN events e2 ON e1.id = e2.id
      WHERE e1.updated_at != e2.updated_at
    ''');
    
    return result.map((json) => Event.fromMap(json)).toList();
  }

  // データベースの整合性チェック
  static Future<bool> checkDatabaseIntegrity() async {
    try {
      final db = await database;
      await db.rawQuery('PRAGMA integrity_check');
      return true;
    } catch (e) {
      print('データベース整合性チェックエラー: $e');
      return false;
    }
  }

  // データベースの最適化
  static Future<void> optimizeDatabase() async {
    try {
      final db = await database;
      await db.rawQuery('VACUUM');
      await db.rawQuery('ANALYZE');
      print('データベースの最適化が完了しました');
    } catch (e) {
      print('データベース最適化エラー: $e');
    }
  }

  // すべてのイベントを取得
  static Future<List<Event>> getAllEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      orderBy: 'start_time ASC',
    );

    return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
  }

  // 特定のユーザーのイベントを取得
  static Future<List<Event>> getEventsByUserId(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'start_time ASC',
    );

    return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
  }

  // 特定の日付範囲のイベントを取得
  static Future<List<Event>> getEventsByDateRange(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startDateStr = startDate.toIso8601String();
    final endDateStr = endDate.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'start_time >= ? AND start_time <= ?',
      whereArgs: [startDateStr, endDateStr],
      orderBy: 'start_time ASC',
    );

    return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
  }

  // 特定の日付のイベントを取得
  static Future<List<Event>> getEventsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getEventsByDateRange(startOfDay, endOfDay);
  }

  // 特定のイベントを取得
  static Future<Event?> getEventById(String eventId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [eventId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Event.fromMap(maps.first);
    }
    return null;
  }

  // 同期されていないイベントを取得
  static Future<List<Event>> getUnsyncedEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'is_synced_with_google = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );

    return List.generate(maps.length, (i) => Event.fromMap(maps[i]));
  }

  // イベントを同期済みとしてマーク
  static Future<void> markEventAsSynced(String eventId, String? googleEventId) async {
    final db = await database;
    await db.update(
      'events',
      {
        'is_synced_with_google': 1,
        'google_event_id': googleEventId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  // データベースをクリア
  static Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('events');
  }

  // データベースを閉じる
  static Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // データベースのサイズを取得
  static Future<int> getDatabaseSize() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM events');
    return result.first['count'] as int? ?? 0;
  }

  // バックアップデータを取得
  static Future<Map<String, dynamic>> getBackupData() async {
    final db = await database;
    final List<Map<String, dynamic>> events = await db.query('events');
    
    return {
      'events': events,
      'backup_date': DateTime.now().toIso8601String(),
      'version': _databaseVersion,
    };
  }

  // バックアップデータから復元
  static Future<void> restoreFromBackup(Map<String, dynamic> backupData) async {
    final db = await database;
    
    // トランザクションを使用してデータを復元
    await db.transaction((txn) async {
      // 既存のデータをクリア
      await txn.delete('events');
      
      // バックアップデータを復元
      final events = backupData['events'] as List<dynamic>;
      for (final eventData in events) {
        await txn.insert('events', eventData as Map<String, dynamic>);
      }
    });
  }
} 