# Hibix iOS — Claude Code 司令塔

このリポジトリは Hibix の **iOS アプリ専用**(`hibix-ios`)。Backend(`hibix-backend`)は別リポジトリで、API契約は `docs/PRD.md` §8 で確定済み。

## 重要参照ファイル(必ず最初に読む)

| ファイル | パス | 役割 |
|---|---|---|
| PRD v2.1 | `docs/PRD.md` | 機械可読仕様(**実装の真実**) |
| 設計書 v0.7 | `docs/design.md` | 背景・思想(判断軸が割れたら PRD が優先) |
| Swift規約 | `.claude/skills/swift/SKILL.md` | Swift/SwiftUI コーディング規約 |
| GRDB規約 | `.claude/skills/grdb/SKILL.md` | GRDB/SQLite データアクセス規約 |
| StoreKit規約 | `.claude/skills/storekit/SKILL.md` | StoreKit 2 課金実装規約 |
| 共通セキュリティ | `.claude/skills/common-security/SKILL.md` | 機微データ取扱・暗号化共通規約 |
| パイプライン | `PIPELINE.md` | 全体フロー(STEP順序・承認ポイント) |

**起動時に必ず実行**:
1. `view docs/PRD.md` で PRD 最新版を読む
2. `view docs/design.md` で設計書 v0.7 を読む
3. `view PIPELINE.md` で現在のSTEP位置を確認
4. その後、現在STEPに該当するSKILL.mdを読む

PRDと設計書がリポジトリ内にない場合は STEP0 が未完了。オーナーから受領して `docs/` に配置するまで他STEPに進まない。

## STEP定義

PRD §13 Sprint をそのまま採用。

| STEP | 名称 | PRD対応 | 承認 |
|---|---|---|---|
| STEP0 | プロジェクト初期化(下記詳細) | 独自 | - |
| STEP1 | 基盤(Package.swift/GRDB/Migrations/KeychainStore) | S1.1〜S1.3 | ✅ **承認1** |
| STEP2 | コア記録機能(F-01〜F-04) | S2.1〜S2.4 | - |
| STEP3 | オンボーディング+通知(F-05) | S3.1〜S3.2 | - |
| STEP4 | APIクライアント+checkin連携 + App Attestクライアント(PRD v2.2.0 §8/§10.7) | S4.3 + S4.5 | - |
| STEP5 | 課金+ゲーティング(F-12〜F-14) + PaywallView + F-04全期間 + /api/storekit/verify連携(C-01) | S5.1〜S5.5 | ✅ **承認2** |
| STEP6 | 設定+有料機能UI(F-06〜F-08) | S6.1〜S6.4 | - |
| STEP7 | 削除権+アクセシビリティ仕上げ(F-10/F-11) | S8 | - |
| STEP8 | テスト網羅+TestFlight準備 | S9 | ✅ **承認3** |

各STEP完了時、PRD §12.3 手動テストチェックリストの該当項目が ✅ になっていることをDONE基準とする。

## STEP0 詳細(必ず順番に実行)

1. `.claude/` 配下が存在することを確認(`view .claude/CLAUDE.md` で本ファイルを読み返す)
2. `.claude/skills/{swift,grdb,storekit,common-security}/SKILL.md` 4ファイルの存在確認
3. `PIPELINE.md` 存在確認
4. `docs/` ディレクトリを作成(存在しなければ)
5. `docs/PRD.md` 存在確認 → なければオーナーに受領依頼して停止
6. `docs/design.md` 存在確認 → なければオーナーに受領依頼して停止
7. `.gitignore` 作成(`.DS_Store` / `xcuserdata/` / `*.xcuserstate` / `build/` / `DerivedData/` 等)
8. Xcode プロジェクト雛形作成(`Hibix.xcodeproj`、Bundle ID `com.shimogun.hibix`)
9. `Package.swift` で GRDB / KeychainAccess を依存追加(PRD §2.4 のバージョン固定)
10. `git init` + 初回commit(コミットメッセージ: `STEP0: project initialization`)
11. オーナーへ STEP0 完了報告 → 承認後 STEP1 へ

## 承認ポイント詳細

- **承認1 (STEP1後)**: 基盤確認。GRDB DBが作られMigrations v1が実行できる、KeychainにUUIDが書き込まれiCloud同期される、ことを実機/シミュレータで確認。
- **承認2 (STEP5後)**: 課金実装確認。Sandbox環境で `com.shimogun.hibix.pro.lifetime` の購入→Entitlement反映→PaywallのCTA動作を確認。
- **承認3 (STEP8後)**: リリース承認。手動テストチェックリスト全項目消化済み、TestFlight配信準備完了。

承認待ち中はオーナーの指示があるまで次STEPに進まない。

## 禁止動作

- 第三者解析SDK(Firebase Analytics / Mixpanel / Sentry等)の追加
- 第三者広告SDKの追加
- `mood_level`、`memo`、ピクセル履歴のサーバー送信(`docs/PRD.md` §4.2 厳守)
- `com.shimogun.hibix.pro.lifetime` 以外の商品ID追加(`docs/PRD.md` §5.3 厳守)
- 月額/サブスク商品の実装(v0.1スコープ外・`docs/PRD.md` §14)
- App Sign-In実装(v0.1スコープ外)
- ウィジェット/Apple Watch/Web招待リンク等の対象外機能
- `xcodebuild archive -configuration Release` 実行(リリースビルドは手動)
- Apple Developer証明書/Provisioning Profileの変更
- `git push --force` / `rm -rf` 系の不可逆操作
- 「治療」「改善」「予防」薬機法NG表現(コード・コメント・通知本文に紛れ込ませない)

要望が出ても拒否し、オーナーに確認を求める。

## SubAgent起動条件

Fork-Join可能な独立タスクのみ並列化:

- STEP2のF-01〜F-04は同一画面に集約されるため並列化不可(同じファイルを触る)
- STEP2完了後の各Featureユニットテスト作成は並列化可
- STEP6のF-06〜F-08の各View実装は並列化可(独立ファイル)

並列化対象を起動する前に、独立性(共有状態を触らない・依存関係がない)を必ず確認。マージ条件: 全SubAgent完了 → メインに集約 → 次STEPへ。

## Auto memory への書き込みルール

書いてよい:
- Xcodeコマンド(`xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 15'`)
- `swift build` / `swift test` のオプション
- 依存解決コマンド(`swift package resolve` / `swift package update`)
- GRDBデバッグ用 sqlite3 コマンド

書いてはならない:
- 設計判断(アーキテクチャ・ライブラリ選定理由)
- コーディング規約(SKILL.md に書く)
- API仕様(PRDに書く)
- 個人の好み

## /triage 利用方針

修正フェーズの入口。指摘事項を分類:

| 種別 | 対応 |
|---|---|
| `bug` | 該当STEPに戻って修正 |
| `design-change` | オーナーに確認・`docs/design.md` または `docs/PRD.md` の更新が必要 |
| `enhancement` | v0.2以降のスコープに記録 |
| `refactor` | テスト全通過後にまとめて対応 |

## ドキュメント更新時の挙動

オーナーから「`docs/PRD.md` を更新した」「`docs/design.md` を更新した」と通達があった場合:
1. 該当ファイルを `view` で再読み込み
2. 変更が現在STEPに影響するか判断
3. 影響がある場合は現在の作業を一旦止め、変更箇所を整理してオーナーに確認
4. 影響がない場合は通常通り続行

PRD/設計書とコードに齟齬がある場合は **PRDが優先**(`docs/PRD.md` §0.1 / 設計書 §14.3 参照)。
