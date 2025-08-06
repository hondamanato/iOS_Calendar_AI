import 'event.dart';

class CalendarEvent {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final bool isAllDay;
  final DateTime createdAt;
  final DateTime updatedAt;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    this.location = '',
    this.isAllDay = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // EventクラスからCalendarEventを作成
  factory CalendarEvent.fromEvent(Event event) {
    return CalendarEvent(
      id: event.id,
      title: event.title,
      description: event.description ?? '',
      startTime: event.startTime,
      endTime: event.endTime,
      location: event.location ?? '',
      isAllDay: event.isAllDay,
      createdAt: event.createdAt,
      updatedAt: event.updatedAt,
    );
  }

  // CalendarEventからEventクラスを作成
  Event toEvent({required String userId}) {
    return Event(
      id: id,
      title: title,
      description: description,
      location: location,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      location: json['location'] ?? '',
      isAllDay: json['is_all_day'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'location': location,
      'is_all_day': isAllDay,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    bool? isAllDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      isAllDay: isAllDay ?? this.isAllDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 