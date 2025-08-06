import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  // Supabase設定
  static String get supabaseUrl => 
    dotenv.env['SUPABASE_URL'] ?? 'https://your-project.supabase.co';
  
  static String get supabaseAnonKey => 
    dotenv.env['SUPABASE_ANON_KEY'] ?? 'your-anon-key';
  
  // OpenAI設定
  static String get openaiApiKey => 
    dotenv.env['OPENAI_API_KEY'] ?? 'sk-your-openai-api-key';
  
  // Google Calendar設定
  static String get googleClientId => 
    dotenv.env['GOOGLE_CLIENT_ID'] ?? 'your-google-client-id';
  
  static String get googleClientSecret => 
    dotenv.env['GOOGLE_CLIENT_SECRET'] ?? 'your-google-client-secret';
  
  // アプリ設定
  static const String appName = 'AI Calendar';
  static const String appVersion = '1.0.0';
  
  // デフォルト設定
  static const String defaultTimeZone = 'Asia/Tokyo';
  static const String defaultLanguage = 'ja';
  
  // 開発モード設定
  static const bool isDevelopment = bool.fromEnvironment(
    'FLUTTER_DEBUG',
    defaultValue: false,
  );
  
  // APIキーが設定されているかチェック
  static bool get isSupabaseConfigured => 
    supabaseUrl != 'https://your-project.supabase.co' && 
    supabaseAnonKey != 'your-anon-key';
  
  static bool get isOpenAIConfigured => 
    openaiApiKey != 'sk-your-openai-api-key';
  
  static bool get isGoogleConfigured => 
    googleClientId != 'your-google-client-id' && 
    googleClientSecret != 'your-google-client-secret';
} 