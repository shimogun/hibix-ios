import Foundation
import LocalAuthentication
import Observation
import os.log

/// PRD v2.2.0 §6 F-08 アプリロック。Face ID / Touch ID / 端末パスコードによる起動時認証。
///
/// - 有効化: `setEnabled(true)` で `LAContext.evaluatePolicy` を 1 回成功させてから永続化
/// - 起動時: `warmUp()` で設定読込 → 有効ならロック状態(`isLocked=true`)で初期化 + 認証起動
/// - BG → FG 遷移: `onEnterBackground()` でロック、`requestAuthenticationIfNeeded()` で再認証
/// - ロック中は RootView が `isLocked` を見てブラーオーバーレイで内容を隠す
@MainActor
@Observable
final class AppLockManager {
    private(set) var isLockEnabled: Bool = false
    /// ロック中(コンテンツを隠すべき状態)
    private(set) var isLocked: Bool = false
    private(set) var lastErrorMessage: String?

    @ObservationIgnored private let settings: SettingsRepository

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "AppLock")

    init(settings: SettingsRepository) {
        self.settings = settings
    }

    /// アプリ起動時に呼ぶ。設定読込 + ロックが有効なら認証起動。
    func warmUp() async {
        do {
            isLockEnabled = try await settings.bool(forKey: .appLockEnabled)
        } catch {
            Self.logger.error("Load app_lock_enabled failed: \(error.localizedDescription, privacy: .public)")
        }
        if isLockEnabled {
            isLocked = true
            _ = await authenticate()
        } else {
            isLocked = false
        }
    }

    /// 設定画面のトグルから呼ぶ。`true` 時は LAContext で認証を取って初めて永続化する。
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let ok = await runAuthentication(reason: "Hibix のアプリロックを有効にします")
            guard ok else { return false }
            do {
                try await settings.setBool(true, forKey: .appLockEnabled, now: Date())
                isLockEnabled = true
                isLocked = false
                lastErrorMessage = nil
                return true
            } catch {
                Self.logger.error("Persist app_lock_enabled failed: \(error.localizedDescription, privacy: .public)")
                lastErrorMessage = "設定の保存に失敗しました"
                return false
            }
        } else {
            do {
                try await settings.setBool(false, forKey: .appLockEnabled, now: Date())
                isLockEnabled = false
                isLocked = false
                lastErrorMessage = nil
                return true
            } catch {
                Self.logger.error("Persist app_lock_enabled failed: \(error.localizedDescription, privacy: .public)")
                lastErrorMessage = "設定の保存に失敗しました"
                return false
            }
        }
    }

    /// 「もう一度」ボタン or 復帰時の再認証。成功で `isLocked=false`。
    @discardableResult
    func authenticate() async -> Bool {
        guard isLockEnabled else {
            isLocked = false
            return true
        }
        let ok = await runAuthentication(reason: "Hibix を開きます")
        if ok {
            isLocked = false
            lastErrorMessage = nil
        }
        return ok
    }

    /// BG 遷移時。有効化されていればロックする。
    func onEnterBackground() {
        if isLockEnabled {
            isLocked = true
        }
    }

    /// Pro 解約等で AppLock を強制的に無効化したい場合(将来用)。
    func forceDisable() async {
        do {
            try await settings.setBool(false, forKey: .appLockEnabled, now: Date())
        } catch {
            Self.logger.error("Force disable persist failed: \(error.localizedDescription, privacy: .public)")
        }
        isLockEnabled = false
        isLocked = false
    }

    // MARK: - Private

    private func runAuthentication(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "パスコードを使用"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            Self.logger.error("Cannot evaluate policy: \(policyError?.localizedDescription ?? "unknown", privacy: .public)")
            lastErrorMessage = "この端末では認証が利用できません(端末パスコードを設定してください)"
            return false
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if !success {
                lastErrorMessage = "認証に失敗しました"
            }
            return success
        } catch {
            Self.logger.error("evaluatePolicy failed: \(error.localizedDescription, privacy: .public)")
            lastErrorMessage = "認証に失敗しました"
            return false
        }
    }
}
