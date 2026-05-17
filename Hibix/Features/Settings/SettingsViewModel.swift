import Foundation
import Observation
import StoreKit
import os.log

/// PRD v2.2.0 §6 F-06/F-07/F-08/F-14 を束ねる設定画面の状態。
/// STEP6.1 ではフレーム表示と「購入を復元」(F-14)のみ実装。
/// 各編集画面 (Mode/Contacts/AppLock) は STEP6.2-6.4 で接続。
@MainActor
@Observable
final class SettingsViewModel {
    enum RestoreState: Equatable {
        case idle
        case restoring
        case completed
        case failed(message: String)
    }

    private(set) var watchMode: String = "solo"
    private(set) var emergencyContactsCount: Int = 0
    private(set) var appLockEnabled: Bool = false
    private(set) var restoreState: RestoreState = .idle

    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let contacts: EmergencyContactsRepository
    @ObservationIgnored private let entitlement: EntitlementManager

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Settings")

    init(settings: SettingsRepository,
         contacts: EmergencyContactsRepository,
         entitlement: EntitlementManager) {
        self.settings = settings
        self.contacts = contacts
        self.entitlement = entitlement
    }

    func load() async {
        do {
            if let raw = try await settings.string(forKey: .watchMode) {
                watchMode = raw
            }
            appLockEnabled = try await settings.bool(forKey: .appLockEnabled)
            emergencyContactsCount = try await contacts.count()
        } catch {
            Self.logger.error("Settings load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func restorePurchases() async {
        restoreState = .restoring
        do {
            try await AppStore.sync()
            await entitlement.refresh()
            if entitlement.isPro {
                restoreState = .completed
            } else {
                restoreState = .failed(message: "購入履歴がありません")
            }
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            restoreState = .failed(message: "復元に失敗しました。時間を置いて再度お試しください")
        }
    }
}
