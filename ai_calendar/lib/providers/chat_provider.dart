import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/calendar_event.dart';
import '../services/supabase_service.dart';
import '../services/openai_service.dart';

class ChatProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final OpenAIService _openAIService = OpenAIService();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _error;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // チャットメッセージを取得
  Future<void> loadMessages() async {
    _setLoading(true);
    try {
      _messages = await _supabaseService.getChatMessages();
      _error = null;
    } catch (e) {
      _error = 'メッセージの取得に失敗しました: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ユーザーメッセージを送信
  Future<void> sendMessage(String text) async {
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isFromUser: true,
    );

    _messages.add(userMessage);
    notifyListeners();

    // AIの応答を取得
    await _getAIResponse(text);
  }

  // AIの応答を取得
  Future<void> _getAIResponse(String userMessage) async {
    _setLoading(true);
    try {
      final response = await _openAIService.processChatMessage(userMessage);
      
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: response['response'],
        timestamp: DateTime.now(),
        isFromUser: false,
        suggestedEvents: _openAIService.extractEventsFromResponse(response),
      );

      _messages.add(aiMessage);
      await _supabaseService.addChatMessage(aiMessage);
      _error = null;
    } catch (e) {
      _error = 'AIの応答の取得に失敗しました: $e';
    } finally {
      _setLoading(false);
    }
  }

  // 提案されたイベントを承認
  Future<void> approveSuggestedEvent(CalendarEvent event) async {
    try {
      // カレンダープロバイダーを通じてイベントを追加
      // この部分は後でカレンダープロバイダーと連携する
      _error = null;
    } catch (e) {
      _error = 'イベントの追加に失敗しました: $e';
    }
    notifyListeners();
  }

  // メッセージをクリア
  void clearMessages() {
    _messages.clear();
    notifyListeners();
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