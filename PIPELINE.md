# Hibix iOS — 開発パイプライン

## 全体フロー

```
STEP0: プロジェクト初期化(Xcode雛形 / 4ファイル配置確認 / .gitignore)
   ↓
STEP1: 基盤(Package.swift / GRDB / Migrations v1 / KeychainStore)
   ↓ ✅ 承認1(オーナー確認)
STEP2: コア記録機能(F-01〜F-04 同一画面群)
   ↓
STEP3: オンボーディング+通知(F-05)
   ↓
[Backend STEP7 Codex設計レビューゲート: PRD v2.2.0 / design v0.8 で確定済]
   ↓
STEP4: iOS S4.3 + S4.5 (APIClient + checkin連携 + App Attestクライアント)
   ↓
STEP5: 課金+ゲーティング(F-12〜F-14, PaywallView, F-04全期間, /api/storekit/verify連携)
   ↓ ✅ 承認2(Sandbox購入確認)
STEP6: 設定+有料機能UI(F-06〜F-08)
   ↓
STEP7: 削除権+アクセシビリティ(F-10/F-11)
   ↓
STEP8: テスト網羅+TestFlight準備
   ↓ ✅ 承認3(リリース承認)
TestFlight配信 → ベータテスト → App Store提出
```

## SubAgent並列化対象

Fork-Join可能(共有状態なし・独立ファイル):

| STEP | 並列化対象 | 同期ポイント |
|---|---|---|
| STEP2 完了後 | F-01〜F-04 のユニットテスト4ファイル作成を並列化可 | 全テスト作成完了後にメイン実行 |
| STEP6 | F-06(ModeSwitchView)/ F-07(EmergencyContactsView)/ F-08(AppLockManager)の各View実装 | 3ファイル完了 → SettingsView から導線接続 |
| STEP8 | ユニットテスト(`DatabaseTests`/`EntitlementTests`/`NotificationTests`/`ModelTests`)の網羅実装 | 全テスト緑→TestFlight準備 |

並列化禁止:
- STEP2 内部の F-01〜F-04(同一画面で相互参照)
- STEP3 のOnboardingFlow(画面間の連続性)
- STEP5 のEntitlementManager → PaywallView → F-04全期間(依存関係あり)

## エラー時の振る舞い

- **ビルド失敗**: そのSTEPに留まって修正。3回失敗で /triage 起動
- **ユニットテスト失敗**: 失敗したテストに対応する機能STEPに戻る
- **GRDBマイグレーション失敗**: STEP1に戻る(他STEPへの波及大)
- **Sandboxで購入が反映されない**: STEP5に戻る、App Store Connectの商品状態を疑う

## 各STEPの成果物(DONE基準)

| STEP | 成果物 |
|---|---|
| STEP0 | Xcodeプロジェクト雛形 + 4ファイル配置 + .gitignore + 初回commit |
| STEP1 | DatabaseManager / Migrations.swift / KeychainStore.swift + 各ユニットテスト + 起動時にDB作成・UUID発行が動く |
| STEP2 | HomeView / MoodPickerView / MoodMemoView / EntryDetailView / PixelCalendarView(直近365日) + F-01〜F-04の受け入れ基準クリア |
| STEP3 | OnboardingFlow / NotificationScheduler + F-05受け入れ基準クリア |
| STEP4 | APIClient / APIEndpoint / APIError / AppAttestClient(DCAppAttestService ラッパー)/ 気分タップ後の POST /api/checkin が wrangler dev に対して動作(PRD v2.2.0 §8.1-§8.2 / §8.7-§8.8 / §10.7) |
| STEP5 | StoreKit 2統合 / EntitlementManager / FeatureGate / PaywallView / F-04全期間スクロール + F-12〜F-14受け入れ基準クリア + POST /api/storekit/verify による is_pro 確定(C-01) |
| STEP6 | SettingsView / ModeSwitchView / EmergencyContactsView / AppLockManager + F-06〜F-08受け入れ基準クリア |
| STEP7 | DataDeletionView / アクセシビリティ仕上げ + F-10/F-11受け入れ基準クリア + Accessibility Inspector 警告ゼロ |
| STEP8 | ユニット/統合/手動テスト全項目消化 + TestFlightビルドアップロード準備完了 |

## マージ条件

各STEPのDONE基準を満たし、ユニットテストが全て緑、SwiftLintで警告ゼロであることをマージ条件とする。
