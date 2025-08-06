# AI Calendar

自然言語でAIと会話し、自動でカレンダーに予定を記入できるFlutterアプリケーションです。

## 機能

- 📅 **カレンダー表示**: 月、週、日の表示形式でカレンダーを表示
- 🤖 **AIチャット**: 自然言語で予定を入力し、AIが自動でカレンダーイベントを提案
- 📱 **モダンUI**: Material Design 3を使用した美しいインターフェース
- 🔄 **リアルタイム同期**: Supabaseを使用したリアルタイムデータ同期
- 📊 **Google Calendar連携**: Google Calendarとの同期機能
- 👥 **参加者管理**: イベントに参加者を追加可能
- 🔐 **ユーザー認証**: ユーザー別のイベント管理

## 技術スタック

- **フレームワーク**: Flutter
- **言語**: Dart
- **AI**: OpenAI API (gpt-4o-mini)
- **データベース**: Supabase (PostgreSQL)
- **カレンダー連携**: Google Calendar API
- **状態管理**: Provider
- **UI**: Material Design 3

## セットアップ

### 1. 依存関係のインストール

```bash
flutter pub get
```

### 2. 環境変数の設定

`.env`ファイルを作成して、以下の内容を設定してください：

```env
# Supabase設定
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# OpenAI設定
OPENAI_API_KEY=sk-your-openai-api-key

# Google Calendar設定
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
```

### 3. Supabaseのセットアップ

1. [Supabase](https://supabase.com)でプロジェクトを作成
2. SQL Editorで以下のスクリプトを実行：

```sql
-- カレンダーイベントテーブル（拡張版）
CREATE TABLE IF NOT EXISTS events (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  location TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  is_all_day BOOLEAN DEFAULT FALSE,
  attendees TEXT[], -- 参加者のメールアドレス配列
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  is_synced_with_google BOOLEAN DEFAULT FALSE,
  google_event_id TEXT, -- Google CalendarのイベントID
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 既存のcalendar_eventsテーブルとの互換性のため
CREATE TABLE IF NOT EXISTS calendar_events (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  location TEXT,
  is_all_day BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- チャットメッセージテーブル
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  text TEXT NOT NULL,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_from_user BOOLEAN NOT NULL,
  suggested_events JSONB, -- 提案されたイベントのJSONデータ
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- インデックスの作成
CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_start_time ON events(start_time);
CREATE INDEX IF NOT EXISTS idx_events_end_time ON events(end_time);
CREATE INDEX IF NOT EXISTS idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages(timestamp);

-- RLS（Row Level Security）の設定
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のイベントのみアクセス可能
CREATE POLICY "Users can view own events" ON events
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own events" ON events
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own events" ON events
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own events" ON events
  FOR DELETE USING (auth.uid() = user_id);

-- ユーザーは自分のチャットメッセージのみアクセス可能
CREATE POLICY "Users can view own chat messages" ON chat_messages
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own chat messages" ON chat_messages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own chat messages" ON chat_messages
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own chat messages" ON chat_messages
  FOR DELETE USING (auth.uid() = user_id);

-- 更新日時を自動更新するトリガー関数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- トリガーの作成
CREATE TRIGGER update_events_updated_at 
  BEFORE UPDATE ON events 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_calendar_events_updated_at 
  BEFORE UPDATE ON calendar_events 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

### 4. OpenAI APIの設定

1. [OpenAI](https://platform.openai.com)でアカウントを作成
2. APIキーを取得
3. .envファイルに設定

### 5. Google Calendar APIの設定

1. [Google Cloud Console](https://console.cloud.google.com)でプロジェクトを作成
2. Google Calendar APIを有効化
3. サービスアカウントを作成
4. 認証情報をダウンロードして設定

## アプリの実行

```bash
flutter run -d chrome
```

## 使用方法

### カレンダー画面

- **月/週/日表示**: 下部のタブで表示形式を切り替え
- **予定の追加**: 右上の「+」ボタンまたはFABで予定を追加
- **予定の編集/削除**: 予定を長押ししてメニューから選択
- **参加者追加**: イベント作成時に参加者のメールアドレスを追加

### AIチャット画面

- **自然言語入力**: 「明日の午後2時に会議」のように入力
- **AI提案**: AIが自動でカレンダーイベントを提案
- **承認/拒否**: 提案されたイベントを承認または拒否

## データモデル

### Event クラス

```dart
class Event {
  final String id;                    // ユニークなID
  final String title;                 // 予定のタイトル
  final String? description;          // 予定の説明
  final String? location;             // 場所
  final DateTime startTime;           // 開始日時
  final DateTime endTime;             // 終了日時
  final bool isAllDay;                // 終日イベントかどうか
  final List<String>? attendees;      // 参加者のメールアドレス
  final String userId;                // イベントを作成したユーザーのID
  final bool isSyncedWithGoogle;      // Googleカレンダーと同期済みか
  final DateTime createdAt;           // 作成日時
  final DateTime updatedAt;           // 更新日時
}
```

## プロジェクト構造

```
lib/
├── models/           # データモデル
│   ├── event.dart              # 新しいEventクラス
│   ├── calendar_event.dart     # 既存のCalendarEventクラス
│   └── chat_message.dart       # チャットメッセージモデル
├── providers/        # 状態管理
│   ├── calendar_provider.dart
│   └── chat_provider.dart
├── screens/          # 画面
│   ├── calendar_screen.dart
│   └── chat_screen.dart
├── services/         # 外部API連携
│   ├── supabase_service.dart
│   ├── openai_service.dart
│   └── google_calendar_service.dart
├── utils/            # ユーティリティ
│   └── config.dart
└── main.dart         # エントリーポイント
```

## 開発者向け情報

### アーキテクチャ

- **MVVM + Provider**: 状態管理にProviderを使用
- **Repository Pattern**: データアクセス層を抽象化
- **Service Layer**: 外部APIとの連携を分離

### テスト

```bash
flutter test
```

### ビルド

```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## ライセンス

MIT License

## 貢献

プルリクエストやイシューの報告を歓迎します。
