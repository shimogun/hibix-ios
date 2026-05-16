# Hibix — Product Requirements Document (PRD)

**バージョン**: v2.1 (Cloudflare Workers + D1 へのバックエンド正規化)
**作成日**: 2026-05-15
**最終更新**: 2026-05-15 (v2.0 → v2.1: 設計書 v0.7 §15 引き継ぎ反映)
**読み手**: Claude Code（AIコーディングエージェント）
**目的**: Phase 1 (MVP / v0.1) の実装仕様書

---

## 0. メタ情報

### 0.1 この PRD の使い方
このドキュメントは **Claude Code が読んで実装する** ことを唯一の目的とする。人間向けの説得・マーケ・KPI などはここに書かない。各機能は「DONE の定義」を持ち、Claude Code が自己判定で実装完了を宣言できる粒度で記述されている。

### 0.2 参照ファイル
- `/Users/a/Desktop/Hibix_design_v0.7.md` — 設計書 v0.7（背景・思想、本書 v2.1 の根拠）
- `/Users/a/Desktop/Hibix_ekytoyo_review_analysis.md` — 競合分析 v1.0
- `/Users/a/Desktop/Hibix_PRD_reference_v1.md` — 旧PRD（v2.0で本書に置換）

### 0.3 確定事項サマリー（変更不可・実装はこの前提に従う）

| 項目 | 確定値 |
|---|---|
| プラットフォーム | iOS Native |
| 開発言語 | Swift 5.10+ |
| UIフレームワーク | SwiftUI |
| 最低OSバージョン | iOS 17.0 |
| ローカル永続化 | GRDB.swift |
| 認証方式 | 匿名UUID（iOS Keychain で iCloud 同期） |
| 課金 | StoreKit 2、¥2,800 買い切り商品 1点 |
| バックエンド | Cloudflare Workers（Wrangler 3.x / TypeScript 5.x） |
| サーバーDB | Cloudflare D1（SQLite） |
| メール送信 | Resend |
| 定期実行 | Cloudflare Cron Triggers（15分間隔） |
| ローンチ言語 | 日本語のみ |
| 通貨/価格 | JPY ¥2,800（PPP は v0.2 以降） |

### 0.4 用語定義

| 用語 | 定義 |
|---|---|
| Entitlement | ユーザーが買い切りProを所有しているか否かのフラグ。`Bool` 値 1 つ |
| チェックイン | ユーザーが気分タップを完了した行為 |
| しきい値 | 「最終チェックイン + 見守り期間日数」によって決まる、メール発火の境界時刻 |
| 緊急連絡先 | しきい値到達時にメール通知される宛先（最大3件） |
| 見守り期間 | ユーザーが設定する 1〜7 日（初期値 2日） |

---

## 1. プロダクト要約

> Hibix は、毎日のひとタップで気分を記録し、設定日数タップが無ければ緊急連絡先にメール通知が届く iOS アプリ。

| 項目 | 値 |
|---|---|
| 1行コンセプト | 「毎日のひとタップが、自分のメンタル日記になり、誰かを安心させる」 |
| 主要ユースケース | 自己メンタル記録 / 一人暮らしの安否確認 / 離れた親への見守りギフト |
| 差別化 | メンタル日記 × 安否確認のハイブリッド、買い切り¥2,800、データ100%ローカル |
| 価格 | 無料 + 買い切りPro ¥2,800（IAP 1点のみ） |
| 対象 OS | iOS 17.0 以降 |

---

## 2. 技術スタック確定

### 2.1 iOS アプリ

| 領域 | 採用技術 | バージョン | 用途 |
|---|---|---|---|
| 言語 | Swift | 5.10+ | — |
| UI | SwiftUI | iOS 17 SDK | 全画面 |
| 永続化（DB） | GRDB.swift | 6.x | ローカル SQLite アクセス |
| Keychain | KeychainAccess | 4.x | UUID・購入状態の安全保存 |
| 課金 | StoreKit 2 | iOS 17 SDK | 買い切り商品・購入復元 |
| 認証 | iOS Keychain (kSecAttrSynchronizable=true) | — | 匿名UUIDを iCloud Keychain で同期 |
| ローカル通知 | UserNotifications | iOS 17 SDK | 朝/夜通知・48h/24h リマインダー |
| HTTP | URLSession + async/await | iOS 17 SDK | サーバーへの ping/設定送信 |
| JSON | Codable | iOS 17 SDK | API リクエスト/レスポンス |
| テスト | XCTest | iOS 17 SDK | ユニット・統合 |

**禁止事項**:
- 第三者解析 SDK（Firebase Analytics、Mixpanel等）一切禁止
- 第三者広告 SDK 一切禁止
- ATT（App Tracking Transparency）プロンプト不要な設計

### 2.2 バックエンド

| 領域 | 採用技術 | バージョン | 用途 |
|---|---|---|---|
| ホスティング | Cloudflare Workers | Wrangler 3.x | サーバーレス API |
| ランタイム | V8 Isolate (Workers Runtime) | — | エッジ実行環境 |
| フレームワーク | Hono | 4.x | fetch handler ルーティング |
| 言語 | TypeScript | 5.x | — |
| DB | Cloudflare D1 (SQLite) | — | last_checkin_time / 緊急連絡先 |
| ORM | Drizzle ORM (`drizzle-orm/d1` アダプター) | 0.36+ | 型安全クエリ |
| メール | Resend | — | 緊急通知メール送信 |
| Cron | Cloudflare Cron Triggers | — | 15分ごとのしきい値チェック |
| 暗号化 | Web Crypto API (AES-256-GCM) | — | emergency_email 暗号化 |
| シークレット管理 | `wrangler secret` | — | API キー / AES 鍵の保管 |
| デプロイ | `wrangler deploy` | — | preview / production |

**Cloudflare 採用根拠**（設計書 v0.7 §5.1 確定事項）:
- 商用利用無料スタート可（Vercel Pro $20/月不要）
- DDoS / WAF / Bot Fight Mode が無料枠標準
- 10万 DAU まで無料枠内
- D1 が SQLite 互換、端末側 GRDB とスキーマ表現を揃えやすい

### 2.3 開発環境

| 項目 | 値 |
|---|---|
| Xcode | 16.0+ |
| Swift Package Manager | 依存解決方式（CocoaPods/Carthage 不使用） |
| Node.js | 24.x LTS |
| パッケージマネージャ（BE） | pnpm |
| Git | リポジトリ 2 分割: `hibix-ios` / `hibix-backend` |

### 2.4 依存パッケージ完全リスト（バージョン固定）

**iOS（Package.swift）**:
```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
    .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
]
```

**Backend（package.json）**:
```json
{
  "dependencies": {
    "hono": "4.6.0",
    "drizzle-orm": "0.36.0",
    "resend": "4.0.0",
    "zod": "3.23.0"
  },
  "devDependencies": {
    "wrangler": "3.80.0",
    "@cloudflare/workers-types": "4.20241011.0",
    "typescript": "5.6.0",
    "drizzle-kit": "0.28.0"
  }
}
```

**注**: Workers ランタイムは Node.js ではないため、`@neondatabase/serverless` / `next` / `react` 依存は不要。`@types/node` も使わず `@cloudflare/workers-types` で型を取る。

---

## 3. プロジェクト構造

### 3.1 iOS リポジトリ（`hibix-ios`）

```
hibix-ios/
├── Hibix.xcodeproj/
├── Hibix/
│   ├── App/
│   │   ├── HibixApp.swift              // @main エントリ
│   │   └── AppDependencies.swift       // 依存注入コンテナ
│   ├── Features/
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── HomeViewModel.swift
│   │   │   └── PixelCalendarView.swift
│   │   ├── MoodEntry/
│   │   │   ├── MoodPickerView.swift
│   │   │   └── MoodMemoView.swift
│   │   ├── EntryDetail/
│   │   │   └── EntryDetailView.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingFlow.swift
│   │   │   └── OnboardingPages.swift
│   │   ├── Paywall/
│   │   │   ├── PaywallView.swift
│   │   │   └── PaywallViewModel.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── ModeSwitchView.swift
│   │       ├── EmergencyContactsView.swift
│   │       └── DataDeletionView.swift
│   ├── Core/
│   │   ├── Database/
│   │   │   ├── DatabaseManager.swift     // GRDB DatabasePool
│   │   │   ├── Migrations.swift          // スキーマ移行
│   │   │   ├── MoodEntryRepository.swift
│   │   │   └── SettingsRepository.swift
│   │   ├── Models/
│   │   │   ├── MoodEntry.swift
│   │   │   ├── MoodLevel.swift           // enum 1-7
│   │   │   ├── WatchMode.swift           // enum solo/gentle/daily
│   │   │   └── EmergencyContact.swift
│   │   ├── Networking/
│   │   │   ├── APIClient.swift
│   │   │   ├── APIEndpoint.swift
│   │   │   └── APIError.swift
│   │   ├── Keychain/
│   │   │   └── KeychainStore.swift       // UUID/Entitlement永続化
│   │   ├── Notifications/
│   │   │   ├── NotificationScheduler.swift
│   │   │   └── NotificationContent.swift
│   │   ├── Entitlement/
│   │   │   ├── EntitlementManager.swift  // StoreKit 2 監視
│   │   │   └── FeatureGate.swift         // 機能ゲーティング判定
│   │   ├── Security/
│   │   │   └── AppLockManager.swift      // Face ID / Passcode
│   │   └── Accessibility/
│   │       └── A11yHelpers.swift
│   ├── Resources/
│   │   ├── Assets.xcassets
│   │   ├── Localizable.strings           // ja.lproj
│   │   └── Info.plist
│   └── Utilities/
│       ├── DateFormatter+Hibix.swift
│       └── Color+MoodPalette.swift
├── HibixTests/
│   ├── DatabaseTests/
│   ├── EntitlementTests/
│   ├── NotificationTests/
│   └── ModelTests/
└── Package.swift
```

### 3.2 Backend リポジトリ（`hibix-backend`）

```
hibix-backend/
├── wrangler.toml                                // Workers 設定（bindings / cron / vars）
├── src/
│   ├── index.ts                                 // fetch handler エントリポイント
│   ├── routes/
│   │   ├── checkin.ts                           // POST /api/checkin
│   │   ├── settings.ts                          // PATCH /api/settings
│   │   ├── contacts.ts                          // PUT /api/contacts
│   │   └── account.ts                           // DELETE /api/account
│   ├── cron/
│   │   └── checkin-monitor.ts                   // scheduled() ハンドラ
│   ├── db/
│   │   ├── schema.ts                            // Drizzle スキーマ（SQLite）
│   │   └── client.ts                            // drizzle(D1) ファクトリ
│   ├── lib/
│   │   ├── crypto.ts                            // Web Crypto AES-256-GCM
│   │   ├── email.ts                             // Resend クライアント
│   │   └── auth.ts                              // X-Hibix-UUID ヘッダ検証
│   └── validation/
│       └── schemas.ts                           // Zod スキーマ
├── migrations/
│   └── 0001_initial.sql                         // D1 マイグレーション
├── drizzle.config.ts
├── package.json
└── tsconfig.json
```

**`wrangler.toml` の主要設定**:
```toml
name = "hibix-backend"
main = "src/index.ts"
compatibility_date = "2026-05-15"

[[d1_databases]]
binding = "DB"
database_name = "hibix-db"
database_id = "<set after `wrangler d1 create`>"

[triggers]
crons = ["*/15 * * * *"]
```

シークレット（`HIBIX_AES_KEY` / `RESEND_API_KEY` / `CRON_SECRET`）は `wrangler secret put` で登録し、`wrangler.toml` には書かない。

### 3.3 命名規則

- Swift: **PascalCase**（型・View）/ **camelCase**（変数・関数）
- TypeScript: **camelCase**（変数）/ **PascalCase**（型・コンポーネント）
- DB カラム: **snake_case**
- API パス: **kebab-case** ではなく **小文字単語**（例: `/api/checkin`）
- ファイル名 Swift: 型名と一致
- ファイル名 TS: kebab-case

---

## 4. データモデル

### 4.1 ローカル DB（iOS / GRDB / SQLite）

ファイル: `Documents/hibix.sqlite`

```sql
-- マイグレーション v1: 初期スキーマ

CREATE TABLE mood_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entry_date TEXT NOT NULL UNIQUE,         -- 'YYYY-MM-DD'（端末ローカルタイム）
    mood_level INTEGER NOT NULL CHECK(mood_level BETWEEN 1 AND 7),
    memo TEXT,                                -- 最大500文字、NULL可
    created_at TEXT NOT NULL,                 -- ISO 8601
    updated_at TEXT NOT NULL                  -- ISO 8601
);

CREATE INDEX idx_mood_entries_date ON mood_entries(entry_date);

CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- 既知 key:
-- 'watch_mode'        : 'solo' | 'gentle' | 'daily'  （default 'solo'）
-- 'watch_days'        : '1'〜'7'                      （default '2'）
-- 'morning_notify'    : 'HH:mm' or 'off'              （default '09:00'）
-- 'evening_notify'    : 'HH:mm' or 'off'              （default '21:00'）
-- 'app_lock_enabled'  : 'true' | 'false'              （default 'false', 有料のみ true 化可能）
-- 'onboarding_done'   : 'true' | 'false'              （default 'false'）
-- 'last_synced_at'    : ISO 8601                      （サーバー最終同期時刻）

CREATE TABLE emergency_contacts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL,
    label TEXT,                               -- 表示名（例: 'お母さん'）NULL可
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);
```

**保存制約**:
- `mood_entries.memo` は UTF-16 換算 500 文字まで（Swift `String.count` で判定）
- 1日に複数回タップした場合は既存レコードを UPDATE（`entry_date` UNIQUE）

### 4.2 サーバー DB（Cloudflare D1 / SQLite / Drizzle）

D1 は SQLite 互換のため、Drizzle スキーマは `drizzle-orm/sqlite-core` を使用。タイムスタンプは Unix epoch（秒）を `integer` で保存、boolean は `integer`（0/1）。UUID は `text` フィールドにアプリ側で `crypto.randomUUID()` 値を入れる。

```typescript
// src/db/schema.ts
import { sql } from 'drizzle-orm';
import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const users = sqliteTable('users', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  anonymous_uuid: text('anonymous_uuid').notNull().unique(),  // 端末発行のUUID
  last_checkin_at: integer('last_checkin_at', { mode: 'timestamp' }).notNull(),
  watch_days: integer('watch_days').notNull().default(2),     // 1-7
  watch_mode: text('watch_mode', { enum: ['solo', 'gentle', 'daily'] }).notNull().default('solo'),
  is_pro: integer('is_pro', { mode: 'boolean' }).notNull().default(false),
  created_at: integer('created_at', { mode: 'timestamp' }).notNull().default(sql`(unixepoch())`),
  updated_at: integer('updated_at', { mode: 'timestamp' }).notNull().default(sql`(unixepoch())`),
});

export const emergencyContacts = sqliteTable('emergency_contacts', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  user_id: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  email_encrypted: text('email_encrypted').notNull(),         // AES-256-GCM ciphertext (base64)
  email_iv: text('email_iv').notNull(),                       // IV (base64)
  email_tag: text('email_tag').notNull(),                     // GCM auth tag (base64)
  label: text('label'),
  sort_order: integer('sort_order').notNull().default(0),
  created_at: integer('created_at', { mode: 'timestamp' }).notNull().default(sql`(unixepoch())`),
});

export const notificationLogs = sqliteTable('notification_logs', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  user_id: text('user_id').notNull().references(() => users.id, { onDelete: 'cascade' }),
  type: text('type', { enum: ['alert'] }).notNull(),
  sent_at: integer('sent_at', { mode: 'timestamp' }).notNull().default(sql`(unixepoch())`),
  delivery_status: text('delivery_status', { enum: ['sent', 'failed', 'bounced'] }).notNull(),
  resend_message_id: text('resend_message_id'),
});

export const deletionRequests = sqliteTable('deletion_requests', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  anonymous_uuid: text('anonymous_uuid').notNull(),
  requested_at: integer('requested_at', { mode: 'timestamp' }).notNull().default(sql`(unixepoch())`),
  completed_at: integer('completed_at', { mode: 'timestamp' }),
});
```

**スキーマ移行注意**:
- Postgres の `uuid` → SQLite では `text` + `crypto.randomUUID()`
- `timestamp(withTimezone)` → `integer({mode:'timestamp'})`（UTC Unix epoch 秒）
- `boolean` → `integer({mode:'boolean'})`（0/1）
- `defaultNow()` → `sql\`(unixepoch())\``
- テーブル数・カラム名・関係性は v2.0 から変更なし

**サーバーに保存しないもの（厳守）**:
- 気分タップの内容（mood_level）
- 日記メモ本文
- ピクセル履歴
- ユーザー氏名・氏名らしき情報

### 4.3 Keychain 保存項目

| key | 値 | iCloud同期 | アクセス制御 |
|---|---|:---:|---|
| `hibix.anonymous_uuid` | UUID v4 文字列 | ✅ | `kSecAttrAccessibleAfterFirstUnlock` |
| `hibix.entitlement.pro` | `"true"` or `"false"` | ✅ | `kSecAttrAccessibleAfterFirstUnlock` |

**ルール**:
- `anonymous_uuid` は初回起動時に発行し、Keychain (synchronizable=true) に保存
- 端末復元/機種変時は iCloud Keychain 経由で復元されることを期待
- 万一 UUID 喪失時は新UUID発行・サーバーへ移行リクエストエンドポイント不要（v0.1では未対応・対象外）

### 4.4 UserDefaults 保存項目

UserDefaults は **永続化目的では使用しない**。一時状態（直近表示画面など）のみ可。設定は必ず `settings` テーブルへ。

---

## 5. 機能ゲーティング仕様

### 5.1 Entitlement の単一ソース

```swift
// Core/Entitlement/EntitlementManager.swift

actor EntitlementManager {
    static let shared = EntitlementManager()
    private(set) var isPro: Bool = false

    // 起動時に StoreKit 2 の Transaction.currentEntitlements を確認
    // 結果を Keychain `hibix.entitlement.pro` に書き込み
    // オフライン時は Keychain の値を信頼

    func refresh() async { /* StoreKit 2 Transaction.currentEntitlements */ }
    func observe() async { /* Transaction.updates を監視 */ }
}
```

### 5.2 機能と境界マッピング（完全表）

| 機能ID | 機能名 | 無料層 | 有料層 |
|---|---|:---:|:---:|
| F-01 | 気分タップ | ✅ | ✅ |
| F-02 | 日記メモ（500文字） | ✅ | ✅ |
| F-03 | 日別詳細表示 | ✅ | ✅ |
| F-04 | ピクセルカレンダー | 直近365日ローリングウィンドウのみ表示 | 全期間スクロール可 |
| F-05 | チェックイン通知（朝/夜） | ✅ | ✅ |
| F-06 | モード設定 | `solo` 固定 | 3モード切替可 |
| F-07 | 緊急連絡先メール通知 | ❌ | ✅ |
| F-08 | Face ID / パスコードロック | ❌ | ✅ |
| F-09 | 2段階リマインダー（48h/24h） | ❌（安否機能セット） | ✅ |
| F-10 | アクセシビリティ最小セット | ✅ | ✅ |
| F-11 | データ削除権 | ✅ | ✅ |
| F-12 | StoreKit 2 統合 | ✅（購入導線） | — |
| F-13 | 機能ゲーティング判定 | ✅ | ✅ |
| F-14 | 購入復元機能 | ✅ | ✅ |

### 5.3 StoreKit 2 商品仕様

| 商品ID | 種類 | 価格 | 用途 |
|---|---|---|---|
| `com.shimogun.hibix.pro.lifetime` | Non-Consumable | ¥2,800 | 買い切りPro |

**App Store Connect 設定**:
- 価格層: Tier 18（¥2,800 / $19.99 / EUR 19,99）
- ローカリゼーション: 日本語のみ

### 5.4 購入状態の取得・キャッシュ

```
起動時:
  1. Keychain から `hibix.entitlement.pro` 読み込み → 即座に UI に反映
  2. 非同期で StoreKit 2 `Transaction.currentEntitlements` を取得
  3. 差分があれば Keychain 更新 + UI 更新
  4. `Transaction.updates` を購読し続け、購入/失効に追従
```

オフライン時は Keychain の値を最後の真実として動作。

### 5.5 購入復元フロー

設定画面に「購入を復元」ボタンを配置。タップで `AppStore.sync()` を呼び、完了後に `EntitlementManager.refresh()`。

### 5.6 ペイウォール表示トリガー

無料ユーザーが以下に到達した時にペイウォール（`PaywallView`）を表示:
- 設定画面で `solo` 以外のモード選択を試みた時
- 緊急連絡先追加ボタンタップ時
- アプリロック有効化トグル ON 時
- ピクセルカレンダーで1年より過去にスクロール試行時
- ホーム画面のメニューから「Pro にアップグレード」明示タップ時

---

## 6. 機能仕様

### F-01 気分タップ

**概要**: 5〜7段階の色グラデーションから当日の気分を1つ選んで保存。
**Entitlement**: 全層
**UI 要件**:
- ホーム画面下部に7色の丸ボタンを横一列配置
- 各ボタン直径 56pt（最小タップ領域 44pt 余裕越え）
- タップで即座にハプティクス（`UIImpactFeedbackGenerator.medium`）
- タップ後 0.1 秒以内にカラーフィルが伝播するアニメーション

**データフロー**:
```
タップ
  ↓
今日(entry_date=今日のYYYY-MM-DD)のレコードを UPSERT
  ├ 既存: mood_level / updated_at を更新
  └ 新規: INSERT
  ↓
ピクセルカレンダー再描画
  ↓
バックグラウンドで POST /api/checkin（last_checkin_at 更新）
  ├ 成功: settings.last_synced_at 更新
  └ 失敗: 次回起動時/タップ時にリトライ
```

**受け入れ基準**:
- [ ] 7段階すべてのボタンが表示される
- [ ] タップ後 100ms 以内にローカルDBに記録される
- [ ] 同日内の再タップで上書きされる（UNIQUE制約）
- [ ] ハプティクスが発火する
- [ ] オフラインでもローカル保存は完了する
- [ ] ネットワーク復帰時にサーバー ping が送られる

---

### F-02 日記メモ

**概要**: 気分タップ後、任意で 500文字までのメモを添付。
**Entitlement**: 全層
**UI 要件**:
- 気分タップ後にシート（`.sheet`）で表示。スキップ可
- `TextEditor` を中央配置、フォーカス自動取得
- 右上に「保存」、左上に「スキップ」
- 文字数カウンター: `現在文字数 / 500`、超過時は赤字＋保存ボタン無効化

**データフロー**:
- 「保存」タップで `memo` カラム UPDATE
- 「スキップ」または閉じるで `memo = NULL` のまま

**受け入れ基準**:
- [ ] 500文字制限が UI と DB の両方で機能する
- [ ] 空白のみのメモは NULL として扱う
- [ ] 過去日の編集も可能（後述 F-03 から）

---

### F-03 日別詳細表示

**概要**: ピクセルカレンダーの 1 セルをタップすると、その日の気分・メモを表示・編集できる画面に遷移。
**Entitlement**: 全層
**UI 要件**:
- 上部に日付、その下に大きな気分カラー、その下にメモ
- 右上に「編集」ボタン → 気分再選択 + メモ編集モードへ
- 記録がない日: 「記録なし」表示 + 「今この日に記録する」ボタン（過去日入力可）

**受け入れ基準**:
- [ ] 過去日の編集ができる
- [ ] 未来日タップは無効（タップしても何も起きない）
- [ ] 編集後にカレンダーが即時更新される

---

### F-04 ピクセルカレンダー

**概要**: GitHub コントリビューションカレンダー風の年間気分カレンダー。
**Entitlement**:
- 無料: 直近365日ローリングウィンドウのみ表示。今日を右端、`今日 - 364日` を左端とする365セル。日が進むたびに最も古い1日が表示から外れる（GitHub コントリビューションカレンダーと同挙動）。それ以前へのスクロール不可。実装ロジック: `WHERE entry_date >= date('now','-364 days')`（端末ローカルタイム基準）
- 有料: 全期間スクロール可（インストール日まで遡れる）

**重要**: 範囲外データは「削除」ではなく「表示外」。有料化したら過去データはすべて即時表示される（データは消えない）。

**UI 要件**:
- 7行 × 53週グリッド
- 1セル: 12pt × 12pt、間隔 2pt
- 未記録セル: グレー（`#E5E7EB`）
- 記録セル: 気分カラー（下記パレット参照）
- 今日セル: 太枠ハイライト
- ヘッダーに月名ラベル

**カラーパレット**（mood_level → HEX）:
```
1: #4A5568  落ち込み
2: #4299E1  沈み
3: #38B2AC  平静
4: #ECC94B  普通
5: #ED8936  良い
6: #9F7AEA  高揚
7: #F687B3  最高
```

**受け入れ基準**:
- [ ] 1年分（365セル）が iPhone SE 第3世代でも縦に収まる
- [ ] 横スクロールで月送りができる
- [ ] 無料ユーザーが1年より過去にスクロールしようとすると `PaywallView` が出る
- [ ] セルタップで F-03 へ遷移

---

### F-05 チェックイン通知（朝/夜）

**概要**: 設定時刻にローカル通知を発火。
**Entitlement**: 全層
**UI 要件**:
- 設定画面で朝/夜それぞれの時刻を `DatePicker(.hourAndMinute)` で設定
- 各通知は ON/OFF 個別切替可

**ロジック**:
- iOS 通知許可未取得時はオンボーディング最終画面で `requestAuthorization` を1回トライ
- 通知の `identifier`:
  - `hibix.daily.morning`
  - `hibix.daily.evening`
- 通知タップでアプリ起動 → ホーム画面（タップ未完了なら気分ピッカーをモーダル表示）

**通知本文**（日本語固定文）:
```
朝: 「今日のひとピクセル、つけにいきましょう」
夜: 「今日のヒビ、ぽちっと記録」
```

**受け入れ基準**:
- [ ] 朝/夜の通知が指定時刻に発火する
- [ ] 通知許可未取得状態でも設定操作はできる（発火しないだけ）
- [ ] 通知から起動で気分ピッカーがモーダル表示される

---

### F-06 3モード切替

**概要**: 見守り動作モードを `solo` / `gentle` / `daily` から選択。
**Entitlement**:
- 無料: `solo` 固定（他を選ぼうとするとペイウォール）
- 有料: 3モード自由切替

**モード定義**:
| モード | 識別子 | 動作 |
|---|---|---|
| おひとりさま | `solo` | 緊急連絡先メール通知を**発火しない** |
| ゆるつながり | `gentle` | しきい値到達時のみ緊急連絡先へメール送信 |
| まいにち共有 | `daily` | しきい値到達時送信 + **毎日のチェックイン時** にも送信 ※v0.1では `gentle` と同じ挙動（後述） |

**v0.1 のスコープ警告**: `daily` モードの「毎日メール」機能はメール送信頻度が高く、コスト/迷惑メール懸念がある。**v0.1 では `daily` を選択可能だが内部挙動は `gentle` と同じ**とする（UIに「※毎日通知は次期アップデート」と注記）。サーバー DB の `watch_mode` カラムには選択値を保存しておく。

**UI 要件**:
- 設定画面 > 見守りモード セグメントピッカー
- 選択時、無料ユーザーかつ `solo` 以外を選ぶとペイウォール表示
- 各モードの説明文を下部に表示

**受け入れ基準**:
- [ ] 無料ユーザーは `solo` 以外を実選択できない（UI はグレーアウトでもタップ時ペイウォールでも可）
- [ ] 有料ユーザーは自由切替できる
- [ ] 選択値はローカル DB + サーバー DB の両方に保存される
- [ ] `daily` 選択時に注記が表示される

---

### F-07 緊急連絡先メール通知

**概要**: しきい値（最終チェックイン + watch_days）到達時に緊急連絡先メールアドレスへ通知メール送信。
**Entitlement**: 有料のみ

**緊急連絡先**:
- 最大3件まで登録可
- メールアドレス（必須）+ 表示ラベル（任意・例「お母さん」）
- 端末側ローカル DB に平文保存、サーバー側は AES-256-GCM 暗号化保存

**メール本文（固定・日本語）**:
```
件名: Hibix からのお知らせ
本文:
  {label or 「ご家族」} さん

  Hibix を利用している方からのチェックインが {watch_days} 日間ありません。
  最終チェックイン日時: {YYYY年MM月DD日 HH:MM}

  一度連絡を取ってみてください。

  ※このメールは Hibix アプリの安否確認機能から自動送信されています。
  ※医療代替・緊急通報サービスではありません。緊急時は119等にご連絡ください。
```

**送信元**: `Hibix <noreply@hibix.app>`（Resend で送信ドメイン認証済み前提）

**受け入れ基準**:
- [ ] 緊急連絡先未登録 + `gentle`/`daily` 選択時に「連絡先を登録してください」エラー表示
- [ ] サーバー Cron がしきい値到達ユーザーを検出してメール送信する
- [ ] 同一しきい値到達で重複送信しない（後述 §9 タイマーリセット）
- [ ] メール本文に医療代替ではない旨が明記される

---

### F-08 Face ID / パスコードロック

**概要**: アプリ起動時に Face ID（または端末パスコード）認証を要求。
**Entitlement**: 有料のみ
**UI 要件**:
- 設定画面でトグル
- 有効化時、`LocalAuthentication` で 1 回認証成功させてから保存
- 失敗時はアプリは見られないが「もう一度」ボタン表示

**実装**:
- `LAContext.evaluatePolicy(.deviceOwnerAuthentication)`
- バックグラウンド → フォアグラウンド遷移時にも再認証要求
- 認証成功までホーム画面はブラーオーバーレイで隠す

**受け入れ基準**:
- [ ] トグル ON で起動時認証が動作する
- [ ] バックグラウンド復帰時にも再認証が要求される
- [ ] Face ID 失敗3回後にパスコード入力にフォールバックする（iOS標準）

---

### F-09 2段階リマインダー（48h / 24h）

**概要**: しきい値到達の 48時間前 / 24時間前に本人へローカル通知でリマインダー。
**Entitlement**: 有料のみ（安否機能とセット）

**スケジュール**:
- チェックイン完了時に次のしきい値（最終チェックイン + watch_days）を計算
- しきい値の 48時間前と 24時間前に `UNNotificationRequest` を予約
- 次のチェックインが発生したら過去予約を全キャンセルして再スケジュール

**通知 identifier**:
- `hibix.reminder.48h`
- `hibix.reminder.24h`

**通知本文（日本語固定文）**:
```
48h前: 「{watch_days}日間記録がありません。あと2日でご家族にお知らせメールが届きます」
24h前: 「明日にはご家族へお知らせが届きます。今日ぜひ記録を」
```

**watch_days = 1 の場合**: 48h 前リマインダーは過去時刻になりうるため、その場合は予約しない（24h前のみ）。

**受け入れ基準**:
- [ ] チェックインのたびに過去のリマインダーがキャンセルされ再スケジュールされる
- [ ] 無料ユーザーには予約されない（有料化と同時に予約開始）
- [ ] 解約相当（v0.1 では発生しないが）または `solo` モード時は予約されない

---

### F-10 アクセシビリティ最小セット

**概要**: VoiceOver / Dynamic Type / 巨大タップ領域を最低ラインで対応。
**Entitlement**: 全層

**必須対応**:
- すべての操作可能要素に `.accessibilityLabel` を付与
- 気分カラー要素には「気分 {N}, {ラベル}」（例「気分5、良い」）
- ピクセルカレンダー各セルに `.accessibilityLabel("{月}月{日}日, 気分{N}")`
- Dynamic Type: `Font.body` 等の標準サイズ系を使用、固定 pt 禁止（カレンダーセルなど一部例外可）
- 最小タップ領域 44pt × 44pt（Apple HIG）

**対象外（v0.1）**:
- Reduce Motion 対応（v0.2）
- Increase Contrast 対応（v0.2）

**受け入れ基準**:
- [ ] VoiceOver でホーム→気分タップ→詳細→設定 まで操作完結
- [ ] 全要素にラベルがある（Accessibility Inspector で穴ゼロ）
- [ ] 最大 Dynamic Type サイズ（xxxLarge）で文字切れがない

---

### F-11 データ削除権

**概要**: ユーザーがアプリ内から「データを削除」を実行すると、48時間以内にローカル + サーバー上の全データが消去される。
**Entitlement**: 全層

**フロー**:
```
設定 > データを削除
  ↓
警告ダイアログ（取り消し不可と明示）
  ↓
ユーザー確定
  ↓
ローカル: GRDB DB ファイル削除 + Keychain クリア + UserDefaults リセット
  ↓
サーバー: DELETE /api/account（anonymous_uuid をリクエスト）
  ├ 即時: deletion_requests に挿入、users 行を論理削除
  └ Cloudflare Cron Triggers の scheduled() 内で 48時間以内に物理削除 + notification_logs 削除
  ↓
アプリは初回起動状態に戻る（オンボーディングへ）
```

**法令対応**:
- 個人情報保護法 第30条（保有個人データの利用停止）対応
- 削除要求受理から 48時間以内の完全消去を保証
- 削除完了ログは `deletion_requests.completed_at` に記録

**受け入れ基準**:
- [ ] 削除実行後にアプリが初回起動状態に戻る
- [ ] サーバー側で 48時間以内に物理削除される
- [ ] 削除中に再起動しても整合性が保たれる（再削除しても無害）

---

### F-12 StoreKit 2 統合

**概要**: 買い切り商品 `com.shimogun.hibix.pro.lifetime` の購入フロー。
**Entitlement**: 購入導線として全層

**実装ポイント**:
- `Product.products(for: ["com.shimogun.hibix.pro.lifetime"])` で取得
- 購入: `product.purchase()` → `Transaction.verified` 判定
- 失敗時のユーザー向け表示: 「購入に失敗しました。時間を置いて再度お試しください」
- 起動時に `Transaction.updates` を購読

**ペイウォール画面（`PaywallView`）構成**:
- ヘッダー: 「Hibix Pro」
- 価格: ¥2,800 一度きり
- ベネフィット 4 行:
  1. すべての見守りモード解禁
  2. 緊急連絡先メール通知
  3. Face ID ロック
  4. 全期間のピクセルカレンダー
- CTA: 「¥2,800 で購入」（大）
- サブテキスト: 「購入を復元」リンク
- 下部: 利用規約・プライバシーポリシーリンク

**受け入れ基準**:
- [ ] Sandbox 環境で購入完了 → Entitlement 反映が 3 秒以内
- [ ] 購入キャンセルでエラー表示が出ない（ユーザー操作として扱う）
- [ ] 失敗時にリトライ可能

---

### F-13 機能ゲーティング判定

**概要**: 全機能の Entitlement 判定を `FeatureGate` 経由に統一。
**Entitlement**: 内部仕組み

**API**:
```swift
enum Feature {
    case modeSwitch        // F-06
    case emergencyContact  // F-07
    case appLock           // F-08
    case reminders         // F-09
    case fullPixelHistory  // F-04 全期間
}

struct FeatureGate {
    static func isAllowed(_ feature: Feature) async -> Bool {
        await EntitlementManager.shared.isPro
    }
}
```

**呼び出しルール**:
- UI 表示時の制御
- アクション実行直前のチェック
- 「サーバー側での再チェック不要」（v0.1 ではサーバーは Entitlement を信頼しない設計に依存しない）

**受け入れ基準**:
- [ ] 全 5 Feature が単一 enum で網羅されている
- [ ] 機能追加時に enum を増やすだけで判定箇所が増えない設計

---

### F-14 購入復元機能

**概要**: 機種変更時に既購入を復元。
**Entitlement**: 全層

**UI**:
- ペイウォール下部の「購入を復元」リンク
- 設定 > 「購入を復元」項目

**実装**:
```swift
try await AppStore.sync()
await EntitlementManager.shared.refresh()
```

**受け入れ基準**:
- [ ] 同じ Apple ID の機種で復元が成功する
- [ ] 未購入アカウントで復元してもエラー表示せず「購入履歴がありません」と表示

---

## 7. 画面仕様

### 7.1 画面一覧

| 画面 | ファイル | 役割 |
|---|---|---|
| ホーム | `HomeView` | ピクセルカレンダー + 気分タップ |
| 気分ピッカー | `MoodPickerView` | 7段階タップ（モーダル） |
| メモ入力 | `MoodMemoView` | 500文字メモ（シート） |
| 日別詳細 | `EntryDetailView` | 過去日表示・編集 |
| 設定 | `SettingsView` | 各種設定エントリ |
| 見守りモード | `ModeSwitchView` | 3モード切替 |
| 緊急連絡先 | `EmergencyContactsView` | 連絡先 CRUD |
| データ削除 | `DataDeletionView` | 削除フロー |
| ペイウォール | `PaywallView` | 購入導線 |
| オンボーディング | `OnboardingFlow` | 初回 3 画面 |

### 7.2 遷移図

```
[OnboardingFlow] → [Home]
                      ├─ Tap mood → [MoodPickerView] → [MoodMemoView] → back to [Home]
                      ├─ Tap cell → [EntryDetailView]
                      └─ Tap settings → [SettingsView]
                                          ├─ [ModeSwitchView] → may show [PaywallView]
                                          ├─ [EmergencyContactsView] → may show [PaywallView]
                                          ├─ App Lock toggle → may show [PaywallView]
                                          └─ [DataDeletionView]
```

### 7.3 オンボーディング 3 画面

**Page 1 — コンセプト**:
- イラスト: ピクセルカレンダー断片
- コピー: 「毎日のひとタップが、365日のあなたになる」

**Page 2 — 見守り**:
- イラスト: 矢印で家族へ向かう
- コピー: 「設定日数タップがなければ、大切な人にだけメールが届きます」
- 注記: 「データはあなたの iPhone から出ません」

**Page 3 — 通知許可 + 開始**:
- 「朝/夜の記録リマインダーを送ってもいいですか？」
- ボタン: 「許可する」「あとで」
- 下部: 「はじめる」（タップで Home へ）

**完了時**: `settings.onboarding_done = 'true'` を書き込み

### 7.4 各画面の空状態 / エラー状態

| 画面 | 空状態 | エラー状態 |
|---|---|---|
| Home | カレンダー全グレー + 中央に「最初の気分を記録しましょう」 | サーバー同期失敗時はサイレント（次回試行）|
| EntryDetail | 「記録なし、今この日に記録する」ボタン | — |
| EmergencyContacts | 「連絡先を追加」CTA のみ | 保存失敗で「保存できませんでした」トースト |
| Paywall | — | 購入失敗で「購入に失敗しました」アラート |

---

## 8. API契約

### 8.1 共通仕様

**ベースURL**: `https://api.hibix.app`（または `*.workers.dev` のデフォルトデプロイ URL）

**実装フレームワーク**: Hono on Cloudflare Workers。各ルートは `src/routes/*.ts` に分割し、`src/index.ts` で `app.route('/api/checkin', checkinRoute)` の形で組み立てる。`Request` / `Response` は Web 標準型を直接使用（`NextRequest` / `NextResponse` は使わない）。

**認証ヘッダ**（全エンドポイント必須・`/api/cron/check` 除く）:
```
X-Hibix-UUID: <anonymous_uuid>
```

**サーバー側挙動**:
- UUID が users テーブルに存在しなければ自動作成（last_checkin_at = NOW）
- UUID 形式が不正（UUID v4 でない）なら 400 Bad Request

**エラーレスポンス共通形式**:
```json
{
  "error": {
    "code": "INVALID_UUID",
    "message": "anonymous_uuid is invalid"
  }
}
```

**レート制限**: 1ユーザーあたり checkin 1日10回まで（設計書 v0.7 §5.2 / §5.3 ハードリミット仕様）。実装は D1 上の checkin カウンタまたは Workers KV / Durable Objects。v0.1 ではアプリ側のタップ抑制でほぼ到達しないが、サーバー側でも上限を持つ。

### 8.2 POST /api/checkin

チェックイン時刻をサーバーに反映する。

**Request**:
```json
{
  "checkin_at": "2026-05-15T12:34:56Z"
}
```

**Response 200**:
```json
{
  "last_checkin_at": "2026-05-15T12:34:56Z"
}
```

**処理**:
- `users.last_checkin_at` を更新
- `checkin_at` がサーバー時刻より未来の場合はサーバー NOW で上書き

### 8.3 PATCH /api/settings

見守り設定をサーバーに反映する。

**Request**（部分更新可）:
```json
{
  "watch_days": 2,
  "watch_mode": "gentle",
  "is_pro": true
}
```

**Response 200**:
```json
{
  "watch_days": 2,
  "watch_mode": "gentle",
  "is_pro": true
}
```

**バリデーション**:
- `watch_days`: 1〜7 の整数
- `watch_mode`: `'solo' | 'gentle' | 'daily'`
- `is_pro`: boolean（端末側 Keychain との同期用、サーバーは信頼するが二重チェックはしない）

### 8.4 PUT /api/contacts

緊急連絡先を全置換する。

**Request**:
```json
{
  "contacts": [
    { "email": "mom@example.com", "label": "お母さん" },
    { "email": "sis@example.com", "label": null }
  ]
}
```

**Response 200**:
```json
{
  "contacts": [
    { "id": "uuid-1", "label": "お母さん" },
    { "id": "uuid-2", "label": null }
  ]
}
```

**処理**:
- 既存連絡先を全削除
- email を AES-256-GCM で暗号化して挿入
- 最大 3 件、超過時 400

**注**: Response にメールアドレス本文は含めない（端末側ローカル DB が真実）

### 8.5 DELETE /api/account

アカウント削除リクエスト。

**Request**: ボディなし
**Response 200**:
```json
{
  "deletion_request_id": "uuid",
  "scheduled_deletion_by": "2026-05-17T12:34:56Z"
}
```

**処理**:
- `deletion_requests` に挿入
- `users` 行は即時論理削除フラグ（実装上は `last_checkin_at = NULL` で Cron 対象外化）
- 物理削除は Cron 内で `requested_at + 48h` 経過後に実行

### 8.6 Cron: しきい値チェック（`scheduled()` ハンドラ）

Cloudflare Cron Triggers から 15 分ごとに起動。HTTP エンドポイントではなく Workers の `scheduled()` イベントハンドラとして実装。

**実装エントリ**:
```typescript
// src/index.ts
export default {
  fetch: app.fetch,            // Hono ルーター
  scheduled: async (event, env, ctx) => {
    await runCheckinMonitor(env);  // src/cron/checkin-monitor.ts
  },
} satisfies ExportedHandler<Env>;
```

**認証**: 不要（`scheduled()` は外部 HTTP からは呼び出せない。Cloudflare 内部から Cron Triggers 経由でのみ起動される。CRON_SECRET 概念は廃止）。

**処理**:
```
1. users で is_pro=true かつ watch_mode IN ('gentle', 'daily') の行を取得
2. しきい値到達ユーザーを検出:
     last_checkin_at + (watch_days * 24h) < NOW
3. 直近 24h 以内に同タイプ通知が notification_logs にあるユーザーは除外
4. emergency_contacts を取得・復号
5. Resend 経由でメール送信
6. notification_logs に記録
7. deletion_requests で requested_at + 48h を経過した行に対応する users / emergency_contacts / notification_logs を物理削除（F-11 関連）
```

**Cron 設定（`wrangler.toml`）**:
```toml
[triggers]
crons = ["*/15 * * * *"]
```

**ローカルテスト**: `wrangler dev --test-scheduled` で `scheduled()` ハンドラをローカル起動できる。

---

## 9. 通知システム仕様

### 9.1 ローカル通知（iOS 側）

| 通知 | identifier | スケジュール |
|---|---|---|
| 朝のチェックイン | `hibix.daily.morning` | settings.morning_notify の時刻に毎日 |
| 夜のチェックイン | `hibix.daily.evening` | settings.evening_notify の時刻に毎日 |
| リマインダー#1 | `hibix.reminder.48h` | しきい値の 48h 前 |
| リマインダー#2 | `hibix.reminder.24h` | しきい値の 24h 前 |

**再スケジュールトリガー**:
- 気分タップ完了時 → 全リマインダー再スケジュール
- 設定画面で watch_days 変更時 → リマインダー再スケジュール
- 設定画面で朝/夜時刻変更時 → 該当通知再スケジュール
- アプリ起動時 → 朝/夜通知が予約されていなければ再予約

### 9.2 メール通知（サーバー側）

§8.6 参照。

### 9.3 タイマーリセット条件

緊急メール発火を防ぐ条件:
1. 端末側で気分タップ → `POST /api/checkin` 成功 → `last_checkin_at` 更新 → しきい値が未来へ移動
2. オフライン時のタップは端末側ローカルにバッファ → 復帰時にバッチで `checkin_at`（タップ時刻）を送信

### 9.4 重複送信防止

`notification_logs` を参照:
- 同一 `user_id` で `type='alert'` が直近 24h 以内に `sent` ステータスで存在すれば送信スキップ
- これにより Cron が 15分ごとに動いてもアラートは 1 日 1 通まで

### 9.5 配信失敗フォールバック

- Resend API 呼び出し失敗時 → `delivery_status='failed'` を記録 → 次回 Cron 実行で再試行（最大 3 回まで、3 回失敗で諦め）
- バウンス検出は v0.1 ではスコープ外（v0.2 で Resend Webhook 実装）

---

## 10. セキュリティ・プライバシー仕様

### 10.1 データ保存原則

| データ | 保存場所 | 理由 |
|---|---|---|
| 気分・メモ・ピクセル履歴 | iPhone ローカル SQLite のみ | 心の中身は外に出さない |
| 緊急連絡先メアド | ローカル平文 + サーバー AES-256-GCM 暗号化 | サーバー側で送信必要、暗号化で漏洩リスク低減 |
| anonymous_uuid | iOS Keychain（iCloud 同期）+ サーバー平文 | 識別子であり機微情報ではない |
| 購入状態 (is_pro) | iOS Keychain + サーバー平文 | 機能ゲーティング判定用 |

### 10.2 Keychain アクセスポリシー

- `kSecAttrAccessibleAfterFirstUnlock`
- `kSecAttrSynchronizable = true`（iCloud Keychain 経由で機種変対応）

### 10.3 サーバー側暗号化

**emergency_email の暗号化**:
- アルゴリズム: AES-256-GCM
- key: シークレット `HIBIX_AES_KEY`（`wrangler secret put HIBIX_AES_KEY` で登録、32 byte hex）
- IV: 12 byte ランダム（リクエストごと）
- 保存: `email_encrypted` / `email_iv` / `email_tag` を base64 で個別保存
- 実装: Workers ランタイム標準の Web Crypto API（`crypto.subtle`）を使用。`node:crypto` は使用しない。

**実装**:
```typescript
// src/lib/crypto.ts
async function getKey(env: Env): Promise<CryptoKey> {
  const raw = hexToBytes(env.HIBIX_AES_KEY);  // 32 byte
  return crypto.subtle.importKey('raw', raw, 'AES-GCM', false, ['encrypt', 'decrypt']);
}

export async function encrypt(env: Env, plaintext: string) {
  const key = await getKey(env);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = new TextEncoder().encode(plaintext);
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, data));
  // AES-GCM の WebCrypto 出力は ciphertext + tag(16byte) 結合。末尾16バイトが tag。
  const tag = ct.slice(ct.length - 16);
  const body = ct.slice(0, ct.length - 16);
  return {
    email_encrypted: bytesToBase64(body),
    email_iv: bytesToBase64(iv),
    email_tag: bytesToBase64(tag),
  };
}

export async function decrypt(env: Env, d: { email_encrypted: string; email_iv: string; email_tag: string }) {
  const key = await getKey(env);
  const body = base64ToBytes(d.email_encrypted);
  const tag = base64ToBytes(d.email_tag);
  const iv = base64ToBytes(d.email_iv);
  const combined = new Uint8Array(body.length + tag.length);
  combined.set(body, 0);
  combined.set(tag, body.length);
  const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, combined);
  return new TextDecoder().decode(plain);
}
```

**注**: 上のサンプルでは tag を別カラム保存する v2.0 互換のためにスライス処理しているが、実装簡略化のため `email_encrypted` 1カラムに ciphertext+tag を結合保存する選択肢もある。最終決定は実装時に。

### 10.4 データ削除権の実装手順

§6 F-11 + §8.5 参照。**48 時間以内完了の SLO**。

### 10.5 法令対応

- **個人情報保護法**: 取得目的の明示、削除権の保証、第三者提供なし
- **薬機法**: アプリ内・LP・App Store 説明文すべてで「治療」「改善」「予防」NG
- **App Store 審査ガイドライン**: 5.1.1 (Data Collection) 準拠、医療代替ではない旨を利用規約・通知メール本文に明示

### 10.6 利用規約・プライバシーポリシー必須項目

- 医療代替・緊急通報サービスではないことの明示
- データの取り扱い範囲（ローカル/サーバー）
- アカウント削除時の挙動と所要時間（48h以内）
- 通知配信の最善努力義務（保証はしない）
- 第三者提供しないこと
- 広告・トラッキングをしないこと

---

## 11. アクセシビリティ仕様

### 11.1 必須対応（v0.1）

- **VoiceOver**: 全操作可能要素にラベル
- **Dynamic Type**: `Font.body` 等の標準サイズ使用、xxxLarge まで切れない
- **タップ領域**: 最小 44pt × 44pt（Apple HIG）
- **コントラスト**: WCAG AA（4.5:1）以上

### 11.2 ラベル方針

```swift
// 気分カラーボタン
.accessibilityLabel("気分 \(level), \(moodName)")
.accessibilityHint("タップして今日の気分を記録")

// ピクセルカレンダーセル
.accessibilityLabel("\(month)月\(day)日, \(hasEntry ? "気分\(level)" : "記録なし")")
```

### 11.3 対象外（v0.2 以降）

- Reduce Motion
- Increase Contrast
- Reduce Transparency
- Voice Control 専用調整

### 11.4 受け入れ基準

- [ ] Accessibility Inspector で警告ゼロ
- [ ] VoiceOver でホーム→気分タップ→詳細→設定が完結
- [ ] Dynamic Type xxxLarge で全画面文字切れなし

---

## 12. テスト戦略

### 12.1 ユニットテスト（XCTest）

**対象**:
- `Migrations` — マイグレーション v1 の DDL 実行が成功する
- `MoodEntryRepository` — UPSERT、日付クエリ、500文字制限
- `EntitlementManager` — Keychain との往復、StoreKit モック
- `FeatureGate` — Feature ごとの isPro=true/false ケース
- `NotificationScheduler` — リマインダー再スケジュールロジック（watch_days=1 の境界含む）
- `NotificationContent` — 通知本文の動的部分（日付・日数）

### 12.2 統合テスト

**バックエンド**:
- 各エンドポイントの正常系・異常系
- AES-256-GCM の暗号化・復号往復
- Cron ロジック: しきい値到達検出、24h 重複防止

### 12.3 手動テストチェックリスト

リリース前に必ず実施:

- [ ] 新規インストール → オンボーディング → 初回タップ
- [ ] アプリ削除 → 再インストールで Keychain 経由 UUID 復元
- [ ] オフライン状態でタップ → ローカル保存 → オンライン復帰で ping 送信
- [ ] watch_days=1 で 24h 放置 → 24h リマインダー発火
- [ ] watch_days=2 で 48h 放置 → メール発火（Sandbox メアド）
- [ ] 購入フロー（Sandbox）→ Entitlement 反映
- [ ] 購入復元 → 別端末で Pro 機能解禁
- [ ] データ削除 → アプリ初期化 + サーバー側削除確認
- [ ] Face ID ロック有効化 → バックグラウンド → 復帰で再認証要求
- [ ] VoiceOver 操作完結
- [ ] Dynamic Type xxxLarge で文字切れなし
- [ ] iPhone SE 第3世代でレイアウト崩れなし

---

## 13. 実装順序

### 13.1 Sprint 分解と依存 DAG

```
Sprint 1: 基盤
  S1.1 プロジェクト初期化（Xcode/Package.swift/フォルダ構造）
  S1.2 GRDB セットアップ + Migrations v1
  S1.3 KeychainStore（UUID 発行・iCloud同期）

Sprint 2: コア記録機能
  S2.1 MoodPickerView + 気分タップ（F-01）
  S2.2 MoodMemoView + メモ保存（F-02）
  S2.3 PixelCalendarView（無料層: 1年表示）（F-04 一部）
  S2.4 EntryDetailView（F-03）

Sprint 3: オンボーディング + 通知
  S3.1 OnboardingFlow（F-05 の通知許可含む）
  S3.2 NotificationScheduler 朝/夜通知（F-05）

Sprint 4: バックエンド基盤
  S4.1 Cloudflare Workers プロジェクト初期化
       - `npm create cloudflare@latest hibix-backend -- --type=hello-world --ts --no-deploy`
       - `wrangler login`
       - `wrangler d1 create hibix-db` → 取得した database_id を wrangler.toml に記載
       - Drizzle スキーマ作成（src/db/schema.ts）+ `drizzle-kit generate` で migrations/0001_initial.sql 生成
       - `wrangler d1 migrations apply hibix-db --local` / `--remote`
       - `wrangler secret put HIBIX_AES_KEY` / `RESEND_API_KEY` 登録
       - `wrangler dev` で起動確認
  S4.2 Hono ルーター骨組み + POST /api/checkin
  S4.3 APIClient（iOS 側） + 気分タップ後の checkin 連携

Sprint 5: 課金 + ゲーティング
  S5.1 StoreKit 2 統合（F-12）
  S5.2 EntitlementManager + FeatureGate（F-13/F-14）
  S5.3 PaywallView
  S5.4 PixelCalendarView 全期間スクロール（F-04 完全）

Sprint 6: 設定 + 有料機能 UI
  S6.1 SettingsView（フレーム）
  S6.2 ModeSwitchView（F-06）
  S6.3 EmergencyContactsView（F-07 UI）
  S6.4 AppLockManager + トグル（F-08）

Sprint 7: 安否機能（サーバー側）
  S7.1 PATCH /api/settings
  S7.2 PUT /api/contacts + Web Crypto AES-256-GCM 暗号化
  S7.3 scheduled() ハンドラ（Cloudflare Cron Triggers）+ Resend 連携
  S7.4 2段階リマインダー実装（F-09）

Sprint 8: 削除権 + 仕上げ
  S8.1 DELETE /api/account
  S8.2 DataDeletionView + scheduled() 内 48h 経過レコード物理削除（F-11）
  S8.3 アクセシビリティ仕上げ（F-10）

Sprint 9: テスト + ベータ準備
  S9.1 ユニットテスト網羅
  S9.2 統合テスト網羅
  S9.3 手動テストチェックリスト消化
  S9.4 TestFlight 配信
```

### 13.2 各 Sprint の DONE 基準

各 Sprint の終わりに、§12.3 手動テストチェックリストの該当項目がすべて ✅ になっている。

### 13.3 クリティカルパス

- S1 → S2 → S5 → S7 がクリティカルパス
- S4 と S5 は独立並列可
- S8 は他全 Sprint 完了後

---

## 14. 明示的な対象外（v0.1 で実装しない）

以下は **v0.1 では実装しない**。Claude Code はこれらを実装しようとしてはならない。要望が出ても拒否し、PRD 更新を求めること。

- ❌ ウィジェット（Home Screen / Lock Screen / Control Center）
- ❌ Apple Watch アプリ
- ❌ QR 代理セットアップ（子→親）
- ❌ Web 招待リンク（緊急連絡先側のアプリレス確認ページ）
- ❌ 通知文トーン選択（深刻/中性/柔らかい）
- ❌ データエクスポート（CSV/JSON）
- ❌ 月間/年間グラフ・ストリーク表示
- ❌ Apple Sign-In
- ❌ Android 版
- ❌ 双方向見守り（両者アプリ持ち・お互いの気分共有）
- ❌ iCloud 経由のフルデータ同期
- ❌ AI 洞察・ChatGPT 統合
- ❌ サブスクリプション商品（月額/年額）
- ❌ ペアプラン・ファミリープラン
- ❌ テーマ・カラーパック追加
- ❌ ソーシャル機能（フォロー・コメント・公開タイムライン）
- ❌ Reduce Motion / Increase Contrast 専用調整
- ❌ 英語・他言語ローカリゼーション
- ❌ PPP（地域別価格）
- ❌ Resend Webhook によるバウンス自動処理
- ❌ `daily` モードの「毎日メール送信」挙動（v0.1 では `gentle` と同じ挙動でフォールバック）

---

## 15. Appendix

### 15.1 参照ファイル

- 設計書: `/Users/a/Desktop/Hibix_design.md`
- 競合分析: `/Users/a/Desktop/Hibix_ekytoyo_review_analysis.md`
- 旧PRD: `/Users/a/Desktop/Hibix_PRD_reference_v1.md`
- 本書: `/Users/a/Desktop/Hibix_PRD.md`

### 15.2 確定経緯（2026-05-15）

1. 読み手は Claude Code に決定 → 構造を機械可読仕様へ全面再設計
2. 技術スタック: SwiftUI / iOS 17+ / GRDB / 匿名UUID + iCloud Keychain
3. MVP は安否機能まで含む 16 機能に絞り込み（参考PRD v1.0 の 25 機能から削減）
4. 無料/有料境界:
   - 無料: 気分タップ・メモ500文字・ピクセル直近1年（直近365日ローリングウィンドウ）・通知・データ削除
   - 有料 (¥2,800): 3モード解禁・緊急連絡先メール・Face IDロック・2段階リマインダー・ピクセル全期間
5. マーケ・ブランド・KPI 章は意図的に除外（コーディング判断に不要）
6. **v2.1 で バックエンドを Cloudflare Workers + D1 + Hono に正規化**（設計書 v0.7 §15 引き継ぎ・コスト青天井防止と無料スタートのため）

### 15.3 変更履歴

| バージョン | 日付 | 内容 |
|---|---|---|
| v1.0 | 2026-05-15 | 旧PRD（人間向け構造） |
| v2.0 | 2026-05-15 | Claude Code 向けにゼロベース書き直し |
| **v2.1** | **2026-05-15** | **設計書 v0.7 §15 引き継ぎ反映: バックエンドを Vercel + Next.js + Neon Postgres → Cloudflare Workers + D1 (SQLite) + Hono に正規化。Cron は `scheduled()` ハンドラ化、暗号化を Web Crypto API へ移行、Sprint 4 セットアップ手順を wrangler ベースに更新。エンドポイント仕様・データモデル構造・iOS 側仕様は変更なし。本書** |

### 15.4 関連メモリ

- [[project_hibix]] — プロジェクト概要
- [[project_revenue_matrix]] — 全PJ収益スコア
- [[project_bali_goal]] — バリ移住目標
- [[feedback_revenue_thinking]] — 収益思考プロセス

---

**EOF**
