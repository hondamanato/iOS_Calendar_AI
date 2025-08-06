import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event.dart';
import '../models/event.dart';
import '../utils/config.dart';
import '../services/auth_service.dart';
import '../services/local_database_service.dart';
import 'chat_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isBottomSheetOpen = false;
  bool _isDayView = false; // 日表示モードかどうかを追跡

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    
    // 日本語のロケールを初期化
    initializeDateFormatting('ja_JP', null);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().initialize();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildCalendarView(),
            ),
            _buildFooter(),
          ],
        ),
      ),
      floatingActionButton: _buildChatFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _showDrawer(),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
              });
            },
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('yyyy年M月', 'ja_JP').format(_focusedDay),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
              });
            },
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // リアルタイム同期状態インジケーター
        Consumer<CalendarProvider>(
          builder: (context, provider, child) {
            return Icon(
              provider.isRealtimeSyncActive ? Icons.sync : Icons.sync_disabled,
              color: provider.isRealtimeSyncActive ? Colors.green : Colors.grey,
              size: 20,
            );
          },
        ),
        // オンライン状態インジケーター
        Consumer<CalendarProvider>(
          builder: (context, provider, child) {
            return Icon(
              provider.isOnline ? Icons.wifi : Icons.wifi_off,
              color: provider.isOnline ? Colors.green : Colors.orange,
            );
          },
        ),
        // 同期ボタン
        Consumer<CalendarProvider>(
          builder: (context, provider, child) {
            return IconButton(
              icon: const Icon(Icons.sync),
              onPressed: provider.isOnline ? () => _syncEvents(context) : null,
              tooltip: '同期',
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => _showSearchDialog(),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showAddEventDialog(context),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettingsDialog(context),
        ),
      ],
    );
  }

  Widget _buildCalendarView() {
    return Consumer<CalendarProvider>(
      builder: (context, calendarProvider, child) {
        if (calendarProvider.isLoading) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (calendarProvider.error != null) {
          return SizedBox(
            height: 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    calendarProvider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  ElevatedButton(
                    onPressed: () => calendarProvider.loadEvents(),
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }

        // 日表示モードの場合はカスタム日表示を表示
        if (_calendarFormat == CalendarFormat.week && _isDayView) {
          return _buildDayView(calendarProvider);
        }

        // カスタムカレンダーグリッドを表示
        return _buildCustomCalendarGrid(calendarProvider);
      },
    );
  }

  Widget _buildCustomCalendarGrid(CalendarProvider calendarProvider) {
    final now = DateTime.now();
    final currentMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstDayOfMonth = currentMonth.weekday;
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final lastDayOfPreviousMonth = DateTime(_focusedDay.year, _focusedDay.month, 0).day;

    // カレンダーグリッドの日付を生成
    List<DateTime> calendarDays = [];
    
    // 前月の日付を追加
    for (int i = firstDayOfMonth - 1; i > 0; i--) {
      calendarDays.add(DateTime(_focusedDay.year, _focusedDay.month - 1, lastDayOfPreviousMonth - i + 1));
    }
    
    // 今月の日付を追加
    for (int i = 1; i <= daysInMonth; i++) {
      calendarDays.add(DateTime(_focusedDay.year, _focusedDay.month, i));
    }
    
    // 次月の日付を追加（6週間分のグリッドを完成させる）
    int remainingDays = 42 - calendarDays.length;
    for (int i = 1; i <= remainingDays; i++) {
      calendarDays.add(DateTime(_focusedDay.year, _focusedDay.month + 1, i));
    }

    return Column(
      children: [
        // 曜日ヘッダー
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: ['月', '火', '水', '木', '金', '土', '日'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: day == '土' ? Colors.blue[600] : day == '日' ? Colors.red[600] : Colors.grey[700],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // カレンダーグリッド
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: calendarDays.length,
            itemBuilder: (context, index) {
              final day = calendarDays[index];
              final isCurrentMonth = day.month == _focusedDay.month;
              final isToday = isSameDay(day, now);
              final isSelected = isSameDay(day, _selectedDay ?? now);
              final events = calendarProvider.getEventsForDate(day);
              final hasEvents = events.isNotEmpty;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });
                  // 同じ日付を再度タップした場合はボトムシートを表示
                  if (isSelected) {
                    _showBottomSheet(context, day);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.deepPurple 
                        : isToday 
                            ? Colors.orange.withOpacity(0.15)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: isToday 
                        ? Border.all(color: Colors.orange, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // 日付
                      Center(
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                            color: isSelected 
                                ? Colors.white
                                : !isCurrentMonth 
                                    ? Colors.grey[300]
                                    : day.weekday == 6 
                                        ? Colors.blue[600] 
                                        : day.weekday == 7 
                                            ? Colors.red[600] 
                                            : Colors.grey[800],
                          ),
                        ),
                      ),
                      // イベントマーカー
                      if (hasEvents)
                        Positioned(
                          bottom: 4,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white : Colors.deepPurple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayView(CalendarProvider calendarProvider) {
    final selectedDay = _selectedDay ?? DateTime.now();
    final events = calendarProvider.getEventsForDate(selectedDay);

    return Column(
      children: [
        // 日付ヘッダー
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            boxShadow: [
              BoxShadow(
                color: Colors.grey[300]!,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = selectedDay.subtract(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Text(
                DateFormat('yyyy年M月d日 (E)', 'ja_JP').format(selectedDay),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDay = selectedDay.add(const Duration(days: 1));
                  });
                },
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
        ),
        // イベントリスト
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'この日には予定がありません',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: event.isOngoing 
                              ? Colors.green 
                              : event.isPast 
                                  ? Colors.grey 
                                  : Colors.deepPurple,
                          child: Icon(
                            event.isAllDay ? Icons.all_inclusive : Icons.schedule,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.description?.isNotEmpty == true)
                              Text(event.description!),
                            const SizedBox(height: 4),
                            Text(
                              event.timeString,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (event.location?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    event.location!,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                            if (event.attendees?.isNotEmpty == true) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.people, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${event.attendees!.length}人の参加者',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => _handleEventAction(value, event),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit),
                                  SizedBox(width: 8),
                                  Text('編集'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('削除', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // 新しい予定を追加ボタン
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddEventDialog(context, selectedDate: selectedDay),
              icon: const Icon(Icons.add),
              label: const Text('新しい予定を追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventList() {
    return Consumer<CalendarProvider>(
      builder: (context, calendarProvider, child) {
        if (_selectedDay == null) {
          return const Center(
            child: Text('日付を選択してください'),
          );
        }

        final events = calendarProvider.getEventsForDate(_selectedDay!);

        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'この日には予定がありません',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('yyyy年M月d日', 'ja_JP').format(_selectedDay!),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddEventDialog(context, selectedDate: _selectedDay!),
                  icon: const Icon(Icons.add),
                  label: const Text('予定を追加'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: event.isOngoing 
                      ? Colors.green 
                      : event.isPast 
                          ? Colors.grey 
                          : Colors.deepPurple,
                  child: Icon(
                    event.isAllDay ? Icons.all_inclusive : Icons.schedule,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (event.description?.isNotEmpty == true)
                      Text(event.description!),
                    const SizedBox(height: 4),
                    Text(
                      event.timeString,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    if (event.location?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            event.location!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                    if (event.attendees?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.people, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${event.attendees!.length}人の参加者',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) => _handleEventAction(value, event),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('編集'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('削除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFooterButton(
                icon: Icons.calendar_view_month,
                label: '月',
                isSelected: _calendarFormat == CalendarFormat.month,
                onTap: () => _changeCalendarFormat(CalendarFormat.month),
              ),
              _buildFooterButton(
                icon: Icons.calendar_view_week,
                label: '週',
                isSelected: _calendarFormat == CalendarFormat.week,
                onTap: () => _changeCalendarFormat(CalendarFormat.week),
              ),
              _buildFooterButton(
                icon: Icons.calendar_view_day,
                label: '日',
                isSelected: _calendarFormat == CalendarFormat.week && _isDayView,
                onTap: () => _changeCalendarFormat(CalendarFormat.week, isDayView: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeCalendarFormat(CalendarFormat format, {bool isDayView = false}) {
    setState(() {
      _calendarFormat = format;
      _isDayView = isDayView;
    });
  }

  Widget _buildChatFAB() {
    return FloatingActionButton(
      onPressed: () => _showChatScreen(),
      backgroundColor: Colors.deepPurple,
      foregroundColor: Colors.white,
      child: const Icon(Icons.auto_awesome), // 魔法の杖アイコン
    );
  }

  // ボトムシートを表示
  void _showBottomSheet(BuildContext context, DateTime selectedDate) {
    if (_isBottomSheetOpen) return;
    
    _isBottomSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildBottomSheetContent(context, selectedDate),
    ).then((_) {
      _isBottomSheetOpen = false;
    });
  }

  Widget _buildBottomSheetContent(BuildContext context, DateTime selectedDate) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // ヘッダー
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('yyyy年M月d日 (E)', 'ja_JP').format(selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // イベントリスト
              Expanded(
                child: Consumer<CalendarProvider>(
                  builder: (context, calendarProvider, child) {
                    final events = calendarProvider.getEventsForDate(selectedDate);
                    
                    if (events.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'この日には予定がありません',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: event.isOngoing 
                                  ? Colors.green 
                                  : event.isPast 
                                      ? Colors.grey 
                                      : Colors.deepPurple,
                              child: Icon(
                                event.isAllDay ? Icons.all_inclusive : Icons.schedule,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (event.description?.isNotEmpty == true)
                                  Text(event.description!),
                                const SizedBox(height: 4),
                                Text(
                                  event.timeString,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                if (event.location?.isNotEmpty == true) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        event.location!,
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) => _handleEventAction(value, event),
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit),
                                      SizedBox(width: 8),
                                      Text('編集'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('削除', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // 新しい予定を追加ボタン
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showAddEventDialog(context, selectedDate: selectedDate);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('新しい予定を追加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDrawer() {
    Scaffold.of(context).openDrawer();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予定を検索'),
        content: const TextField(
          decoration: InputDecoration(
            hintText: '予定のタイトルや説明を入力してください',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              // 検索機能の実装
              Navigator.of(context).pop();
            },
            child: const Text('検索'),
          ),
        ],
      ),
    );
  }

  void _showChatScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  void _handleEventAction(String action, Event event) {
    switch (action) {
      case 'edit':
        _showEditEventDialog(context, event);
        break;
      case 'delete':
        _showDeleteEventDialog(context, event);
        break;
    }
  }

  void _showAddEventDialog(BuildContext context, {DateTime? selectedDate}) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        selectedDate: selectedDate,
      ),
    );
  }

  void _showEditEventDialog(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (context) => AddEventDialog(
        event: event,
      ),
    );
  }

  void _showDeleteEventDialog(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('イベントを削除'),
        content: Text('「${event.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              context.read<CalendarProvider>().deleteEvent(event.id);
              Navigator.of(context).pop();
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.settings, color: Colors.blue),
            SizedBox(width: 8),
            Text('設定'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ユーザー情報
            Consumer<CalendarProvider>(
              builder: (context, provider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          provider.isGuestUser ? Icons.person_outline : Icons.person,
                          color: provider.isGuestUser ? Colors.orange : Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isGuestUser ? 'ゲストユーザー' : '登録ユーザー',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: provider.isGuestUser ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (provider.currentUserId != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${provider.currentUserId!.substring(0, 8)}...',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            _buildConfigStatus('Supabase', Config.isSupabaseConfigured),
            const SizedBox(height: 8),
            _buildConfigStatus('OpenAI', Config.isOpenAIConfigured),
            const SizedBox(height: 8),
            _buildConfigStatus('Google Calendar', Config.isGoogleConfigured),
            const SizedBox(height: 16),
            Consumer<CalendarProvider>(
              builder: (context, provider, child) {
                return Row(
                  children: [
                    Icon(
                      provider.isOnline ? Icons.wifi : Icons.wifi_off,
                      color: provider.isOnline ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.isOnline ? 'オンライン' : 'オフライン',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: provider.isOnline ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'ローカルデータベース機能:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• オフライン時でもイベントの作成・編集が可能'),
            const Text('• オンライン復帰時に自動同期'),
            const Text('• データのローカル保存'),
            const SizedBox(height: 16),
            const Text(
              'Supabase同期機能:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• リアルタイムデータ同期'),
            const Text('• オフライン対応'),
            const Text('• データバックアップ'),
            const Text('• 競合解決機能'),
            const SizedBox(height: 16),
            Consumer<CalendarProvider>(
              builder: (context, provider, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          provider.isRealtimeSyncActive ? Icons.sync : Icons.sync_disabled,
                          color: provider.isRealtimeSyncActive ? Colors.green : Colors.grey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.isRealtimeSyncActive ? 'リアルタイム同期: 有効' : 'リアルタイム同期: 無効',
                          style: TextStyle(
                            fontSize: 12,
                            color: provider.isRealtimeSyncActive ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '同期状態: ${provider.isOnline ? "オンライン" : "オフライン"}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'APIキーを設定するには、環境変数を設定するか、\nflutter runコマンドに--dart-defineフラグを使用してください。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Consumer<CalendarProvider>(
            builder: (context, provider, child) {
              if (provider.isGuestUser) {
                return TextButton(
                  onPressed: () => _showGuestConversionDialog(context),
                  child: const Text('アカウント作成'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer<CalendarProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: provider.isOnline ? () => _resolveConflicts(context) : null,
                child: const Text('競合解決'),
              );
            },
          ),
          TextButton(
            onPressed: () => _showLocalDatabaseInfo(context),
            child: const Text('ローカルDB情報'),
          ),
          Consumer<CalendarProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: provider.isOnline ? () => _syncEvents(context) : null,
                child: const Text('同期'),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showGuestConversionDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント作成'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ゲストユーザーから正式なアカウントに変換します。'),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  if (!value.contains('@')) {
                    return '有効なメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  if (value.length < 6) {
                    return 'パスワードは6文字以上で入力してください';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await AuthService.convertGuestToRegularUser(
                    emailController.text,
                    passwordController.text,
                  );
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('アカウント作成が完了しました'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('アカウント作成に失敗しました: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  void _showLocalDatabaseInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ローカルデータベース情報'),
        content: FutureBuilder<int>(
          future: LocalDatabaseService.getDatabaseSize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final eventCount = snapshot.data ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('保存されているイベント数: $eventCount'),
                const SizedBox(height: 16),
                const Text('データベース機能:'),
                const Text('• オフライン対応'),
                const Text('• 自動同期'),
                const Text('• データバックアップ'),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => _clearLocalDatabase(context),
            child: const Text('データベースクリア', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _clearLocalDatabase(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データベースクリア'),
        content: const Text('ローカルデータベースのすべてのデータを削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              context.read<CalendarProvider>().clearLocalDatabase();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigStatus(String name, bool isConfigured) {
    return Row(
      children: [
        Icon(
          isConfigured ? Icons.check_circle : Icons.error,
          color: isConfigured ? Colors.green : Colors.red,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isConfigured ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isConfigured ? '設定済み' : '未設定',
          style: TextStyle(
            color: isConfigured ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  // イベント同期
  void _syncEvents(BuildContext context) {
    final provider = context.read<CalendarProvider>();
    provider.syncWithSupabase();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('イベントの同期を開始しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 競合解決
  void _resolveConflicts(BuildContext context) {
    final provider = context.read<CalendarProvider>();
    provider.resolveConflicts();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('競合解決を開始しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class AddEventDialog extends StatefulWidget {
  final Event? event;
  final DateTime? selectedDate;

  const AddEventDialog({super.key, this.event, this.selectedDate});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _attendeesController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  bool _isAllDay = false;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description ?? '';
      _locationController.text = widget.event!.location ?? '';
      _attendeesController.text = widget.event!.attendees?.join(', ') ?? '';
      _startDate = widget.event!.startTime;
      _endDate = widget.event!.endTime;
      _isAllDay = widget.event!.isAllDay;
    } else if (widget.selectedDate != null) {
      // 選択された日付がある場合は、その日付の9:00から10:00をデフォルトに設定
      _startDate = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        9,
        0,
      );
      _endDate = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        10,
        0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'イベントを追加' : 'イベントを編集'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '場所',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _attendeesController,
                decoration: const InputDecoration(
                  labelText: '参加者（カンマ区切り）',
                  prefixIcon: Icon(Icons.people),
                  hintText: 'example@email.com, another@email.com',
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('終日'),
                value: _isAllDay,
                onChanged: (value) {
                  setState(() {
                    _isAllDay = value ?? false;
                  });
                },
              ),
              if (!_isAllDay) ...[
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('開始時刻'),
                  subtitle: Text(DateFormat('yyyy/MM/dd HH:mm', 'ja_JP').format(_startDate)),
                  leading: const Icon(Icons.access_time),
                  onTap: () => _selectDateTime(true),
                ),
                ListTile(
                  title: const Text('終了時刻'),
                  subtitle: Text(DateFormat('yyyy/MM/dd HH:mm', 'ja_JP').format(_endDate)),
                  leading: const Icon(Icons.access_time_filled),
                  onTap: () => _selectDateTime(false),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _saveEvent,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _selectDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
      );

      if (time != null) {
        setState(() {
          final newDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );

          if (isStart) {
            _startDate = newDateTime;
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(hours: 1));
            }
          } else {
            _endDate = newDateTime;
          }
        });
      }
    }
  }

  void _saveEvent() {
    if (_formKey.currentState!.validate()) {
      final attendees = _attendeesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final userId = AuthService.currentUserId ?? 'default-user';

      final event = widget.event == null
          ? Event.create(
              title: _titleController.text,
              description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
              location: _locationController.text.isEmpty ? null : _locationController.text,
              startTime: _startDate,
              endTime: _endDate,
              isAllDay: _isAllDay,
              attendees: attendees.isEmpty ? null : attendees,
              userId: userId,
              isSyncedWithGoogle: false,
            )
          : widget.event!.copyWith(
              title: _titleController.text,
              description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
              location: _locationController.text.isEmpty ? null : _locationController.text,
              startTime: _startDate,
              endTime: _endDate,
              isAllDay: _isAllDay,
              attendees: attendees.isEmpty ? null : attendees,
              updatedAt: DateTime.now(),
            );

      if (widget.event == null) {
        context.read<CalendarProvider>().addEvent(event);
      } else {
        context.read<CalendarProvider>().updateEvent(event);
      }

      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _attendeesController.dispose();
    super.dispose();
  }
} 