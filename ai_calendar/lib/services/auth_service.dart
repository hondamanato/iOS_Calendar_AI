import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const String _guestUserIdKey = 'guest_user_id';
  static const String _guestUserEmailKey = 'guest_user_email';

  // 現在のユーザーを取得
  static User? get currentUser => _client.auth.currentUser;

  // ユーザーIDを取得
  static String? get currentUserId => currentUser?.id;

  // ユーザーがログインしているかチェック
  static bool get isLoggedIn => currentUser != null;

  // ゲストユーザーIDを取得
  static Future<String?> getGuestUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestUserIdKey);
  }

  // ゲストユーザーIDを保存
  static Future<void> saveGuestUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestUserIdKey, userId);
  }

  // ゲストユーザーメールアドレスを取得
  static Future<String?> getGuestUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_guestUserEmailKey);
  }

  // ゲストユーザーメールアドレスを保存
  static Future<void> saveGuestUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestUserEmailKey, email);
  }

  // ゲストユーザーIDを生成
  static String _generateGuestUserId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(10000);
    return 'guest_${timestamp}_$randomNum';
  }

  // ゲストユーザーメールアドレスを生成
  static String _generateGuestEmail() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(10000);
    return 'guest_${timestamp}_$randomNum@ai-calendar.local';
  }

  // ゲストユーザーとしてサインイン
  static Future<String> signInAsGuest() async {
    try {
      // 既存のゲストユーザーIDを確認
      String? guestUserId = await getGuestUserId();
      String? guestEmail = await getGuestUserEmail();

      if (guestUserId == null || guestEmail == null) {
        // 新しいゲストユーザーを作成
        guestUserId = _generateGuestUserId();
        guestEmail = _generateGuestEmail();
        
        // ローカルに保存
        await saveGuestUserId(guestUserId);
        await saveGuestUserEmail(guestEmail);
      }

      // Supabaseにゲストユーザーを登録
      await _registerGuestUser(guestUserId, guestEmail);
      
      print('ゲストユーザーとしてサインインしました: $guestUserId');
      return guestUserId;
    } catch (e) {
      print('ゲストサインインエラー: $e');
      rethrow;
    }
  }

  // ゲストユーザーをSupabaseに登録
  static Future<void> _registerGuestUser(String userId, String email) async {
    try {
      // usersテーブルにゲストユーザーを登録
      await _client.from('users').upsert({
        'id': userId,
        'email': email,
        'is_guest': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'id');
      
      print('ゲストユーザーをSupabaseに登録しました: $userId');
    } catch (e) {
      print('ゲストユーザー登録エラー: $e');
      // エラーが発生しても続行（ローカルデータベースは使用可能）
    }
  }

  // 匿名サインイン（テスト用）
  static Future<void> signInAnonymously() async {
    try {
      await _client.auth.signInAnonymously();
    } catch (e) {
      print('Error signing in anonymously: $e');
      rethrow;
    }
  }

  // サインアウト
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      // ゲストユーザー情報は保持（アプリ再起動時に再利用）
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // 認証状態の変更を監視
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // 現在のユーザーIDを取得（ゲストユーザー対応）
  static Future<String> getCurrentUserId() async {
    // まず認証済みユーザーを確認
    if (isLoggedIn && currentUserId != null) {
      return currentUserId!;
    }
    
    // ゲストユーザーIDを取得
    String? guestUserId = await getGuestUserId();
    if (guestUserId != null) {
      return guestUserId;
    }
    
    // 新しいゲストユーザーを作成
    return await signInAsGuest();
  }

  // ユーザー情報を取得
  static Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('ユーザー情報取得エラー: $e');
      return null;
    }
  }

  // ゲストユーザーかどうかチェック
  static Future<bool> isGuestUser(String userId) async {
    final userInfo = await getUserInfo(userId);
    return userInfo?['is_guest'] == true;
  }

  // ゲストユーザーを正式ユーザーに変換
  static Future<void> convertGuestToRegularUser(String email, String password) async {
    try {
      final guestUserId = await getCurrentUserId();
      
      // 新しいユーザーを作成
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        // ゲストユーザーのデータを新しいユーザーに移行
        await _migrateGuestData(guestUserId, response.user!.id);
        
        // ゲストユーザー情報をクリア
        await _clearGuestUserData();
        
        print('ゲストユーザーを正式ユーザーに変換しました');
      }
    } catch (e) {
      print('ゲストユーザー変換エラー: $e');
      rethrow;
    }
  }

  // ゲストユーザーのデータを移行
  static Future<void> _migrateGuestData(String guestUserId, String newUserId) async {
    try {
      // eventsテーブルのデータを移行
      await _client
          .from('events')
          .update({'user_id': newUserId})
          .eq('user_id', guestUserId);
      
      // chat_messagesテーブルのデータを移行
      await _client
          .from('chat_messages')
          .update({'user_id': newUserId})
          .eq('user_id', guestUserId);
      
      print('ゲストユーザーデータの移行が完了しました');
    } catch (e) {
      print('データ移行エラー: $e');
    }
  }

  // ゲストユーザー情報をクリア
  static Future<void> _clearGuestUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestUserIdKey);
    await prefs.remove(_guestUserEmailKey);
  }

  // アプリ初期化時の認証処理
  static Future<String> initializeAuth() async {
    try {
      // 認証済みユーザーがいる場合はそのまま使用
      if (isLoggedIn && currentUserId != null) {
        print('既存のユーザーでサインイン中: ${currentUserId}');
        return currentUserId!;
      }
      
      // ゲストユーザーとしてサインイン
      final guestUserId = await signInAsGuest();
      print('ゲストユーザーでサインイン: $guestUserId');
      return guestUserId;
    } catch (e) {
      print('認証初期化エラー: $e');
      // エラーが発生した場合はデフォルトのゲストIDを返す
      return 'guest_default_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
} 