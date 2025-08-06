import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'calendar_event.dart';

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isFromUser;
  final List<CalendarEvent>? suggestedEvents;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isFromUser,
    this.suggestedEvents,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      text: json['text'],
      timestamp: DateTime.parse(json['timestamp']),
      isFromUser: json['is_from_user'],
      suggestedEvents: json['suggested_events'] != null
          ? (json['suggested_events'] as List)
              .map((e) => CalendarEvent.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'is_from_user': isFromUser,
      'suggested_events': suggestedEvents?.map((e) => e.toJson()).toList(),
    };
  }

  types.TextMessage toChatTypesMessage() {
    return types.TextMessage(
      author: types.User(
        id: isFromUser ? 'user' : 'ai',
        firstName: isFromUser ? 'User' : 'AI',
      ),
      id: id,
      text: text,
      createdAt: timestamp.millisecondsSinceEpoch,
    );
  }
} 