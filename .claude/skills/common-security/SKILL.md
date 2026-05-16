# 機微データ取扱・セキュリティ共通規約

両リポジトリ(`hibix-ios` / `hibix-backend`)で同一内容を配置。**片方を更新したら必ず両方を更新**。

## データ保存原則(設計書 v0.7 §4 / PRD §4.2 / §10.1)

| データ種別 | 保存場所 | 絶対ルール |
|---|---|---|
| 気分タップ(mood_level) | iOSローカル100% | **サーバーに送らない** |
| 日記メモ本文 | iOSローカル100% | **サーバーに送らない** |
| ピクセル履歴 | iOSローカル100% | **サーバーに送らない** |
| ユーザー氏名・氏名らしき情報 | どこにも保存しない | **収集しない** |
| `last_checkin_at` | サーバーのみ | タイムスタンプのみ |
| `anonymous_uuid` | iOS Keychain(iCloud同期) + サーバー平文 | 機微情報ではない |
| `emergency_email` | iOSローカル平文 + サーバーAES-256-GCM暗号化 | サーバー側は必ず暗号化 |
| `is_pro` | iOS Keychain + サーバー平文 | 機能ゲーティング判定用 |

### コードレビュー時の必須チェック

新規エンドポイント・新規DBカラム・新規ログ出力を追加したとき、以下を全部 No であることを確認:
- 気分タップの内容がリクエストボディ・レスポンス・ログに含まれていないか?
- 日記メモ本文がHTTPを通っていないか?
- ピクセル履歴の数値配列がサーバーに送られていないか?
- ユーザー氏名らしきフィールドが追加されていないか?

1つでも Yes なら設計違反。STEPに戻って削除。

## 暗号化(emergency_email のみ)

- **アルゴリズム**: AES-256-GCM
- **鍵**: 環境変数 `HIBIX_AES_KEY`(32 byte hex)。`wrangler secret put HIBIX_AES_KEY` で登録
- **IV**: リクエストごとに 12 byte ランダム生成
- **保存形式**: `email_encrypted` / `email_iv` / `email_tag` を base64 で個別カラム保存(PRD §4.2 / §10.3)
- **実装**: Workers側は Web Crypto API(`crypto.subtle`)を使う。`node:crypto` は使わない

## 認証

- **方式**: 匿名UUID + iOS Keychain(iCloud同期)。Apple Sign-In は v0.1 採用せず
- **ヘッダ**: 全API リクエストに `X-Hibix-UUID: <uuid>` 必須(`/api/cron/check` 除く・PRD §8.1)
- **形式バリデーション**: UUID v4 でない値は 400 Bad Request

## レート制限(設計書 v0.7 §5.2 / §5.3)

| 項目 | 上限 | 違反時 |
|---|---|---|
| 1ユーザー ping | 1日10回まで | 429 Too Many Requests |
| 緊急連絡先メール送信 | 同一ユーザー24時間1回 | 送信スキップ(notification_logs 確認) |
| 緊急連絡先登録数 | 1ユーザー最大3件 | 4件目で 400 Bad Request |

## ログ・監査

- 緊急連絡先メール送信は全件 `notification_logs` に記録
- ログ保持期間: 30日(以降自動削除)
- ログには **メールアドレス本文を残さない**(`user_id` と `delivery_status` のみ)
- `print` / `console.log` を本番に残さない(`os_log` / `Logger` 使用)

## シークレット管理

- `.env` ファイルをコミットしない(`.gitignore` 必須)
- iOS側: APIキーをハードコードしない(v0.1ではAPI Key不要だが将来用ルール)
- Backend側: `wrangler secret put` でのみ登録、`wrangler.toml` に書かない
- **Gitleaks** を pre-commit hook と CI で実行(設計書 v0.7 §5.2)

## データ削除権(48時間SLO)

- 個人情報保護法 第30条対応
- 削除リクエスト受理 → 48時間以内に完全消去
- iOS側: GRDB DBファイル削除 + Keychain クリア + UserDefaults リセット
- Backend側: `deletion_requests` に挿入 → `scheduled()` 内で48h経過後に物理削除
- 削除完了は `deletion_requests.completed_at` に記録

## 第三者SDK 全面禁止

- 解析: Firebase Analytics / Mixpanel / Amplitude / Sentry 等 すべて不可
- 広告: AdMob / 他広告SDK すべて不可
- クラッシュレポート: 必要になったら設計書を更新して追加可(v0.1 では追加しない)
- **ATT(App Tracking Transparency)プロンプトが不要な設計を維持する**

## 法務・表現規制

- **薬機法NG表現**: 「治療」「改善」「予防」を **コード・コメント・通知本文・エラーメッセージ・テスト名 のいずれにも書かない**
- 通知メール本文には「医療代替・緊急通報サービスではない」明示(PRD §6 F-07)

## ドキュメント同期ルール

このファイルを更新したら、もう一方のリポジトリの `common-security/SKILL.md` も同時に更新する。差分があればCC設計士に再生成を依頼。
