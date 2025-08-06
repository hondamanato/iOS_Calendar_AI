import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:googleapis_auth/auth_io.dart';
import '../models/calendar_event.dart';

class GoogleCalendarService {
  static const List<String> _scopes = [calendar.CalendarApi.calendarScope];
  static const String _clientId = 'YOUR_GOOGLE_CLIENT_ID';
  static const String _clientSecret = 'YOUR_GOOGLE_CLIENT_SECRET';
  
  calendar.CalendarApi? _calendarApi;

  // Google Calendar APIの初期化
  Future<void> initialize() async {
    try {
      final credentials = ServiceAccountCredentials.fromJson({
        'type': 'service_account',
        'project_id': 'your-project-id',
        'private_key_id': 'your-private-key-id',
        'private_key': 'your-private-key',
        'client_email': 'your-client-email',
        'client_id': 'your-client-id',
        'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
        'token_uri': 'https://oauth2.googleapis.com/token',
        'auth_provider_x509_cert_url': 'https://www.googleapis.com/oauth2/v1/certs',
        'client_x509_cert_url': 'your-cert-url',
      });

      final client = await clientViaServiceAccount(credentials, _scopes);
      _calendarApi = calendar.CalendarApi(client);
    } catch (e) {
      print('Error initializing Google Calendar API: $e');
    }
  }

  // イベントをGoogle Calendarに追加
  Future<bool> addEventToGoogleCalendar(CalendarEvent event) async {
    try {
      if (_calendarApi == null) {
        await initialize();
      }

      final startDateTime = calendar.EventDateTime()
        ..dateTime = event.startTime.toUtc()
        ..timeZone = 'Asia/Tokyo';
      
      final endDateTime = calendar.EventDateTime()
        ..dateTime = event.endTime.toUtc()
        ..timeZone = 'Asia/Tokyo';

      final calendarEvent = calendar.Event()
        ..summary = event.title
        ..description = event.description
        ..location = event.location
        ..start = startDateTime
        ..end = endDateTime;

      await _calendarApi!.events.insert(calendarEvent, 'primary');
      return true;
    } catch (e) {
      print('Error adding event to Google Calendar: $e');
      return false;
    }
  }

  // Google Calendarからイベントを取得
  Future<List<CalendarEvent>> getEventsFromGoogleCalendar({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_calendarApi == null) {
        await initialize();
      }

      final now = DateTime.now();
      final start = startDate ?? now.subtract(const Duration(days: 30));
      final end = endDate ?? now.add(const Duration(days: 30));

      final events = await _calendarApi!.events.list(
        'primary',
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items?.map((googleEvent) {
        return CalendarEvent(
          id: googleEvent.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
          title: googleEvent.summary ?? '',
          description: googleEvent.description ?? '',
          startTime: googleEvent.start?.dateTime ?? now,
          endTime: googleEvent.end?.dateTime ?? now,
          location: googleEvent.location ?? '',
          isAllDay: googleEvent.start?.date != null,
          createdAt: now,
          updatedAt: now,
        );
      }).toList() ?? [];
    } catch (e) {
      print('Error getting events from Google Calendar: $e');
      return [];
    }
  }

  // Google Calendarからイベントを削除
  Future<bool> deleteEventFromGoogleCalendar(String eventId) async {
    try {
      if (_calendarApi == null) {
        await initialize();
      }

      await _calendarApi!.events.delete(eventId, 'primary');
      return true;
    } catch (e) {
      print('Error deleting event from Google Calendar: $e');
      return false;
    }
  }
} 