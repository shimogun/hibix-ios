---
date: 2026-05-24
project: hibix
scope: D1 + F1 + F2 + F3 (気分入力体験リデザイン)
target_launch: 2026-05-31
status: approved
related:
  - docs/PRD.md
  - secretary/notes/2026-05-24-hibix-ui-review.md
---

# Hibix 気分入力体験リデザイン 設計書

## 1. 背景・目的

5/31リリース・6/1 X告知ローンチに向けた UIブラッシュアップの中核施策。
コアバリュー「毎日のひとタップが、自分のメンタル日記になり、誰かを安心させる」(1アクション・2バリュー) を満たす入力体験を構築する。

### 1.1 現状の課題（実機検証で判明）

- **D1: 気分の視認性** — MoodPickerView は単色円のみで、どの色がどの気分か直感的に分からない
- **F1: 入力工数最小化が未実装** — タップすると MoodMemo シートが必ず表示される。「ひとタップで完了」する動線がない
- **F2: メモが文章入力前提** — 文章を書くのが面倒な日でも記録できる軽量フローがない
- **F3: 保存後フィードバックが弱い** — 何が記録されたか視覚的に伝わらない

### 1.2 解決後の体験

```
気分長押し(0.5秒)
  → ハプティック + 円拡大
  → memoなしで保存
  → 色付き円がカレンダーマス位置に移動 + バウンス
  → "記録しました" トースト 0.6秒
合計約1秒で1日の記録完了
```

文章を書きたい日は **タップ → MoodMemo** で従来通り、面倒な日は **長押し → 即完了** という二段構え。

## 2. データモデル変更

### 2.1 MoodLevel 5段階化

| 旧 (7段階) | 新 (5段階) | rawValue | displayName |
|----|----|----|----|
| down(1) / sink(2) | **down** | 1 | 落ち込み |
| calm(3) | **calm** | 3 | 平静 |
| neutral(4) | **neutral** | 4 | 普通 |
| good(5) / uplift(6) | **good** | 5 | 良い |
| best(7) | **best** | 7 | 最高 |

### 2.2 Migration 方針

**rawValue を維持することで DB schema 変更を回避**。

- `MoodLevel.init?(rawValue:)` だけでは `2` や `6` を decode できなくなる
- そのため `MoodLevel.fromStoredValue(_ rawValue: Int)` ファクトリメソッドを追加
  - `2` → `.down` (1にマッピング)
  - `6` → `.good` (5にマッピング)
  - 範囲外 → `nil`
- `MoodEntryRepository` 内の decode 箇所をすべてファクトリ経由に切り替え
- 既存データへの破壊的変更なし

### 2.3 Backend 影響

PRD §4.2 により mood_level はサーバー送信しない（checkin event のみ送信）。
Backend 側の `mood_level` バリデーション値は変更不要。

### 2.4 PRD 更新

- §5.x 系の MoodLevel 列挙を 5段階に修正
- 設計判断の経緯を §14 (変更履歴) に追記

## 3. MoodPickerView 新仕様

### 3.1 ビジュアル

```
[●][●][●][●][●]
☁︎  〜  ○  ☀︎  ✨
        晴            ← 選択中のみ表示
```

| 要素 | 仕様 |
|---|---|
| 円直径 | iPhone 16: 64pt / iPhone SE 3: 56pt (動的計算) |
| 円間スペース | 12pt |
| アイコン | SF Symbol (背景色付き円の上に白抹き、サイズは円の50%) |
| 選択時 | 1.08x スケール + ハプティック (medium) + ラベル表示 |
| ラベル | アイコン下 4pt、`.caption2` + `.fontWeight(.semibold)` |

### 3.2 SF Symbol 候補

| MoodLevel | SF Symbol | 意味 |
|---|---|---|
| down(1) | `cloud.rain.fill` | 雨雲 |
| calm(3) | `cloud.fill` | 曇り |
| neutral(4) | `circle.fill` | 中性（無） |
| good(5) | `sun.max.fill` | 晴れ |
| best(7) | `sparkles` | きらきら |

カラーは D2 (カラー・フォント方針) で確定。暫定: `Color.moodColor(for:)` の既存定義を流用。

### 3.3 タップ動作（既存維持）

- 単一タップ → `onSelect(level)` 呼び出し → MoodMemoシート表示（HomeView 側）

### 3.4 長押し動作（F1: 新規）

長押しジェスチャーは `.onLongPressGesture(minimumDuration: 0.5, ...)` で実装。

| 経過時間 | 挙動 |
|---|---|
| 0.0s | 押下開始。ハプティック軽 (selectionChanged) |
| 0.0-0.5s | 円が線形に 1.0x → 1.2x へ拡大（押下中は内部 state でアニメ） |
| 0.5s 到達 | ハプティック大 (impactOccurred medium) + 即保存呼び出し (`onLongPress(level)`) |
| 解除 | 円が元サイズに戻る (easeOut 0.15s) |

途中で指を離した場合は保存しない（円は元サイズに戻る）。

HomeView 側で `onLongPress` ハンドラを実装：
- `recordMood(level)` を memo=nil で呼び出し
- F3 アニメーションを開始
- トースト表示

### 3.5 アクセシビリティ

- `accessibilityLabel`: 既存維持
- `accessibilityCustomActions`: `"長押しで即記録"` を追加（VoiceOver では長押し代替手段が必要）
- ラベルが選択時のみ表示される件は VoiceOver では関係ない（label に既に含まれる）

## 4. MoodMemoView 新仕様 (F2)

### 4.1 ビジュアル

```
┌── 今日のメモ ──────────┐
│ ☀️ 晴れ                │
│ ┌─ TextEditor ─────┐  │
│ │ 今日はいい一日|   │  │
│ │                  │  │
│ └──────────────────┘  │
│ ┌── 絵文字パレット ──┐ │
│ │ [☀️][⛅][✨][🌈]   │ │
│ │ [🌻][🍀]   →ｽｸﾛｰﾙ │ │
│ └──────────────────┘  │
│              15 / 250  │
└────────────────────────┘
[スキップ]      [保存]
```

### 4.2 絵文字パレット

- 配置: TextEditor と文字数カウンタの間
- レイアウト: `ScrollView(.horizontal)` 内に絵文字ボタン横並び
- ボタンサイズ: 44pt（タップ領域）+ 6pt 間隔
- タップ動作: 現在のカーソル位置に絵文字挿入（カーソル位置取得困難な場合は末尾追加）
- 文字数カウンタは絵文字も含めてカウント（既存 `text.count` 維持）

### 4.3 絵文字パレット中身（気分別）

| MoodLevel | 絵文字（6個） |
|---|---|
| down | 😔 😟 🌧️ 💧 🥀 ☁️ |
| calm | 🕊️ 😌 🍃 🌫️ 🍵 📖 |
| neutral | 🙂 😐 ☕ 💭 🚶 📚 |
| good | 😊 ☀️ 🌻 🍀 ✨ 😄 |
| best | 🤩 🎉 🌈 🎆 ⭐ 💯 |

選択中の mood に応じて 6個を表示。

### 4.4 既存挙動の維持

- スキップ → memo を nil のまま保存
- 保存 → 入力テキストで保存
- 文字数オーバー時の保存無効化

## 5. F3: 保存後アニメーション

### 5.1 概要

保存（タップ→保存、長押し→即保存、MoodMemo→保存 すべて共通）した瞬間、選んだ気分の **色付き円のレプリカ** が MoodPickerView の位置からカレンダーの対応マス位置へ直線移動し、マスがバウンスする。

### 5.2 実装方針（v0.1 簡略版で確定）

v0.1 リリースは **「画面中央付近で円が拡大→縮小してフェード」** のシンプル版で実装する。
カレンダーマス位置への動的補間（matchedGeometryEffect + ScrollView内座標計算）は v0.2 へ送る。

理由: ScrollView 内のマス座標を取得する `GeometryReader` の伝播 + ScrollView スクロール位置との整合が複雑で、5/31リリースに対するリスクが大きい。簡略版でも「保存した瞬間に何かが起きる」フィードバックは成立する。

実装:
- HomeView 上に `.overlay` で `flyingReplicaView`（選んだ気分の色付き円）を配置
- `viewModel.lastSavedMood` が non-nil の間だけ表示
- `.transition(.scale + .opacity)` + `.animation(.spring(duration: 0.6))` で表示中に拡大→縮小→フェード
- 0.6秒後に `lastSavedMood = nil` でクリア

#### 5.2.1 アニメーション仕様

```
t=0.0s: 円がMoodPicker位置で 1.0x
t=0.1s: 円がカレンダー手前位置で 1.4x（拡大しながら移動）
t=0.4s: 円が同位置で 0.0x（フェードアウト）+ カレンダーが軽くバウンス（spring）
t=0.6s: 終了
```

トーストは並行して fadeIn → 0.5s → fadeOut（合計 0.6s + 1.0s）

### 5.3 トースト仕様

- 位置: 画面下から 80pt
- 背景: `.regularMaterial` で透過ガラス
- 文言: 「気分を記録しました」
- アクセシビリティ: `.accessibilityElement(children: .combine)` + announce

## 6. HomeView 統合

### 6.1 役割分担

- HomeView: namespace 管理 + flyingReplica overlay + トースト overlay
- MoodPickerView: タップ/長押しイベント発火、純粋なUI
- HomeViewModel: 既存の `recordMood(_:)` + memo保存ロジック維持

### 6.2 ViewModel 拡張

```swift
@Observable
final class HomeViewModel {
    // 既存
    var calendarEntries: [String: MoodEntry] = [:]
    var isMemoSheetPresented: Bool = false

    // 新規
    var lastSavedMood: MoodLevel?       // F3アニメ用
    var toastMessage: String?           // トースト表示
    private(set) var pendingLevel: MoodLevel?  // 長押し→保存判定中

    func recordMoodWithoutMemo(_ level: MoodLevel) async {
        await repository.upsert(date: today, level: level, memo: nil)
        await refreshCalendar()
        lastSavedMood = level
        toastMessage = "気分を記録しました"
        // 1秒後にトーストクリア
    }
}
```

## 7. 既存テスト変更

| テスト | 変更内容 |
|---|---|
| `MoodLevelTests` (新規) | fromStoredValue で 2→1, 6→5 の migration を検証 |
| `MoodEntryRepositoryTests` | sink(2), uplift(6) を含むテストフィクスチャを 1, 5 にマッピングされることを検証 |
| `HomeViewModelTests` | `recordMoodWithoutMemo` の追加検証 |
| `MoodPickerViewTests` (新規) | 長押し 0.5秒で onLongPress 発火、それ以下では発火しないこと |
| `PixelCalendarGeometryTests` | 変更なし |

## 8. 実装順序

リスク低 → 高の順、各ステップで回帰確認：

1. **STEP 1**: MoodLevel 5段階化 + Migration ファクトリ + テスト（半日）
2. **STEP 2**: SF Symbol アイコン + ラベル + ハプティック（既存タップ動作維持・半日）
3. **STEP 3**: 長押しジェスチャー + 円拡大アニメ + 即保存（F1・半日）
4. **STEP 4**: MoodMemoView 絵文字パレット（F2・半日）
5. **STEP 5**: F3 アニメーション (matchedGeometryEffect + トースト・1日）
6. **STEP 6**: 全体回帰テスト + 実機ループ確認（半日）

**合計: 約3.5日（5/24-5/27 想定）**。
完了後、5/28 TestFlight内部配信、5/29 App Store審査申請、5/30-5/31 審査待ち、6/1 X告知ローンチ。

## 9. スコープ外 (v0.2 以降)

- D2/D3/D4（カラー・フォント・オンボーディング・アイコン）→ 別ブレスト
- F4（緊急連絡先 LINE追加）→ 別実装
- F3 のフルード版（弧軌道・隣セル雪豆・Lottie 等）→ v0.2

## 10. リスク

| リスク | 対策 |
|---|---|
| 長押し誤発火 | 0.5秒固定 + 解除時アニメ復元で検証。短すぎたら 0.7秒に調整 |
| matchedGeometryEffect が ScrollView 内のマス位置で機能しない | カレンダー位置への動的補間は v0.2、初回は画面中央バウンスで簡略化（§5.2 末尾） |
| migration ファクトリ漏れで既存 sink/uplift データが消える | Decoder側を必ず通る設計 + 既存DBに対する手動検証 |
| 5/31 リリースに3.5日では足りない | F3を最初に削る判断ライン。F1+F2+D1 完了で十分リリース可 |
