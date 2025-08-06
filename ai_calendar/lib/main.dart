import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/calendar_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/calendar_screen.dart';
import 'screens/chat_screen.dart';
import 'utils/config.dart';
import 'services/auth_service.dart';
import 'services/local_database_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 日本語のロケールデータを初期化
  await initializeDateFormatting('ja_JP', null);
  
  // .envファイルを読み込み
  try {
    await dotenv.load(fileName: ".env");
    print('環境変数を読み込みました');
  } catch (e) {
    print('Warning: .env file not found, using default values');
  }
  
  // Supabaseの初期化
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? Config.supabaseUrl,
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? Config.supabaseAnonKey,
    );
    print('Supabaseが初期化されました');
    
    // Supabase接続テスト
    final supabaseService = SupabaseService();
    final isConnected = await supabaseService.testConnection();
    if (isConnected) {
      print('Supabase接続テスト成功');
    } else {
      print('Supabase接続テスト失敗');
    }
  } catch (e) {
    print('Supabase初期化エラー: $e');
  }
  
  // ゲストユーザー認証の初期化
  try {
    final userId = await AuthService.initializeAuth();
    print('認証初期化完了: $userId');
  } catch (e) {
    print('認証初期化エラー: $e');
  }
  
  // ローカルデータベースの初期化
  try {
    await LocalDatabaseService.database;
    print('ローカルデータベースが初期化されました');
  } catch (e) {
    print('ローカルデータベースの初期化に失敗: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: Config.appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: CalendarScreen(),
    );
  }
}
