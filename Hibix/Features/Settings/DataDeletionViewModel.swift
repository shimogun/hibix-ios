import Foundation
import Observation
import os.log

/// PRD v2.2.0 §6 F-11 — データ削除権の UI 状態管理。
///
/// **フロー**:
/// 1. `idle` → ユーザーが「データを削除」ボタンタップ → `confirming`
/// 2. `confirming` → 警告ダイアログで確定 → `deleting`
/// 3. `deleting` → サーバー DELETE → ローカル purge → `completed`(リブート)
///
/// サーバー DELETE が失敗してもローカル削除は実行する（ユーザーの削除権を優先）。
@MainActor
@Observable
final class DataDeletionViewModel {
    enum State: Equatable {
        case idle
        case confirming
        case deleting
        case completed
        case failed(String)
    }

    private(set) var state: State = .idle

    @ObservationIgnored private let service: any AccountDeletionServicing

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "DataDeletion")

    init(service: any AccountDeletionServicing) {
        self.service = service
    }

    var isBusy: Bool {
        if case .deleting = state { return true }
        return false
    }

    var isCompleted: Bool {
        if case .completed = state { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let message) = state { return message }
        return nil
    }

    /// 「データを削除」ボタンタップ。
    func presentConfirmation() {
        guard state == .idle || state == .failed("") || failureMessage != nil else { return }
        state = .confirming
    }

    /// 警告ダイアログのキャンセル。
    func dismissConfirmation() {
        if state == .confirming { state = .idle }
    }

    /// 警告ダイアログの「削除する」確定。完了したら `onComplete` を呼んでアプリを再起動する。
    /// - Parameter onComplete: ローカル削除完了後にアプリ全体を再生成するコールバック。
    func confirmDeletion(onComplete: @escaping @MainActor () -> Void) async {
        state = .deleting

        // サーバーに削除リクエストを投げる。失敗してもローカル消去は続行する。
        var serverFailure: APIError?
        do {
            let response = try await service.requestDeletion()
            Self.logger.info("Deletion requested: id=\(response.deletion_request_id, privacy: .public)")
        } catch let error as APIError {
            serverFailure = error
            Self.logger.notice("Server deletion request failed; continuing local purge: \(error.localizedDescription, privacy: .public)")
        } catch {
            Self.logger.notice("Server deletion request failed (unknown); continuing local purge: \(error.localizedDescription, privacy: .public)")
        }

        await service.purgeLocalData()
        state = .completed

        if let serverFailure {
            Self.logger.notice("Local purge completed with server failure: \(serverFailure.localizedDescription, privacy: .public)")
        } else {
            Self.logger.info("Local purge completed")
        }

        // SwiftUI ルートを破棄して新しい AppDependencies を起動。
        // 呼び出し後に self へアクセスしない。
        onComplete()
    }
}
