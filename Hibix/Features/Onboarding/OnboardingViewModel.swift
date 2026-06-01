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
