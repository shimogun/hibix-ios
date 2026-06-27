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
    /// 記録なし日数しきい値の許容範囲 (PRD v2.2.0 §6 F-06)。
    static let watchDaysRange = 1...7
    static let defaultWatchDays = 2

    private(set) var selectedMode: WatchMode = .solo
    private(set) var watchDays: Int = ModeSwitchViewModel.defaultWatchDays
    var isPaywallPresented: Bool = false
    /// gentle/daily 切替に email 連絡先が不足しているとき true（先回りバリデーション）。
    var requiresEmailContactAlert: Bool = false

    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let entitlement: EntitlementManager
    @ObservationIgnored private let contacts: EmergencyContactsRepository
    @ObservationIgnored private let contactsSync: ContactsSyncService

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "ModeSwitch")

    init(settings: SettingsRepository,
         entitlement: EntitlementManager,
         contacts: EmergencyContactsRepository,
         contactsSync: ContactsSyncService) {
        self.settings = settings
        self.entitlement = entitlement
        self.contacts = contacts
        self.contactsSync = contactsSync
    }

    /// `solo` は見守り通知が発生しないため、日数/緊急連絡先の設定は無効。
    var canEditWatchSettings: Bool {
        selectedMode != .solo
    }

    func load() async {
        do {
            if let raw = try await settings.string(forKey: .watchMode),
               let mode = WatchMode(rawValue: raw) {
                selectedMode = mode
            }
            if let raw = try await settings.string(forKey: .watchDays),
               let days = Int(raw) {
                watchDays = Self.clampWatchDays(days)
            }
        } catch {
            Self.logger.error("Load watch settings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 日数しきい値を 1...7 にクランプして保存。
    func setWatchDays(_ days: Int) async {
        let clamped = Self.clampWatchDays(days)
        guard clamped != watchDays else { return }
        watchDays = clamped
        do {
            try await settings.setString(String(clamped), forKey: .watchDays, now: Date())
        } catch {
            Self.logger.error("Persist watch_days failed: \(error.localizedDescription, privacy: .public)")
        }
        try? await contactsSync.syncSettings(watchMode: selectedMode.rawValue, watchDays: clamped)
    }

    private static func clampWatchDays(_ days: Int) -> Int {
        min(max(days, watchDaysRange.lowerBound), watchDaysRange.upperBound)
    }

    /// 選択を試みる。無料 + 非 `solo` 選択 → Paywall 起動。保存は成功時のみ。
    /// gentle/daily は email 連絡先が最低1件必要（サーバー M-01 を UX で先回り）。
    func select(_ mode: WatchMode) async {
        if !entitlement.isPro && mode.requiresPro {
            isPaywallPresented = true
            return
        }
        guard mode != selectedMode else { return }

        if mode.isNotifying {
            let emailCount = (try? await contacts.list())?.filter { $0.contactType == .email }.count ?? 0
            if emailCount == 0 {
                requiresEmailContactAlert = true
                return
            }
        }

        let previous = selectedMode
        selectedMode = mode
        do {
            try await settings.setString(mode.rawValue, forKey: .watchMode, now: Date())
        } catch {
            Self.logger.error("Persist watch_mode failed: \(error.localizedDescription, privacy: .public)")
            selectedMode = previous
            return
        }

        // サーバーへ反映。競合等で EMAIL_CONTACT_REQUIRED が返ったらローカルを戻す。
        if mode.isNotifying {
            do {
                try await contactsSync.syncSettings(watchMode: mode.rawValue, watchDays: watchDays)
            } catch let APIError.server(_, code, _, _) where code == .emailContactRequired {
                selectedMode = previous
                try? await settings.setString(previous.rawValue, forKey: .watchMode, now: Date())
                requiresEmailContactAlert = true
            } catch {
                Self.logger.error("syncSettings failed: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            try? await contactsSync.syncSettings(watchMode: mode.rawValue, watchDays: watchDays)
        }
    }
}
