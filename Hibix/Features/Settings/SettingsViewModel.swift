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
    private(set) var appLockEnabled: Bool = false
    private(set) var restoreState: RestoreState = .idle

    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let entitlement: EntitlementProviding
    /// 購入履歴を App Store と強制同期する処理（既定は `AppStore.sync()`）。
    /// テストで sync の throw を再現するため注入可能にしている。
    @ObservationIgnored private let syncAppStore: @Sendable () async throws -> Void

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Settings")

    init(settings: SettingsRepository,
         entitlement: EntitlementProviding,
         syncAppStore: @escaping @Sendable () async throws -> Void = { try await AppStore.sync() }) {
        self.settings = settings
        self.entitlement = entitlement
        self.syncAppStore = syncAppStore
    }

    func load() async {
        do {
            if let raw = try await settings.string(forKey: .watchMode) {
                watchMode = raw
            }
            appLockEnabled = try await settings.bool(forKey: .appLockEnabled)
        } catch {
            Self.logger.error("Settings load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func restorePurchases() async {
        restoreState = .restoring

        // `AppStore.sync()` は App Store と購入履歴を強制同期するが、購入自体は
        // sync 無しでも `Transaction.currentEntitlements` から読める。Sandbox では
        // sync が良性理由で throw することがあるため、throw を復元失敗とはみなさず、
        // 最終判定は必ず `entitlement.refresh()`（＝currentEntitlements）に委ねる。
        var syncFailed = false
        do {
            try await syncAppStore()
        } catch {
            // 認証シートをユーザーが閉じた場合はエラー表示せず静かに戻す（.userCancelled 規約）。
            if let skError = error as? StoreKitError, case .userCancelled = skError {
                Self.logger.info("Restore cancelled by user during AppStore.sync")
                restoreState = .idle
                return
            }
            syncFailed = true
            Self.logger.error("AppStore.sync failed during restore (falling back to currentEntitlements): \(error.localizedDescription, privacy: .public)")
        }

        await entitlement.refresh()
        if await entitlement.isPro {
            // sync が throw しても currentEntitlements に購入があれば復元成功。
            restoreState = .completed
        } else if syncFailed {
            // 同期失敗かつ購入未検出のときだけ本当の失敗として再試行を促す。
            restoreState = .failed(message: "復元に失敗しました。時間を置いて再度お試しください")
        } else {
            // 同期成功・購入なし＝購入履歴が無い（エラーではない・F-14）。
            restoreState = .failed(message: "購入履歴がありません")
        }
    }
}
