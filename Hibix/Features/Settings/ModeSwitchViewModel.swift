import Foundation
import Observation
import os.log

/// PRD v2.2.0 §6 F-06 見守りモード切替。
///
/// - 無料: `solo` のみ実選択可能。それ以外を選ぼうとすると Paywall を表示。
/// - 有料: 3 モード自由切替。`daily` は v0.1 では `gentle` と同じ挙動(注記表示)。
/// - 永続化はローカル DB のみ。サーバー連携 (PATCH /api/settings) は STEP7。
@MainActor
@Observable
final class ModeSwitchViewModel {
    private(set) var selectedMode: WatchMode = .solo
    var isPaywallPresented: Bool = false

    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let entitlement: EntitlementManager

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "ModeSwitch")

    init(settings: SettingsRepository, entitlement: EntitlementManager) {
        self.settings = settings
        self.entitlement = entitlement
    }

    func load() async {
        do {
            if let raw = try await settings.string(forKey: .watchMode),
               let mode = WatchMode(rawValue: raw) {
                selectedMode = mode
            }
        } catch {
            Self.logger.error("Load watch_mode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 選択を試みる。無料 + 非 `solo` 選択 → Paywall 起動。保存は成功時のみ。
    func select(_ mode: WatchMode) async {
        if !entitlement.isPro && mode.requiresPro {
            isPaywallPresented = true
            return
        }
        guard mode != selectedMode else { return }
        selectedMode = mode
        do {
            try await settings.setString(mode.rawValue, forKey: .watchMode, now: Date())
        } catch {
            Self.logger.error("Persist watch_mode failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
