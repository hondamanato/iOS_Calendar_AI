import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../models/calendar_event.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text('AI アシスタント'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => _showClearDialog(context),
            tooltip: 'チャット履歴をクリア',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'ヘルプ',
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          if (chatProvider.isLoading && chatProvider.messages.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AIアシスタントを初期化中...'),
                ],
              ),
            );
          }

          if (chatProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    chatProvider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => chatProvider.loadMessages(),
                    child: const Text('再試行'),
                  ),
                ],
              ),
            );
          }

          final messages = chatProvider.messages
              .map((msg) => msg.toChatTypesMessage())
              .toList();

          return Chat(
            messages: messages,
            onSendPressed: (text) {
              chatProvider.sendMessage(text.text);
            },
            user: const types.User(id: 'user'),
            customMessageBuilder: (message, {required messageWidth}) {
              if (message is types.TextMessage) {
                final chatMessage = chatProvider.messages.firstWhere(
                  (msg) => msg.id == message.id,
                );

                if (chatMessage.suggestedEvents != null &&
                    chatMessage.suggestedEvents!.isNotEmpty) {
                  return _buildSuggestedEventsCard(
                    chatMessage.suggestedEvents!,
                    chatProvider,
                  );
                }
              }
              return const SizedBox.shrink();
            },
            inputOptions: const InputOptions(
              sendButtonVisibilityMode: SendButtonVisibilityMode.always,
            ),
            theme: DefaultChatTheme(
              primaryColor: Colors.deepPurple,
              backgroundColor: Colors.grey[50]!,
              inputBackgroundColor: Colors.white,
              inputTextColor: Colors.black87,
              inputTextCursorColor: Colors.deepPurple,
              userAvatarNameColors: [Colors.deepPurple],
              userAvatarImageBackgroundColor: Colors.deepPurple,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestedEventsCard(
    List<CalendarEvent> events,
    ChatProvider chatProvider,
  ) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_available,
                  color: Colors.deepPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '提案されたイベント',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...events.map((event) => _buildEventTile(event, chatProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(CalendarEvent event, ChatProvider chatProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _approveEvent(event, chatProvider),
                      tooltip: '承認',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _rejectEvent(event),
                      tooltip: '拒否',
                    ),
                  ],
                ),
              ],
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${event.startTime.toString().substring(0, 16)} - ${event.endTime.toString().substring(0, 16)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    event.location,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _approveEvent(CalendarEvent event, ChatProvider chatProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('イベントを追加'),
          ],
        ),
        content: Text('「${event.title}」をカレンダーに追加しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              chatProvider.approveSuggestedEvent(event);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('「${event.title}」をカレンダーに追加しました'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _rejectEvent(CalendarEvent event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${event.title}」を拒否しました'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.clear_all, color: Colors.red),
            SizedBox(width: 8),
            Text('チャット履歴をクリア'),
          ],
        ),
        content: const Text('すべてのチャット履歴を削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ChatProvider>().clearMessages();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('チャット履歴をクリアしました'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('クリア'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('AIアシスタントの使い方'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '自然言語で予定を入力してください。例：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• "明日の午後2時に会議"'),
              Text('• "来週月曜日の10時から12時まで打ち合わせ"'),
              Text('• "8月15日の終日で休暇"'),
              SizedBox(height: 16),
              Text(
                'AIが提案したイベントは承認または拒否できます。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('了解'),
          ),
        ],
      ),
    );
  }
} 