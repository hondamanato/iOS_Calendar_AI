import 'dart:math';

class Event {
  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final List<String>? attendees;
  final String userId;
  final bool isSyncedWithGoogle;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.attendees,
    required this.userId,
    this.isSyncedWithGoogle = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // UUIDを生成するファクトリメソッド
  factory Event.create({
    required String title,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    List<String>? attendees,
    required String userId,
    bool isSyncedWithGoogle = false,
  }) {
    return Event(
      id: _generateUUID(),
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      attendees: attendees,
      userId: userId,
      isSyncedWithGoogle: isSyncedWithGoogle,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // 簡単なUUID生成（実際のプロジェクトではuuidパッケージを使用することを推奨）
  static String _generateUUID() {
    final random = Random();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    
    // UUID v4形式に変換
    values[6] = (values[6] & 0x0f) | 0x40; // バージョン4
    values[8] = (values[8] & 0x3f) | 0x80; // バリアント
    
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  // JSONからEventオブジェクトを作成
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      location: json['location'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      isAllDay: json['is_all_day'] ?? false,
      attendees: json['attendees'] != null 
          ? List<String>.from(json['attendees'])
          : null,
      userId: json['user_id'],
      isSyncedWithGoogle: json['is_synced_with_google'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // EventオブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_all_day': isAllDay,
      'attendees': attendees,
      'user_id': userId,
      'is_synced_with_google': isSyncedWithGoogle,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // MapからEventオブジェクトを作成（sqflite用）
  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      location: map['location'],
      startTime: DateTime.parse(map['start_time']),
      endTime: DateTime.parse(map['end_time']),
      isAllDay: map['is_all_day'] == 1,
      attendees: map['attendees'] != null 
          ? map['attendees'].split(',').where((e) => e.isNotEmpty).toList()
          : null,
      userId: map['user_id'],
      isSyncedWithGoogle: map['is_synced_with_google'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // EventオブジェクトをMapに変換（sqflite用）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_all_day': isAllDay ? 1 : 0,
      'attendees': attendees?.join(','),
      'user_id': userId,
      'is_synced_with_google': isSyncedWithGoogle ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Eventオブジェクトをコピーして新しいオブジェクトを作成
  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    List<String>? attendees,
    String? userId,
    bool? isSyncedWithGoogle,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      attendees: attendees ?? this.attendees,
      userId: userId ?? this.userId,
      isSyncedWithGoogle: isSyncedWithGoogle ?? this.isSyncedWithGoogle,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // イベントの期間を取得
  Duration get duration => endTime.difference(startTime);

  // イベントが今日かどうか
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(startTime.year, startTime.month, startTime.day);
    return today.isAtSameMomentAs(eventDate);
  }

  // イベントが過去かどうか
  bool get isPast => endTime.isBefore(DateTime.now());

  // イベントが進行中かどうか
  bool get isOngoing {
    final now = DateTime.now();
    return startTime.isBefore(now) && endTime.isAfter(now);
  }

  // イベントが将来かどうか
  bool get isFuture => startTime.isAfter(DateTime.now());

  // イベントの時間文字列を取得
  String get timeString {
    if (isAllDay) return '終日';
    return '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
  }

  // イベントの日付文字列を取得
  String get dateString {
    return '${startTime.year}/${startTime.month.toString().padLeft(2, '0')}/${startTime.day.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'Event(id: $id, title: $title, startTime: $startTime, endTime: $endTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 