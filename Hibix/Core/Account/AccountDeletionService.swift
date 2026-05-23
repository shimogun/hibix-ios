import Foundation
import UserNotifications
import os.log

/// PRD v2.2.0 §6 F-11 / §8.5 / §8.10 / §10.4 — データ削除権の実装。
///
/// **挙動**:
/// - `requestDeletion()`: `DELETE /api/account` を叩き、サーバー側論理削除リクエスト ID と
///   `scheduled_deletion_by` を受け取る。冪等（既存リクエストがあればそれを返す）。
/// - `purgeLocalData()`: GRDB の DB ファイル / Keychain / App Attest 鍵 / 通知 / UserDefaults を完全消去する。
/// - `cancelDeletion()`: 48h 経過前の削除取り消し。
///
/// **呼び出し順序**: `requestDeletion` → `purgeLocalData` → アプリ再起動 (RootView を再生成)。
/// サーバーへの DELETE が失敗してもローカルは消去する（ユーザーの削除権を優先）。
@MainActor
protocol AccountDeletionServicing: AnyObject {
    func requestDeletion() async throws -> AccountDeleteResponse
    func cancelDeletion() async throws -> CancelDeletionResponse
    func purgeLocalData() async
}

@MainActor
final class AccountDeletionService: AccountDeletionServicing {

    private let apiClient: APIClient
    private let databaseURL: URL
    private weak var database: DatabaseManager?
    private let keychain: KeychainStore
    private let attestKeyStore: AppAttestKeyStore
    private let notificationScheduler: NotificationScheduler

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "AccountDeletion")

    init(apiClient: APIClient,
         database: DatabaseManager,
         databaseURL: URL,
         keychain: KeychainStore,
         attestKeyStore: AppAttestKeyStore,
         notificationScheduler: NotificationScheduler) {
        self.apiClient = apiClient
        self.database = database
        self.databaseURL = databaseURL
        self.keychain = keychain
        self.attestKeyStore = attestKeyStore
        self.notificationScheduler = notificationScheduler
    }

    /// サーバーに削除リクエストを投げる（冪等）。
    /// - Throws: `APIError` — 呼び出し側で 409 や接続不能を判定可能。
    func requestDeletion() async throws -> AccountDeleteResponse {
        try await apiClient.request(.account)
    }

    /// 48h 経過前のサーバー削除リクエストを取り消す。
    func cancelDeletion() async throws -> CancelDeletionResponse {
        try await apiClient.request(.cancelDeletion)
    }

    /// ローカル端末上の全データを消す。エラーは個別ログするが基本的に握りつぶし、
    /// 「消せるところは全て消す」を優先する（部分消去で残骸が残る方が悪い）。
    ///
    /// - Note: 呼び出し後の `database` / `keychain` への参照は破棄前提。アプリの再起動が必要。
    func purgeLocalData() async {
        notificationScheduler.cancelDailyNotifications()
        clearPendingNotifications()

        await database?.close()

        do {
            try removeDatabaseFiles()
        } catch {
            Self.logger.error("Remove DB files failed: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try keychain.reset()
        } catch {
            Self.logger.error("Keychain reset failed: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try attestKeyStore.reset()
        } catch {
            Self.logger.error("App Attest keystore reset failed: \(error.localizedDescription, privacy: .public)")
        }

        clearUserDefaults()
    }

    // MARK: - Private


    private func clearPendingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    private func removeDatabaseFiles() throws {
        let fm = FileManager.default
        let candidates: [URL] = [
            databaseURL,
            databaseURL.appendingPathExtension("wal"),
            databaseURL.appendingPathExtension("shm"),
            databaseURL.deletingPathExtension().appendingPathExtension("sqlite-wal"),
            databaseURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        ]
        for url in candidates where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    private func clearUserDefaults() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundleId)
        UserDefaults.standard.synchronize()
    }
}
