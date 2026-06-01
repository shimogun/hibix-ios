# オンボーディング刷新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 全機能を網羅し取説を兼ねる9ページの水彩オンボーディングへ刷新し、設定から再閲覧可能にする。

**Architecture:** ロジックは `OnboardingViewModel`（クロージャ注入でテスト可能）に集約。表示は共通 `OnboardingPageScaffold` 上に9ページを構築し、既存 `Color+HibixTheme` の水彩テーマ（ライト/ダーク）を流用。⑨でモード選択→Proモードは既存 `PaywallView` を提示。設定に再閲覧導線を追加。

**Tech Stack:** SwiftUI, Swift Testing(`import Testing`), GRDB(in-memory DatabaseQueue for tests), 既存 `SettingsRepository` / `EntitlementManager` / `NotificationScheduler` / `PaywallView`。

参照spec: `docs/superpowers/specs/2026-06-01-onboarding-redesign-design.md`

---

## File Structure

- Create `Hibix/Features/Onboarding/OnboardingViewModel.swift` — モード選択・完了・ペイウォール分岐ロジック（クロージャ注入）。
- Create `Hibix/Features/Onboarding/OnboardingPageScaffold.swift` — 共通ページレイアウト（イラスト/タイトル/サブ/追加スロット）。
- Modify `Hibix/Features/Onboarding/OnboardingPages.swift` — 9ページView＋イラスト群に再編。
- Modify `Hibix/Features/Onboarding/OnboardingFlow.swift` — 9ページTabView化、`Mode` 追加、ペイウォール提示、VM連携。
- Modify `Hibix/App/RootView.swift` — `OnboardingFlow(dependencies:mode:onCompleted:)` 呼び出し（`mode: .firstRun`）。
- Modify `Hibix/Features/Settings/SettingsView.swift` — 「使い方をもう一度見る」行＋ `OnboardingFlow(mode:.review)` シート。
- Create `HibixTests/OnboardingTests/OnboardingViewModelTests.swift` — VMロジックのユニットテスト。

ビルド確認コマンド（全タスク共通）:
```
xcodebuild build -scheme Hibix -configuration Debug -destination 'platform=iOS Simulator,id=747A07A5-537B-4CD5-9628-3B433A43621F' -quiet
```
（id が無効な場合は `xcrun simctl list devices available | grep "iPhone 17 Pro"` で取得し直す）
テスト実行:
```
xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,id=747A07A5-537B-4CD5-9628-3B433A43621F' -only-testing:HibixTests/OnboardingViewModelTests -quiet
```

---

## Task 1: OnboardingViewModel（ロジック・TDD）

**Files:**
- Create: `Hibix/Features/Onboarding/OnboardingViewModel.swift`
- Test: `HibixTests/OnboardingTests/OnboardingViewModelTests.swift`

- [ ] **Step 1: 失敗するテストを書く**

`HibixTests/OnboardingTests/OnboardingViewModelTests.swift`:
```swift
import Testing
@testable import Hibix

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {

    private final class Spy {
        var saved: [WatchMode] = []
        var completed = false
        var notificationsRequested = false
    }

    private func makeViewModel(isPro: Bool, mode: OnboardingViewModel.Mode = .firstRun)
        -> (OnboardingViewModel, Spy) {
        let spy = Spy()
        let vm = OnboardingViewModel(
            mode: mode,
            isPro: { isPro },
            saveMode: { m in spy.saved.append(m) },
            requestNotifications: { spy.notificationsRequested = true },
            markComplete: { spy.completed = true }
        )
        return (vm, spy)
    }

    @Test
    func selectStart_solo_savesAndCompletes() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.solo)
        #expect(spy.saved == [.solo])
        #expect(spy.completed == true)
        #expect(vm.isPaywallPresented == false)
    }

    @Test
    func selectStart_proModeWhenFree_showsPaywallWithoutSaving() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.gentle)
        #expect(vm.isPaywallPresented == true)
        #expect(vm.pendingProMode == .gentle)
        #expect(spy.saved.isEmpty)
        #expect(spy.completed == false)
    }

    @Test
    func selectStart_proModeWhenPro_savesDirectly() async {
        let (vm, spy) = makeViewModel(isPro: true)
        await vm.selectStartMode(.daily)
        #expect(spy.saved == [.daily])
        #expect(spy.completed == true)
        #expect(vm.isPaywallPresented == false)
    }

    @Test
    func purchaseCompleted_savesPendingModeRequestsNotificationsAndCompletes() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.gentle)   // pending=.gentle, paywall shown
        await vm.handlePurchaseCompleted()
        #expect(spy.saved == [.gentle])
        #expect(spy.notificationsRequested == true)
        #expect(spy.completed == true)
        #expect(vm.pendingProMode == nil)
        #expect(vm.isPaywallPresented == false)
    }

    @Test
    func paywallDismissedWithoutPurchase_fallsBackToSolo() async {
        let (vm, spy) = makeViewModel(isPro: false)
        await vm.selectStartMode(.gentle)
        await vm.handlePaywallDismissedWithoutPurchase()
        #expect(spy.saved == [.solo])
        #expect(spy.completed == true)
        #expect(vm.pendingProMode == nil)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: 上記 test コマンド
Expected: コンパイルエラー（`OnboardingViewModel` 未定義）で FAIL。

- [ ] **Step 3: OnboardingViewModel を実装**

`Hibix/Features/Onboarding/OnboardingViewModel.swift`:
```swift
import Foundation
import Observation

/// オンボーディングのモード選択・完了・ペイウォール分岐ロジック。
/// 依存はクロージャ注入し、View層・通知・課金から切り離してテスト可能にする。
@MainActor
@Observable
final class OnboardingViewModel {
    enum Mode: Sendable {
        case firstRun
        case review
    }

    let mode: Mode
    var isPaywallPresented: Bool = false
    private(set) var pendingProMode: WatchMode?

    @ObservationIgnored private let isProProvider: () -> Bool
    @ObservationIgnored private let saveMode: (WatchMode) async -> Void
    @ObservationIgnored private let requestNotifications: () async -> Void
    @ObservationIgnored private let markComplete: () async -> Void

    init(mode: Mode,
         isPro: @escaping () -> Bool,
         saveMode: @escaping (WatchMode) async -> Void,
         requestNotifications: @escaping () async -> Void,
         markComplete: @escaping () async -> Void) {
        self.mode = mode
        self.isProProvider = isPro
        self.saveMode = saveMode
        self.requestNotifications = requestNotifications
        self.markComplete = markComplete
    }

    /// ⑨開始ページでモードを選んだとき。
    /// 無料 + Pro限定モードならペイウォールを表示し、保存・完了は保留。
    func selectStartMode(_ mode: WatchMode) async {
        if mode.requiresPro && !isProProvider() {
            pendingProMode = mode
            isPaywallPresented = true
            return
        }
        await saveMode(mode)
        await markComplete()
    }

    /// ペイウォールで購入完了。保留中のProモードを確定→通知許可→完了。
    func handlePurchaseCompleted() async {
        let mode = pendingProMode ?? .solo
        await saveMode(mode)
        await requestNotifications()
        await markComplete()
        pendingProMode = nil
        isPaywallPresented = false
    }

    /// ペイウォールを購入せず閉じた。おひとりさまにフォールバックして開始。
    func handlePaywallDismissedWithoutPurchase() async {
        await saveMode(.solo)
        await markComplete()
        pendingProMode = nil
        isPaywallPresented = false
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: 上記 test コマンド
Expected: 5テストすべて PASS。

- [ ] **Step 5: コミット**

```bash
git add Hibix/Features/Onboarding/OnboardingViewModel.swift HibixTests/OnboardingTests/OnboardingViewModelTests.swift
git commit -m "feat(onboarding): モード選択/完了/ペイウォール分岐のViewModelを追加（テスト付き）"
```

---

## Task 2: OnboardingPageScaffold（共通レイアウト）

**Files:**
- Create: `Hibix/Features/Onboarding/OnboardingPageScaffold.swift`

- [ ] **Step 1: 実装**

```swift
import SwiftUI

/// オンボーディング各ページ共通レイアウト。
/// 上からイラスト→タイトル→サブ→任意の追加UI。背景はFlow側で水彩を敷く。
struct OnboardingPageScaffold<Illustration: View, Extra: View>: View {
    let title: String
    let subtitle: String
    private let illustration: Illustration
    private let extra: Extra

    init(title: String,
         subtitle: String,
         @ViewBuilder illustration: () -> Illustration,
         @ViewBuilder extra: () -> Extra = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.illustration = illustration()
        self.extra = extra()
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            illustration
                .accessibilityHidden(true)
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.hibixNavy)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.hibixSubNavy)
                    .multilineTextAlignment(.center)
            }
            extra
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: ビルド確認**

Run: 上記 build コマンド
Expected: BUILD SUCCEEDED（エラー/警告なし）。

- [ ] **Step 3: コミット**

```bash
git add Hibix/Features/Onboarding/OnboardingPageScaffold.swift
git commit -m "feat(onboarding): 共通ページレイアウト OnboardingPageScaffold を追加"
```

---

## Task 3: 9ページView＋イラスト（OnboardingPages 再編）

**Files:**
- Modify(置換): `Hibix/Features/Onboarding/OnboardingPages.swift`

文言は spec §4 を正とする。各ページは `OnboardingPageScaffold` を使用。⑨のみ操作ボタンを持つ。

- [ ] **Step 1: OnboardingPages.swift を以下で置換**

```swift
import SwiftUI

// MARK: - ① コンセプト

struct OnboardingConceptPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "気分を記録すると、\n安心がつながる",
            subtitle: "毎日の気分記録が、\nあなた自身と大切な人をそっと支えます。"
        ) {
            HStack(spacing: 14) {
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hibixSubNavy)
                PixelPreviewIllustration(filledDays: 12, columns: 4, rows: 3)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.hibixSubNavy)
            }
        }
    }
}

// MARK: - ② 気分記録

struct OnboardingMoodPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "1日1回、気分を選ぶだけ",
            subtitle: "5段階の気分から選択"
        ) {
            HStack(spacing: 14) {
                ForEach(MoodLevel.allCases, id: \.self) { level in
                    VStack(spacing: 6) {
                        Image(level.iconAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                        Text(level.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.hibixNavy)
                    }
                }
            }
        }
    }
}

// MARK: - ③ ピクセルカレンダー

struct OnboardingCalendarPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "気分の変化を見える化",
            subtitle: "毎日の記録が、\nあなただけのピクセルカレンダーになります。"
        ) {
            PixelPreviewIllustration(filledDays: 76, columns: 10, rows: 9)
        }
    }
}

// MARK: - ④ 見守りモード

struct OnboardingWatchModePage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "あなたに合った見守り方",
            subtitle: "3つのモードから選べます"
        ) {
            EmptyView()
        } extra: {
            VStack(spacing: 10) {
                ModeInfoCard(title: "おひとりさま", detail: "自分のために記録", isPro: false)
                ModeInfoCard(title: "ゆるつながり", detail: "必要なときだけ通知", isPro: true)
                ModeInfoCard(title: "まいにち共有", detail: "家族と毎日共有", isPro: true)
            }
        }
    }
}

// MARK: - ⑤ 安否通知

struct OnboardingSafetyPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "もしもの時だけ知らせる",
            subtitle: "一定期間記録がない場合、\n登録した連絡先へ通知します。"
        ) {
            VStack(spacing: 8) {
                WatchFlowStep(text: "記録なし")
                Image(systemName: "arrow.down").foregroundStyle(Color.hibixPeriwinkle)
                WatchFlowStep(text: "7日経過")
                Image(systemName: "arrow.down").foregroundStyle(Color.hibixPeriwinkle)
                WatchFlowStep(text: "メール通知", systemImage: "envelope.fill")
            }
        } extra: {
            Text("※日数は設定で変更できます")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(Color.hibixSubText)
        }
    }
}

// MARK: - ⑥ プライバシー

struct OnboardingPrivacyPage: View {
    private static let points = ["端末内保存", "外部共有なし", "データ削除可能"]
    var body: some View {
        OnboardingPageScaffold(
            title: "データはあなたのもの",
            subtitle: "記録は端末内に保存。\n第三者へ共有されません。"
        ) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.hibixSubNavy)
        } extra: {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Self.points, id: \.self) { point in
                    Label(point, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hibixNavy)
                }
            }
        }
    }
}

// MARK: - ⑦ アプリロック

struct OnboardingAppLockPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "気分記録を守る",
            subtitle: "Face IDやパスコードで保護できます。"
        ) {
            VStack(spacing: 12) {
                Image(systemName: "faceid")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.hibixSubNavy)
                Text("● ● ● ●")
                    .font(.title3)
                    .foregroundStyle(Color.hibixPeriwinkle)
            }
            .frame(width: 150, height: 180)
            .hibixGlassCard(cornerRadius: 24)
        }
    }
}

// MARK: - ⑧ Pro

struct OnboardingProPage: View {
    var body: some View {
        OnboardingPageScaffold(
            title: "買い切りで、ずっと使える",
            subtitle: "サブスクなし。\n一度の購入で全機能を解放。"
        ) {
            EmptyView()
        } extra: {
            VStack(spacing: 14) {
                ProCompareTable()
                Text("¥2,800")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Color.hibixNavy)
                + Text("  買い切り")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.hibixSubText)
            }
        }
    }
}

// MARK: - ⑨ 開始

struct OnboardingStartPage: View {
    let onSelectMode: (WatchMode) -> Void

    var body: some View {
        OnboardingPageScaffold(
            title: "今日から始めよう",
            subtitle: "あなたに合った見守りモードを選択"
        ) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Color.hibixSubNavy)
        } extra: {
            VStack(spacing: 12) {
                ForEach(WatchMode.allCases) { mode in
                    Button {
                        onSelectMode(mode)
                    } label: {
                        HStack(spacing: 8) {
                            Text(mode.displayName)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.hibixNavy)
                            if mode.requiresPro {
                                Text("Pro")
                                    .font(.caption2)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(Color.hibixAccentPink)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .hibixRoundButton(cornerRadius: 25)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode.requiresPro ? "\(mode.displayName)、Pro" : mode.displayName)
                }
            }
        }
    }
}

// MARK: - Illustrations / parts

/// 角丸タイルのピクセルカレンダー風プレビュー（非操作）。
struct PixelPreviewIllustration: View {
    let filledDays: Int
    let columns: Int
    let rows: Int

    private var palette: [Color] { MoodLevel.allCases.map { Color.moodColor(for: $0) } }

    var body: some View {
        let cell: CGFloat = columns >= 10 ? 12 : 22
        VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        let filled = (index * 7 + 3) % 11 < 8 && index < filledDays
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(filled ? palette[(index * 3) % palette.count] : Color.hibixCellBase.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .strokeBorder(Color.hibixCellBorder, lineWidth: 1)
                            )
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }
}

private struct ModeInfoCard: View {
    let title: String
    let detail: String
    let isPro: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.hibixNavy)
                    if isPro {
                        Text("Pro")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundStyle(Color.hibixAccentPink)
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.hibixSubText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .hibixGlassCard(cornerRadius: 18)
    }
}

private struct WatchFlowStep: View {
    let text: String
    var systemImage: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).foregroundStyle(Color.hibixAccentPink)
            }
            Text(text)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.hibixNavy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .hibixGlassCard(cornerRadius: 14)
    }
}

private struct ProCompareTable: View {
    private struct Row: Identifiable { let id = UUID(); let label: String; let free: String; let pro: String }
    private let rows = [
        Row(label: "基本記録", free: "✓", pro: "✓"),
        Row(label: "見守り", free: "一部", pro: "全解放"),
        Row(label: "高度な管理", free: "−", pro: "✓")
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("").frame(maxWidth: .infinity, alignment: .leading)
                Text("無料").frame(width: 64)
                Text("Pro").frame(width: 64)
            }
            .font(.caption).fontWeight(.heavy).foregroundStyle(Color.hibixSubNavy)
            .padding(.vertical, 6)
            ForEach(rows) { row in
                Divider().overlay(Color.hibixHairline)
                HStack {
                    Text(row.label).frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.free).frame(width: 64)
                    Text(row.pro).frame(width: 64)
                }
                .font(.caption).fontWeight(.medium).foregroundStyle(Color.hibixNavy)
                .padding(.vertical, 7)
            }
        }
        .padding(.horizontal, 14)
        .hibixGlassCard(cornerRadius: 18)
    }
}
```

- [ ] **Step 2: ビルド確認**

Run: build コマンド
Expected: BUILD SUCCEEDED。（この時点で旧 `OnboardingConceptPage`/`OnboardingWatchPage`/`OnboardingPermissionPage` は置換済み。Task4 で参照を更新するため、まだ `OnboardingFlow` がコンパイルエラーになる場合は Task4 とまとめてビルドして良い。）

- [ ] **Step 3: コミット**

```bash
git add Hibix/Features/Onboarding/OnboardingPages.swift
git commit -m "feat(onboarding): 9ページのページView群とイラストを実装"
```

---

## Task 4: OnboardingFlow を9ページ＋Mode＋ペイウォール対応に刷新

**Files:**
- Modify(置換): `Hibix/Features/Onboarding/OnboardingFlow.swift`

- [ ] **Step 1: OnboardingFlow.swift を以下で置換**

```swift
import SwiftUI
import os.log

struct OnboardingFlow: View {
    let dependencies: AppDependencies
    let mode: OnboardingViewModel.Mode
    let onCompleted: () -> Void
    let onClose: () -> Void

    @State private var viewModel: OnboardingViewModel
    @State private var pageIndex: Int = 0

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Onboarding")
    /// firstRun=9ページ(0..8) / review=8ページ(0..7、開始ページ⑨を除外)
    private var pageCount: Int { mode == .review ? 8 : 9 }
    private var isLastPage: Bool { pageIndex == pageCount - 1 }

    init(dependencies: AppDependencies,
         mode: OnboardingViewModel.Mode = .firstRun,
         onCompleted: @escaping () -> Void = {},
         onClose: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.mode = mode
        self.onCompleted = onCompleted
        self.onClose = onClose

        let settings = dependencies.settingsRepository
        let entitlement = dependencies.entitlementManager
        let scheduler = dependencies.notificationScheduler
        let complete = onCompleted
        _viewModel = State(initialValue: OnboardingViewModel(
            mode: mode,
            isPro: { entitlement.isPro },
            saveMode: { selected in
                do {
                    try await settings.setString(selected.rawValue, forKey: .watchMode, now: Date())
                } catch {
                    OnboardingFlow.logger.error("watch_mode write failed: \(error.localizedDescription, privacy: .public)")
                }
            },
            requestNotifications: {
                let granted = await scheduler.requestAuthorization()
                if granted { await scheduler.rescheduleDailyNotifications() }
            },
            markComplete: {
                do {
                    try await settings.setBool(true, forKey: .onboardingDone, now: Date())
                } catch {
                    OnboardingFlow.logger.error("onboarding_done write failed: \(error.localizedDescription, privacy: .public)")
                }
                complete()
            }
        ))
    }

    var body: some View {
        @Bindable var bindable = viewModel
        VStack(spacing: 16) {
            if mode == .review {
                HStack {
                    Spacer()
                    Button("閉じる") { onClose() }
                        .fontWeight(.semibold)
                        .tint(Color.hibixNavy)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
            }

            TabView(selection: $pageIndex) {
                OnboardingConceptPage().tag(0)
                OnboardingMoodPage().tag(1)
                OnboardingCalendarPage().tag(2)
                OnboardingWatchModePage().tag(3)
                OnboardingSafetyPage().tag(4)
                OnboardingPrivacyPage().tag(5)
                OnboardingAppLockPage().tag(6)
                OnboardingProPage().tag(7)
                if mode != .review {
                    OnboardingStartPage(onSelectMode: { selected in
                        Task { await viewModel.selectStartMode(selected) }
                    })
                    .tag(8)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: pageIndex)

            pagination

            if !isLastPage {
                Button(action: advance) {
                    Text("次へ")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hibixNavy)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .hibixRoundButton(cornerRadius: 25)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hibixWatercolorBackground()
        .sheet(isPresented: $bindable.isPaywallPresented) {
            PaywallView(
                viewModel: PaywallViewModel(entitlement: dependencies.entitlementManager),
                onPurchaseCompleted: {
                    Task { await viewModel.handlePurchaseCompleted() }
                },
                onDismiss: {
                    Task { await viewModel.handlePaywallDismissedWithoutPurchase() }
                }
            )
        }
    }

    private var pagination: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? Color.hibixNavy : Color.hibixPeriwinkle.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private func advance() {
        guard pageIndex < pageCount - 1 else { return }
        pageIndex += 1
    }
}
```

- [ ] **Step 2: ビルド確認**

Run: build コマンド
Expected: BUILD SUCCEEDED。（RootView の呼び出しが新シグネチャと不整合ならエラー → Task5 で解消。まとめてビルド可。）

- [ ] **Step 3: コミット**

```bash
git add Hibix/Features/Onboarding/OnboardingFlow.swift
git commit -m "feat(onboarding): 9ページTabView化・Mode対応・ペイウォール連携に刷新"
```

---

## Task 5: RootView の呼び出し更新

**Files:**
- Modify: `Hibix/App/RootView.swift`（`OnboardingFlow(dependencies:)` 呼び出し箇所、§9で確認した RootView.swift:13-15 付近）

- [ ] **Step 1: 呼び出しを置換**

変更前:
```swift
case .some(false):
    OnboardingFlow(dependencies: dependencies) {
        dependencies.markOnboardingDone()
    }
```
変更後:
```swift
case .some(false):
    OnboardingFlow(dependencies: dependencies, mode: .firstRun, onCompleted: {
        dependencies.markOnboardingDone()
    })
```

- [ ] **Step 2: ビルド確認**

Run: build コマンド
Expected: BUILD SUCCEEDED（エラー/警告なし）。

- [ ] **Step 3: コミット**

```bash
git add Hibix/App/RootView.swift
git commit -m "chore(onboarding): RootViewからmode指定でOnboardingFlowを起動"
```

---

## Task 6: 設定に「使い方をもう一度見る」再閲覧導線を追加

**Files:**
- Modify: `Hibix/Features/Settings/SettingsView.swift`（`List` に `helpSection` を追加。場所は accountSection の直下）

- [ ] **Step 1: 再閲覧シート用の state を追加**

`SettingsView` の他の `@State`（例: `@State private var ...`）の並びに追加:
```swift
@State private var isHelpPresented: Bool = false
```

- [ ] **Step 2: `List` 内に helpSection を追加**

`List { accountSection` の直後（accountSection の次の行）に:
```swift
            helpSection
```
を挿入する（`appearanceSection` より前）。

- [ ] **Step 3: helpSection を実装**

`SettingsView` 内（他の `private var xxxSection: some View` と並べて）に追加:
```swift
    private var helpSection: some View {
        Section {
            Button {
                isHelpPresented = true
            } label: {
                Label("使い方をもう一度見る", systemImage: "questionmark.circle")
            }
            .accessibilityHint("オンボーディングを最初から見直します")
        }
    }
```

- [ ] **Step 4: 再閲覧シートを追加**

`SettingsView` の `body` 内、`NavigationStack { List { ... } ... }` の修飾子として（既存の `.navigationTitle("設定")` の近く、List への修飾子チェーンに）追加:
```swift
        .sheet(isPresented: $isHelpPresented) {
            OnboardingFlow(dependencies: dependencies, mode: .review, onClose: {
                isHelpPresented = false
            })
        }
```

- [ ] **Step 5: ビルド確認**

Run: build コマンド
Expected: BUILD SUCCEEDED（エラー/警告なし）。

- [ ] **Step 6: コミット**

```bash
git add Hibix/Features/Settings/SettingsView.swift
git commit -m "feat(onboarding): 設定に『使い方をもう一度見る』再閲覧導線を追加"
```

---

## Task 7: 全テスト＋手動検証＋仕上げ

**Files:** なし（検証のみ）

- [ ] **Step 1: ユニットテスト全実行**

Run:
```
xcodebuild test -scheme Hibix -destination 'platform=iOS Simulator,id=747A07A5-537B-4CD5-9628-3B433A43621F' -only-testing:HibixTests/OnboardingViewModelTests -quiet
```
Expected: 5テスト PASS。

- [ ] **Step 2: フルビルド（警告ゼロ確認）**

Run: build コマンド
Expected: BUILD SUCCEEDED、`grep -E "error:|warning:"` で該当なし。

- [ ] **Step 3: 手動検証（Simulator）**

確認項目:
- 初回起動で9ページをスワイプ。各ページの文言/イラストが spec §4 と一致。
- ライト/ダーク両モードで水彩テーマが追従（端末ライト＋アプリ内ダーク含む）。
- ⑨「おひとりさま」→ 即ホーム遷移、watch_mode=solo 保存。
- ⑨「ゆるつながり/まいにち共有」（無料時）→ ペイウォール表示。購入完了→そのモード保存＋通知許可ダイアログ→ホーム。キャンセル→おひとりさまでホーム。
- 設定→「使い方をもう一度見る」→ ①〜⑧のみ表示・⑨非表示・「閉じる」で戻る・副作用（完了/保存/許可）が起きない。
- VoiceOver で各ページ・⑨ボタンが読み上げられる。

- [ ] **Step 4: 仕上げコミット（必要時）**

```bash
git add -A
git commit -m "test(onboarding): 検証完了（9ページ/再閲覧/ペイウォール分岐）"
```

---

## 完了条件
- OnboardingViewModel テスト5本 PASS。
- フルビルド エラー/警告ゼロ。
- 手動検証の全項目OK（ライト/ダーク、⑨分岐、再閲覧の副作用なし）。
- 据え置き対象（気分カラー§6・PNG・既存課金/通知/モードロジック）に変更なし。
