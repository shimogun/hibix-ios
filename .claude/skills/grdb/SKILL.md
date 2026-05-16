# GRDB.swift / SQLite 規約

## DatabasePool / DatabaseQueue 選定

- **DatabasePool** を使う(複数読み取り並列・書き込み単一・WAL モード)
- `Documents/hibix.sqlite` をDB ファイルパスとして固定(PRD §4.1)
- DBインスタンスはアプリ全体で1つ(`DatabaseManager` シングルトン経由)

## マイグレーション

- すべてのスキーマ変更は `DatabaseMigrator` 経由で行う
- 各マイグレーションは独立した名前を持ち、**冪等**にする
- 既存マイグレーションを変更しない(新規マイグレーションを追加)
- 初期スキーマは `v1` として PRD §4.1 のDDLを実行

```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("v1_initial") { db in
    try db.execute(sql: """
        CREATE TABLE mood_entries (...)
    """)
}
```

## カラム命名・型対応

| Swift型 | SQLite型 | 補足 |
|---|---|---|
| `Int` / `Int64` | `INTEGER` | |
| `String` | `TEXT` | UTF-8 |
| `Date` | `TEXT` (ISO 8601) | 文字列で保存・PRD §4.1 準拠 |
| `Bool` | `INTEGER` (0/1) | |
| `Data` | `BLOB` | 暗号化バイト列等 |

- カラム名は **snake_case**(PRD §3.3)
- Swift プロパティ名は **camelCase**(CodingKeysでマッピング)

## クエリスタイル

### 推奨: タイプセーフ Record API

```swift
struct MoodEntry: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var entryDate: String
    var moodLevel: Int
    var memo: String?
    var createdAt: String
    var updatedAt: String
}

// Read
let entries = try await dbPool.read { db in
    try MoodEntry.filter(Column("entry_date") >= startDate).fetchAll(db)
}

// Write
try await dbPool.write { db in
    var entry = MoodEntry(...)
    try entry.insert(db)
}
```

### 許可: 生SQL(必要時のみ)

複雑な集計・JOINで Record API が不便な場合は生SQLを使ってよい。ただし**バインドパラメータを必ず使う**(文字列結合禁止):

```swift
try await dbPool.read { db in
    try Row.fetchAll(db,
        sql: "SELECT ... WHERE entry_date >= ?",
        arguments: [startDate])
}
```

## UPSERT(PRD F-01)

`entry_date` UNIQUE 制約を使った INSERT ON CONFLICT を使う:

```swift
try await dbPool.write { db in
    try db.execute(sql: """
        INSERT INTO mood_entries (entry_date, mood_level, memo, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(entry_date) DO UPDATE SET
            mood_level = excluded.mood_level,
            memo = excluded.memo,
            updated_at = excluded.updated_at
    """, arguments: [entryDate, level, memo, now, now])
}
```

## トランザクション

- 複数テーブルへの書き込みは `write { db in ... }` ブロック内で実行(自動トランザクション)
- 読み書き混在は `inTransaction` を明示的に使う

## ローリングウィンドウ実装(F-04)

無料層の直近365日表示:

```swift
let cutoff = Calendar.current.date(byAdding: .day, value: -364, to: Date())!
let cutoffString = ISO8601DateFormatter().string(from: cutoff).prefix(10) // YYYY-MM-DD

let entries = try await dbPool.read { db in
    try MoodEntry.filter(Column("entry_date") >= String(cutoffString)).fetchAll(db)
}
```

端末ローカルタイム基準(PRD §6 F-04)。タイムゾーン跨ぎの境界はUSERのローカルタイムを優先。

## パフォーマンス

- ピクセルカレンダー描画用クエリは1回で取得・キャッシュ(`@StateObject` の ViewModel が保持)
- インデックス活用: `idx_mood_entries_date` を `entry_date` に張る(PRD §4.1)
- 5000レコード以上のフェッチは検討不要(個人の1年=365件想定)

## テスト

- in-memory DB を使ったテスト(`DatabaseQueue()` でin-memory)
- マイグレーションテスト: v1 適用後にスキーマが期待通りか確認
- リポジトリテスト: UPSERT動作・500文字制限・日付クエリ

## 禁止事項

- **文字列結合によるSQL組み立て**(SQLインジェクション防止)
- **同期API呼び出し**(`DispatchQueue.main.sync` でDB操作禁止・asyncで包む)
- **DBファイルを Documents 以外に置く**(バックアップ対象外になる)
- **マイグレーション履歴の削除/変更**(冪等性が崩れる)

## 共通参照

データ保存原則(ローカル100%・サーバーに気分/メモを送らない)は `common-security/SKILL.md` を参照。
