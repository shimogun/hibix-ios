# Hibix マーケティング Web サイト

App Store 審査・ユーザー導線向けの静的ウェブサイト。

## ファイル一覧

| パス | 用途 | App Store Connect 入力先 |
|---|---|---|
| `privacy.html` | プライバシーポリシー | アプリプライバシー / プライバシーポリシーURL |
| `support.html` | サポート（FAQ + 連絡先） | アプリ情報 / サポートURL |

## デプロイ計画（未実施・5/28 までに完遂）

### 想定構成

- **ドメイン**: `hibix.app` (apex)（既に取得済 / 2026-05-15）
- **公開URL**:
  - `https://hibix.app/privacy.html` (or `/privacy/`)
  - `https://hibix.app/support.html` (or `/support/`)
- **API サブドメイン**: `https://api.hibix.app` ← hibix-backend (Cloudflare Workers) 専用

### デプロイ方式の候補

| 候補 | 採否 | 備考 |
|---|---|---|
| Cloudflare Pages (独立プロジェクト) | 🟢 推奨 | apex `hibix.app` を Pages に向ける。`api.hibix.app` は Workers の routes で吸う |
| hibix-backend Worker から配信 | 🟡 代替 | `/privacy`, `/support` ルートを Worker に追加。簡素だが将来 LP 拡張で分離コスト発生 |
| GitHub Pages | ⚪ 不採用 | hibix.app DNS を別所有者に向けるオーバヘッド |

### 推奨手順 (Cloudflare Pages)

1. Cloudflare Dashboard → Pages → Create a project → Direct Upload を選択
2. プロジェクト名: `hibix-website`
3. このディレクトリ全体 (`privacy.html`, `support.html`, `README.md` 以外) を zip でアップロード
4. Pages の Custom domain で `hibix.app` (apex) を割り当て
5. DNS は Cloudflare で自動構成 (CNAME flattening)
6. `api.hibix.app` の Routes は hibix-backend `wrangler.toml [env.production]` の routes に設定

### 確認用 URL（デプロイ後）

```
https://hibix.app/privacy.html
https://hibix.app/support.html
```

## 修正・更新ルール

- プライバシーポリシーは PRD §10 と整合させる（PRD 更新時は本ファイルも更新する）
- v0.2 でサーバー側機能が拡張された場合は、「1.2 サーバーに保存する情報」を更新
- 改定時は `最終更新日` のみ書き換え、本文の構造（章番号）は維持する

## App Store Connect 入力チェックリスト

- [ ] アプリ情報 → プライバシーポリシーURL: `https://hibix.app/privacy.html`
- [ ] アプリ情報 → サポートURL: `https://hibix.app/support.html`
- [ ] アプリ情報 → マーケティングURL（任意）: `https://hibix.app/`（LP がなければサポート URL と同じでも可）
