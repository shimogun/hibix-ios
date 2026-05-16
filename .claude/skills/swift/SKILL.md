# Swift / SwiftUI 規約

## 命名規則

- 型・enum・struct・class・protocol: **PascalCase**
- 変数・関数・プロパティ: **camelCase**
- ファイル名: 主要型名と一致(`HomeView.swift` に `struct HomeView`)
- enumケース: lowerCamelCase(`case solo / gentle / daily`)
- 定数: `let`、可変は最小化

## 関数設計

- **1関数は単一責任**。複数の責務が混じったら分割
- **1関数50行以内**(コメント・空行除く)を上限とする。超えたらリファクタ
- **副作用は明示**: ファイル/DB/ネットワークへの書き込みを伴う関数名は動詞を強くする(`save~` / `delete~` / `send~`)
- **戻り値は型注釈を省略しない**(暗黙的な型推論は内部変数のみ)

## SwiftUI プロパティラッパー使い分け

- `@State`: View内部の一時状態のみ
- `@Binding`: 親から渡された状態の双方向参照
- `@StateObject`: ViewModelの初回生成(View自身が所有)
- `@ObservedObject`: 親から渡されたObservableObject
- `@Environment`: 環境値(`\.colorScheme` 等)
- `@AppStorage`: UserDefaults(**ただしHibixでは設定はGRDBに保存。UserDefaultsは一時状態のみ。PRD §4.4 厳守**)

## 非同期処理

- 新規コードは **async/await** を使う(Combine は避ける)
- `actor` を使ってデータ競合を防ぐ(`EntitlementManager` 等)
- `Task { ... }` でラップする際は cancellation を考慮
- メインスレッドUI更新は `@MainActor` で明示

## エラーハンドリング

- `do-try-catch` を握り潰さない(空catchブロック禁止)
- 独自エラー型は enum で定義し、`LocalizedError` 準拠
- ユーザー向けメッセージは PRD で定義済みのものを使う(独自に増やさない)
- `try!` / `try?` の使用は限定的に(`try!` はテストコードのみ可)

## 型注釈

- public な関数の引数・戻り値は型を明示
- 配列・辞書リテラルは型推論可
- Optional は明示的に `String?` と書く(`Optional<String>` は使わない)

## SwiftUI View 設計

- 1ファイル = 1メインView を原則
- 補助のサブViewは同ファイル内に小さく宣言可
- 同じViewが3箇所以上で使われたら共通化(`Components/` に切り出し)
- `body` 内で重い計算をしない(`computed property` か ViewModel に逃がす)

## 禁止事項

- **強制アンラップ `!`** の使用(IBOutlet等の例外除く)
- **マジックナンバー** をリテラルでコードに埋め込む(定数定義必須・SwiftUIのpadding等のViewレベル定数は許可)
- **型定義の省略**(public APIは必ず型注釈)
- **エラーの握り潰し**(`try? ... // ignore` 含む)
- **print文の本番残置**(デバッグは `os_log` か `Logger`)
- **TODOコメントの放置**(TODOは即座にissue化し、コメントから消す)

## テスト方針

- **対象**: PRD §12.1 列挙の全Repository・Manager・Scheduler
- **モック**: プロトコル化してテスト時に差し替え(`MoodEntryRepositoryProtocol` 等)
- **カバレッジ目標**: ロジック層80%以上、View層は受け入れ基準テストで担保
- **テスト命名**: `test_methodName_scenario_expectedResult()`

## SwiftFormat / SwiftLint

- `swiftformat` 設定: デフォルト(`.swiftformat` ファイル不要、必要時はリポジトリルートに置く)
- `swiftlint` 設定: `.swiftlint.yml` で `force_unwrapping` を `error` レベル、`line_length` を 120
- PostToolUseフックで自動実行されるため、手動実行は不要

## 共通参照

機微データ取り扱い・暗号化・データ保存原則は `common-security/SKILL.md` を参照。
