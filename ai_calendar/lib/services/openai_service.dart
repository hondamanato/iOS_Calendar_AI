import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendar_event.dart';

class OpenAIService {
  static const String _apiKey = 'YOUR_OPENAI_API_KEY';
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4o-mini';

  // AIとの会話を処理し、カレンダーイベントを提案
  Future<Map<String, dynamic>> processChatMessage(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''
あなたはカレンダー管理アシスタントです。ユーザーの自然言語の入力から、カレンダーイベントを作成します。

以下の形式でJSONレスポンスを返してください：
{
  "response": "ユーザーへの返信メッセージ",
  "events": [
    {
      "title": "イベントのタイトル",
      "description": "イベントの説明",
      "startTime": "YYYY-MM-DDTHH:MM:SS",
      "endTime": "YYYY-MM-DDTHH:MM:SS",
      "location": "場所（オプション）",
      "isAllDay": false
    }
  ]
}

日付が明確でない場合は、ユーザーに確認してください。
'''
            },
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        try {
          final jsonResponse = jsonDecode(content);
          return {
            'response': jsonResponse['response'],
            'events': jsonResponse['events'] ?? [],
          };
        } catch (e) {
          // JSONパースに失敗した場合、通常のテキストレスポンスとして扱う
          return {
            'response': content,
            'events': [],
          };
        }
      } else {
        throw Exception('Failed to get response from OpenAI: ${response.statusCode}');
      }
    } catch (e) {
      print('Error processing chat message: $e');
      return {
        'response': '申し訳ございませんが、エラーが発生しました。もう一度お試しください。',
        'events': [],
      };
    }
  }

  // テキストからカレンダーイベントを抽出
  List<CalendarEvent> extractEventsFromResponse(Map<String, dynamic> response) {
    final events = response['events'] as List? ?? [];
    final now = DateTime.now();
    
    return events.map((eventData) {
      return CalendarEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: eventData['title'] ?? '',
        description: eventData['description'] ?? '',
        startTime: DateTime.parse(eventData['startTime']),
        endTime: DateTime.parse(eventData['endTime']),
        location: eventData['location'] ?? '',
        isAllDay: eventData['isAllDay'] ?? false,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();
  }
} 