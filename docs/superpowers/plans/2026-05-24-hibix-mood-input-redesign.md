# Hibix 気分入力体験リデザイン Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hibix の気分入力体験を「1アクション・2バリュー」コアバリュー実現に向けて全面リデザインする（D1+F1+F2+F3）。5/31 リリース・6/1 X告知ローンチ。

**Architecture:** MoodLevel を7段階→5段階に集約（rawValue維持で DB schema 変更回避）、MoodPickerView を SF Symbol + ラベル + 長押し対応に全面リライト、MoodMemoView に気分関連絵文字パレットを追加、保存後アニメ + トースト を HomeView に統合。

**Tech Stack:** Swift / SwiftUI / GRDB（既存 DB 影響なし）/ Swift Testing。

**Spec:** `docs/superpowers/specs/2026-05-24-hibix-mood-input-redesign-design.md`

---

## File Structure

| 区分 | パス | 役割 |
|------|------|------|
| **Modify** | `Hibix/Core/Models/MoodLevel.swift` | 5段階化 + `fromStoredValue` ファクトリ |
| Modify | `Hibix/Core/Database/MoodEntryRepository.swift` | decode 経路を `fromStoredValue` 経由に変更 |
| Modify | `Hibix/Features/MoodEntry/MoodPickerView.swift` | SF Symbol + ラベル + 長押し対応にリライト |
| Modify | `Hibix/Features/MoodEntry/MoodMemoView.swift` | 絵文字パレット追加 |
| **Create** | `Hibix/Features/MoodEntry/MoodEmojiPalette.swift` | 気分→絵文字配列マッピング + パレットView |
| Modify | `Hibix/Features/Home/HomeViewModel.swift` | `recordMoodWithoutMemo` / `lastSavedMood` / `toastMessage` 追加 |
| Modify | `Hibix/Features/Home/HomeView.swift` | flyingReplica overlay + トースト overlay 統合 |
| **Create** | `HibixTests/Core/MoodLevelTests.swift` | `fromStoredValue` 検証 |
| **Create** | `HibixTests/MoodEntry/MoodEmojiPaletteTests.swift` | 気分別絵文字選定検証 |
| Modify | `HibixTests/HomeTests/HomeViewModelTests.swift` | `recordMoodWithoutMemo` 追加 + 既存テストの sink/uplift マッピング検証 |
| Modify | `docs/PRD.md` | MoodLevel 5段階化を §5.x に反映 |

---

## Task 1: MoodLevel 5段階化 + Migration ファクトリ

**Files:**
- Modify: `Hibix/Core/Models/MoodLevel.swift`
- Modify: `Hibix/Core/Database/MoodEntryRepository.swift`
- Create: `HibixTests/Core/MoodLevelTests.swift`
- Modify: `HibixTests/HomeTests/HomeViewModelTests.swift` (sink/uplift を使ってる箇所のみ)

- [ ] **Step 1: Write failing test for MoodLevel.fromStoredValue migration**

Create `HibixTests/Core/MoodLevelTests.swift`:

```swift
import Testing
@testable import Hibix

@Suite("MoodLevel")
struct MoodLevelTests {

    @Test
    func fromStoredValue_returnsNewCases_forValidRawValues() {
        #expect(MoodLevel.fromStoredValue(1) == .down)
        #expect(MoodLevel.fromStoredValue(3) == .calm)
        #expect(MoodLevel.fromStoredValue(4) == .neutral)
        #expect(MoodLevel.fromStoredValue(5) == .good)
        #expect(MoodLevel.fromStoredValue(7) == .best)
    }

    @Test
    func fromStoredValue_migratesLegacySink_toDown() {
        // 旧 sink(2) → 新 down(1) にマッピング
        #expect(MoodLevel.fromStoredValue(2) == .down)
    }

    @Test
    func fromStoredValue_migratesLegacyUplift_toGood() {
        // 旧 uplift(6) → 新 good(5) にマッピング
        #expect(MoodLevel.fromStoredValue(6) == .good)
    }

    @Test
    func fromStoredValue_returnsNil_forOutOfRange() {
        #expect(MoodLevel.fromStoredValue(0) == nil)
        #expect(MoodLevel.fromStoredValue(8) == nil)
        #expect(MoodLevel.fromStoredValue(-1) == nil)
    }

    @Test
    func allCases_areFiveLevels_inAscendingOrder() {
        let cases = MoodLevel.allCases
        #expect(cases.count == 5)
        #expect(cases == [.down, .calm, .neutral, .good, .best])
    }

    @Test
    func displayName_returnsJapaneseLabels() {
        #expect(MoodLevel.down.displayName == "落ち込み")
        #expect(MoodLevel.calm.displayName == "平静")
        #expect(MoodLevel.neutral.displayName == "普通")
        #expect(MoodLevel.good.displayName == "良い")
        #expect(MoodLevel.best.displayName == "最高")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests/MoodLevelTests`

Expected: `fromStoredValue` not defined → compile error

- [ ] **Step 3: Implement MoodLevel 5段階化 + fromStoredValue**

Replace `Hibix/Core/Models/MoodLevel.swift` entire content:

```swift
import Foundation

nonisolated enum MoodLevel: Int, CaseIterable, Sendable {
    case down = 1
    case calm = 3
    case neutral = 4
    case good = 5
    case best = 7

    var displayName: String {
        switch self {
        case .down:    return "落ち込み"
        case .calm:    return "平静"
        case .neutral: return "普通"
        case .good:    return "良い"
        case .best:    return "最高"
        }
    }

    var accessibilityLabel: String {
        "気分\(rawValue)、\(displayName)"
    }

    /// DBに保存された rawValue から MoodLevel を復元する。
    /// 旧 sink(2) は down(1) に、旧 uplift(6) は good(5) にマイグレーションする。
    static func fromStoredValue(_ rawValue: Int) -> MoodLevel? {
        switch rawValue {
        case 1, 2: return .down       // sink(2) は down に集約
        case 3:    return .calm
        case 4:    return .neutral
        case 5, 6: return .good       // uplift(6) は good に集約
        case 7:    return .best
        default:   return nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests/MoodLevelTests`

Expected: All 6 tests PASS

- [ ] **Step 5: Find all MoodLevel decode sites and switch to fromStoredValue**

Run: `grep -rn "MoodLevel(rawValue:" /Users/a/Develop/Hibix/hibix-ios/Hibix/`

For each occurrence (likely in `MoodEntryRepository.swift` or related), replace:

```swift
// Before:
guard let mood = MoodLevel(rawValue: row[Columns.mood]) else { return nil }
// After:
guard let mood = MoodLevel.fromStoredValue(row[Columns.mood]) else { return nil }
```

- [ ] **Step 6: Update existing tests that reference removed cases (sink, uplift)**

Run: `grep -rn "\.sink\|\.uplift" /Users/a/Develop/Hibix/hibix-ios/HibixTests/`

For each test:
- `.sink` (旧 rawValue 2) → 同様の意図のテストなら `.down` に置換
- `.uplift` (旧 rawValue 6) → `.good` に置換
- もし「migration検証」目的のテストがあれば、`MoodLevel.fromStoredValue(2)` 形式の呼び出しに書き換え

- [ ] **Step 7: Run full HibixTests suite to verify no regressions**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests`

Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
cd /Users/a/Develop/Hibix/hibix-ios
git add Hibix/Core/Models/MoodLevel.swift Hibix/Core/Database/MoodEntryRepository.swift HibixTests/Core/MoodLevelTests.swift HibixTests/HomeTests/HomeViewModelTests.swift
git commit -m "feat: MoodLevel を 7段階から5段階に集約 (rawValue維持 + migration ファクトリ)"
```

---

## Task 2: MoodPickerView SF Symbol + ラベル + 既存タップ動作維持

**Files:**
- Modify: `Hibix/Features/MoodEntry/MoodPickerView.swift`
- Modify: `Hibix/Core/Models/MoodLevel.swift` (SF Symbol プロパティ追加)

- [ ] **Step 1: Add iconName property to MoodLevel**

Edit `Hibix/Core/Models/MoodLevel.swift`, add after `accessibilityLabel`:

```swift
    var iconName: String {
        switch self {
        case .down:    return "cloud.rain.fill"
        case .calm:    return "cloud.fill"
        case .neutral: return "circle.fill"
        case .good:    return "sun.max.fill"
        case .best:    return "sparkles"
        }
    }
```

- [ ] **Step 2: Replace MoodPickerView with new SF Symbol + label layout**

Replace `Hibix/Features/MoodEntry/MoodPickerView.swift` entire content:

```swift
import SwiftUI
import UIKit

struct MoodPickerView: View {
    let selected: MoodLevel?
    let onSelect: (MoodLevel) -> Void
    var onLongPress: ((MoodLevel) -> Void)? = nil

    private static let buttonCount: Int = MoodLevel.allCases.count
    private static let maxDiameter: CGFloat = 64
    private static let minDiameter: CGFloat = 56
    private static let spacing: CGFloat = 12
    private static let labelHeight: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = Self.spacing * CGFloat(Self.buttonCount - 1)
            let perButton = (proxy.size.width - totalSpacing) / CGFloat(Self.buttonCount)
            let diameter = min(Self.maxDiameter, max(Self.minDiameter, perButton))
            HStack(spacing: Self.spacing) {
                ForEach(MoodLevel.allCases, id: \.self) { level in
                    MoodPickerButton(level: level,
                                     isSelected: selected == level,
                                     diameter: diameter,
                                     onTap: { onSelect(level) },
                                     onLongPress: { onLongPress?(level) })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: Self.maxDiameter + Self.labelHeight + 4)
        .accessibilityElement(children: .contain)
    }
}

private struct MoodPickerButton: View {
    let level: MoodLevel
    let isSelected: Bool
    let diameter: CGFloat
    let onTap: () -> Void
    let onLongPress: () -> Void

    private static let selectionStrokeWidth: CGFloat = 3
    private static let labelHeight: CGFloat = 16

    var body: some View {
        VStack(spacing: 4) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.moodColor(for: level))
                    Image(systemName: level.iconName)
                        .font(.system(size: diameter * 0.4, weight: .semibold))
                        .foregroundStyle(.white)
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: isSelected ? Self.selectionStrokeWidth : 0)
                }
                .frame(width: diameter, height: diameter)
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(.easeOut(duration: 0.1), value: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(level.accessibilityLabel)
            .accessibilityHint("タップして今日の気分を記録、長押しで即記録")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

            Text(isSelected ? level.displayName : "")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(height: Self.labelHeight)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    @Previewable @State var selected: MoodLevel? = .good
    return MoodPickerView(selected: selected) { level in
        selected = level
    }
    .padding()
}
```

- [ ] **Step 3: Build and verify no compile errors**

Run: `xcodebuild -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run all tests to verify no regressions**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests`

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/a/Develop/Hibix/hibix-ios
git add Hibix/Core/Models/MoodLevel.swift Hibix/Features/MoodEntry/MoodPickerView.swift
git commit -m "feat: MoodPickerView に SF Symbol アイコン + 選択時ラベル表示を追加"
```

---

## Task 3: F1 長押しジェスチャー + recordMoodWithoutMemo

**Files:**
- Modify: `Hibix/Features/Home/HomeViewModel.swift`
- Modify: `Hibix/Features/MoodEntry/MoodPickerView.swift`
- Modify: `Hibix/Features/Home/HomeView.swift`
- Modify: `HibixTests/HomeTests/HomeViewModelTests.swift`

- [ ] **Step 1: Write failing test for recordMoodWithoutMemo**

Add to `HibixTests/HomeTests/HomeViewModelTests.swift`:

```swift
    @Test
    func recordMoodWithoutMemo_savesEntryWithNilMemo() async throws {
        let repo = InMemoryMoodEntryRepository()
        let viewModel = await HomeViewModel(repository: repo,
                                            checkinService: nil,
                                            now: { Date(timeIntervalSince1970: 1_716_000_000) })
        await viewModel.load(isPro: false)

        await viewModel.recordMoodWithoutMemo(.good)

        let today = HibixDate.todayString(now: Date(timeIntervalSince1970: 1_716_000_000))
        let entry = await viewModel.calendarEntries[today]
        #expect(entry?.mood == .good)
        #expect(entry?.memo == nil)
    }

    @Test
    func recordMoodWithoutMemo_doesNotPresentMemoSheet() async throws {
        let repo = InMemoryMoodEntryRepository()
        let viewModel = await HomeViewModel(repository: repo, checkinService: nil)

        await viewModel.recordMoodWithoutMemo(.calm)

        let isPresented = await viewModel.isMemoSheetPresented
        #expect(isPresented == false)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests/HomeViewModelTests`

Expected: FAIL with `recordMoodWithoutMemo` not defined

- [ ] **Step 3: Add recordMoodWithoutMemo to HomeViewModel**

Add to `Hibix/Features/Home/HomeViewModel.swift` after `recordMood(_:)`:

```swift
    /// 長押し起動: memo なしで気分のみ即保存する (F1)。
    func recordMoodWithoutMemo(_ level: MoodLevel) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        let date = HibixDate.todayString(now: now())
        do {
            let tapAt = now()
            let entry = try await repository.upsert(date: date,
                                                    level: level,
                                                    memo: nil,
                                                    now: tapAt)
            calendarEntries[date] = entry
            updateEarliestEntryDateOnInsert(entry: entry)
            lastErrorMessage = nil
            Self.logger.info("Recorded mood (no memo) level=\(level.rawValue, privacy: .public) date=\(date, privacy: .public)")
            if let checkinService {
                Task { await checkinService.reportCheckin(at: tapAt) }
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            Self.logger.error("Record mood without memo failed: \(error.localizedDescription, privacy: .public)")
        }
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests/HomeViewModelTests`

Expected: All HomeViewModelTests PASS

- [ ] **Step 5: Add long-press gesture to MoodPickerButton**

Edit `Hibix/Features/MoodEntry/MoodPickerView.swift`, replace `MoodPickerButton` body:

```swift
    @State private var isPressed: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.moodColor(for: level))
                Image(systemName: level.iconName)
                    .font(.system(size: diameter * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                Circle()
                    .strokeBorder(Color.primary, lineWidth: isSelected ? Self.selectionStrokeWidth : 0)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(isPressed ? 1.2 : (isSelected ? 1.08 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isPressed)
            .animation(.easeOut(duration: 0.1), value: isSelected)
            .onLongPressGesture(minimumDuration: 0.5,
                                maximumDistance: 20,
                                perform: {
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    onLongPress()
                                },
                                onPressingChanged: { pressing in
                                    isPressed = pressing
                                    if pressing {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                })
            .simultaneousGesture(
                TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTap()
                }
            )
            .accessibilityLabel(level.accessibilityLabel)
            .accessibilityHint("タップして気分を記録、長押しでメモなし即記録")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

            Text(isSelected ? level.displayName : "")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(height: Self.labelHeight)
                .accessibilityHidden(true)
        }
    }
```

- [ ] **Step 6: Wire onLongPress in HomeView**

Edit `Hibix/Features/Home/HomeView.swift`, update `picker` computed property:

```swift
    private var picker: some View {
        MoodPickerView(
            selected: viewModel.todayEntry?.mood,
            onSelect: { level in
                Task {
                    await viewModel.recordMood(level)
                }
            },
            onLongPress: { level in
                Task {
                    await viewModel.recordMoodWithoutMemo(level)
                }
            }
        )
    }
```

Also update `moodPickerSheet` similarly to support long-press in the sheet:

```swift
    private var moodPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("今日の気分を選んでください")
                    .font(.title3)
                    .fontWeight(.semibold)
                MoodPickerView(
                    selected: viewModel.todayEntry?.mood,
                    onSelect: { level in
                        Task {
                            await viewModel.recordMood(level)
                            isMoodPickerSheetPresented = false
                        }
                    },
                    onLongPress: { level in
                        Task {
                            await viewModel.recordMoodWithoutMemo(level)
                            isMoodPickerSheetPresented = false
                        }
                    }
                )
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        isMoodPickerSheetPresented = false
                    }
                }
            }
        }
    }
```

- [ ] **Step 7: Build and run full test suite**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests`

Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
cd /Users/a/Develop/Hibix/hibix-ios
git add Hibix/Features/Home/HomeViewModel.swift Hibix/Features/MoodEntry/MoodPickerView.swift Hibix/Features/Home/HomeView.swift HibixTests/HomeTests/HomeViewModelTests.swift
git commit -m "feat: 気分長押し(0.5秒)で memo なし即保存 (F1)"
```

---

## Task 4: F2 MoodMemoView 絵文字パレット

**Files:**
- Create: `Hibix/Features/MoodEntry/MoodEmojiPalette.swift`
- Modify: `Hibix/Features/MoodEntry/MoodMemoView.swift`
- Create: `HibixTests/MoodEntry/MoodEmojiPaletteTests.swift`

- [ ] **Step 1: Write failing test for MoodEmojiPalette**

Create `HibixTests/MoodEntry/MoodEmojiPaletteTests.swift`:

```swift
import Testing
@testable import Hibix

@Suite("MoodEmojiPalette")
struct MoodEmojiPaletteTests {

    @Test
    func returnsSixEmojis_forEachMood() {
        for level in MoodLevel.allCases {
            let emojis = MoodEmojiPalette.emojis(for: level)
            #expect(emojis.count == 6, "MoodLevel \(level) should have 6 emojis")
        }
    }

    @Test
    func returnsDistinctSets_forDifferentMoods() {
        let downSet = Set(MoodEmojiPalette.emojis(for: .down))
        let bestSet = Set(MoodEmojiPalette.emojis(for: .best))
        let intersection = downSet.intersection(bestSet)
        #expect(intersection.isEmpty, "down と best は絵文字が被ってはならない")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests/MoodEmojiPaletteTests`

Expected: `MoodEmojiPalette` not defined → compile error

- [ ] **Step 3: Create MoodEmojiPalette**

Create `Hibix/Features/MoodEntry/MoodEmojiPalette.swift`:

```swift
import SwiftUI

enum MoodEmojiPalette {
    static func emojis(for level: MoodLevel) -> [String] {
        switch level {
        case .down:    return ["😔", "😟", "🌧️", "💧", "🥀", "☁️"]
        case .calm:    return ["🕊️", "😌", "🍃", "🌫️", "🍵", "📖"]
        case .neutral: return ["🙂", "😐", "☕", "💭", "🚶", "📚"]
        case .good:    return ["😊", "☀️", "🌻", "🍀", "✨", "😄"]
        case .best:    return ["🤩", "🎉", "🌈", "🎆", "⭐", "💯"]
        }
    }
}

struct MoodEmojiPaletteView: View {
    let level: MoodLevel
    let onSelect: (String) -> Void

    private static let buttonSize: CGFloat = 44
    private static let spacing: CGFloat = 6

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.spacing) {
                ForEach(MoodEmojiPalette.emojis(for: level), id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: Self.buttonSize, height: Self.buttonSize)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("絵文字 \(emoji) を挿入")
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: Self.buttonSize + 4)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests/MoodEmojiPaletteTests`

Expected: 2 tests PASS

- [ ] **Step 5: Integrate palette into MoodMemoView**

Edit `Hibix/Features/MoodEntry/MoodMemoView.swift`, update `body`:

```swift
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                moodBadge
                editor
                if let mood {
                    MoodEmojiPaletteView(level: mood) { emoji in
                        text.append(emoji)
                    }
                }
                counter
            }
            .padding(16)
            .navigationTitle("今日のメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                text = initialMemo ?? ""
                isEditorFocused = true
            }
        }
    }
```

- [ ] **Step 6: Build and run full test suite**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests`

Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
cd /Users/a/Develop/Hibix/hibix-ios
git add Hibix/Features/MoodEntry/MoodEmojiPalette.swift Hibix/Features/MoodEntry/MoodMemoView.swift HibixTests/MoodEntry/MoodEmojiPaletteTests.swift
git commit -m "feat: MoodMemoView に気分関連絵文字パレットを追加 (F2)"
```

---

## Task 5: F3 アニメーション + トースト

**Files:**
- Modify: `Hibix/Features/Home/HomeViewModel.swift` (state追加)
- Modify: `Hibix/Features/Home/HomeView.swift` (overlay追加)

- [ ] **Step 1: Add state for F3 animation in HomeViewModel**

Edit `Hibix/Features/Home/HomeViewModel.swift`, add after existing `var` declarations:

```swift
    /// F3 アニメ用: 最後に保存された気分。non-nil の間 flying replica overlay が表示される。
    var lastSavedMood: MoodLevel?
    /// 保存完了トーストの文言。non-nil の間トーストが表示される。
    var toastMessage: String?
```

Update `recordMood(_:)` to trigger animations after successful save (insert before `isMemoSheetPresented = true`):

```swift
            calendarEntries[date] = entry
            updateEarliestEntryDateOnInsert(entry: entry)
            lastErrorMessage = nil
            triggerSaveFeedback(level: level)
            isMemoSheetPresented = true
```

Update `recordMoodWithoutMemo(_:)` similarly (insert before `lastErrorMessage = nil` line / after assignment):

```swift
            calendarEntries[date] = entry
            updateEarliestEntryDateOnInsert(entry: entry)
            lastErrorMessage = nil
            triggerSaveFeedback(level: level)
```

Add private helper method:

```swift
    private func triggerSaveFeedback(level: MoodLevel) {
        lastSavedMood = level
        toastMessage = "気分を記録しました"
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await MainActor.run { self.lastSavedMood = nil }
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run { self.toastMessage = nil }
        }
    }
```

- [ ] **Step 2: Add flying replica and toast overlay in HomeView**

Edit `Hibix/Features/Home/HomeView.swift`, modify the outermost VStack/NavigationStack `body` to attach two `.overlay` modifiers after the existing `.sheet` chain (before the closing `}`):

```swift
            .overlay(alignment: .center) {
                if let mood = viewModel.lastSavedMood {
                    flyingReplica(for: mood)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottom) {
                if let message = viewModel.toastMessage {
                    Text(message)
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 80)
                        .transition(.opacity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(message)
                }
            }
            .animation(.spring(duration: 0.6), value: viewModel.lastSavedMood)
            .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
```

Add private builder:

```swift
    private func flyingReplica(for mood: MoodLevel) -> some View {
        ZStack {
            Circle()
                .fill(Color.moodColor(for: mood))
                .frame(width: 96, height: 96)
            Image(systemName: mood.iconName)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 12)
    }
```

- [ ] **Step 3: Build and verify**

Run: `xcodebuild -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -configuration Debug build 2>&1 | tail -5`

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run full test suite**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests`

Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
cd /Users/a/Develop/Hibix/hibix-ios
git add Hibix/Features/Home/HomeViewModel.swift Hibix/Features/Home/HomeView.swift
git commit -m "feat: 保存後フライング・レプリカ + 完了トースト追加 (F3 v0.1 簡略版)"
```

---

## Task 6: PRD 更新 + 全体回帰テスト + 実機検証

**Files:**
- Modify: `docs/PRD.md`

- [ ] **Step 1: Update PRD §5.x to reflect 5-level MoodLevel**

Find section in `docs/PRD.md` describing MoodLevel cases:

Run: `grep -n "down\|sink\|calm\|neutral\|good\|uplift\|best\|MoodLevel" /Users/a/Develop/Hibix/hibix-ios/docs/PRD.md | head -20`

Replace any `sink (rawValue 2)` and `uplift (rawValue 6)` enumeration with notes about migration:

```markdown
| down    | 1 | 落ち込み | 旧 sink(2) はここに集約 |
| calm    | 3 | 平静     |                          |
| neutral | 4 | 普通     |                          |
| good    | 5 | 良い     | 旧 uplift(6) はここに集約 |
| best    | 7 | 最高     |                          |
```

Add to §14 (変更履歴):

```markdown
- **2026-05-24 (v2.3.0)**: MoodLevel を 7段階から5段階に集約 (sink/uplift を down/good にマージ)。rawValue は維持し、Decoderレイヤーで migration。実装計画: `docs/superpowers/plans/2026-05-24-hibix-mood-input-redesign.md`
```

- [ ] **Step 2: Run full HibixTests suite**

Run: `xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1' -only-testing:HibixTests 2>&1 | tail -20`

Expected: TEST SUCCEEDED, no failures

- [ ] **Step 3: Manual real-device verification checklist**

Run on `shingoのiPhone` via Xcode (⌘R), execute:

```
- タップで MoodMemo シート開く → 保存できる
- 長押し0.5秒で memo なし即保存 → トースト出る → カレンダーに反映
- 解除( <0.5秒 ) で何も起きない
- 各気分5つともアイコンが表示・タップできる
- 選択時のラベル「落ち込み」「平静」「普通」「良い」「最高」が出る
- MoodMemo シート: 絵文字パレット表示・タップで text 挿入
- 保存後: 円が画面中央でscale-fadeしながら消える
- トースト「気分を記録しました」が画面下部に1秒表示
- ダークモード/ライトモード両方で表示崩れなし
- iPhone SE 第3世代 simulator でも横並び崩れず
- VoiceOver: アイコンと「長押しでメモなし即記録」読み上げ
- 旧データ (rawValue 2 or 6) があれば down/good として表示される（migration確認）
```

各項目すべて ✅ になるまで Task 5 までの該当箇所に戻って修正。

- [ ] **Step 4: Update UI review memo**

Edit `/Users/a/.company/secretary/notes/2026-05-24-hibix-ui-review.md`, mark items D1/F1/F2/F3 as ✅ 完了済み with implementation summary.

- [ ] **Step 5: Final commit**

```bash
cd /Users/a/Develop/Hibix/hibix-ios
git add docs/PRD.md docs/superpowers/specs/2026-05-24-hibix-mood-input-redesign-design.md docs/superpowers/plans/2026-05-24-hibix-mood-input-redesign.md
git commit -m "docs: PRD と設計書/実装計画書を反映 (MoodLevel 5段階化 + 入力体験リデザイン)"
```

---

## Definition of Done

- [ ] 全 Task の Step が ✅ 完了
- [ ] HibixTests 全緑（regression なし）
- [ ] 実機検証チェックリスト ✅ 全項目
- [ ] PRD §5.x / §14 更新済み
- [ ] secretary/notes/2026-05-24-hibix-ui-review.md の D1/F1/F2/F3 が ✅
- [ ] commit 6 つ以上（タスクごと）
