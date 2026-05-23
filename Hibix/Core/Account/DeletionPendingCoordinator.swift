import Foundation
import Observation
import os.log

/// PRD v2.2.0 §8.5 / §8.10 — 削除リクエスト進行中の取消 UX を統括する。
///
/// 各 mutating Service が `APIError.isDeletionPending` を捕捉した際に
/// `report(_:)` を呼ぶと、UI 階層（RootView）上にキャンセル誘導モーダルが表示される。
///
/// ユーザーが「取り消す」を選んだら `confirmCancel()` が呼ばれ、サーバーに
/// `POST /api/account/cancel-deletion` を投げて 200 を受ければモーダルを閉じる。
@MainActor
@Observable
final class DeletionPendingCoordinator {
    struct Pending: Equatable, Sendable {
        let scheduledDeletionBy: Date?
        let message: String
    }

    enum CancelState: Equatable, Sendable {
        case idle
        case cancelling
        case failed(String)
    }

    /// 表示中の 409 通知。`nil` ならモーダル非表示。
    private(set) var pending: Pending?
    private(set) var cancelState: CancelState = .idle

    private weak var deletionService: AccountDeletionService?
    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "DeletionPending")

    func attach(deletionService: AccountDeletionService) {
        self.deletionService = deletionService
    }

    /// mutating API が 409 を受けた時にサービスから呼ぶ。
    /// 既に表示中の場合はスケジュール日時を上書きする（古い情報を新しい情報に置換）。
    func report(_ error: APIError) {
        guard error.isDeletionPending else { return }
        let scheduled: Date?
        let message: String
        if case .server(_, _, let serverMessage, let by) = error {
            scheduled = by
            message = serverMessage
        } else {
            scheduled = nil
            message = "削除リクエストが進行中です。続けるには取り消してください。"
        }
        pending = Pending(scheduledDeletionBy: scheduled, message: message)
        cancelState = .idle
        Self.logger.notice("DELETION_PENDING surfaced (scheduled=\(scheduled?.description ?? "nil", privacy: .public))")
    }

    /// モーダルから「取り消す」ボタンが押された時に呼ぶ。
    func confirmCancel() async {
        guard let deletionService else {
            cancelState = .failed("内部エラー: 削除サービスが利用できません")
            return
        }
        cancelState = .cancelling
        do {
            _ = try await deletionService.cancelDeletion()
            pending = nil
            cancelState = .idle
            Self.logger.info("Deletion cancelled by user")
        } catch let error as APIError {
            if error.errorCode == .noPendingDeletion {
                // すでに物理削除済み or サーバー側に削除リクエストが残っていない
                pending = nil
                cancelState = .idle
                Self.logger.notice("No pending deletion on server; dismissing modal")
            } else {
                cancelState = .failed(error.errorDescription ?? "取り消しに失敗しました")
                Self.logger.error("Cancel deletion failed: \(error.localizedDescription, privacy: .public)")
            }
        } catch {
            cancelState = .failed(error.localizedDescription)
            Self.logger.error("Cancel deletion failed (unknown): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// モーダルを閉じる（ユーザーが「あとで」を選んだ場合など）。
    /// 取り消しが完了していなくても閉じられるが、次の mutating で再表示される。
    func dismiss() {
        pending = nil
        cancelState = .idle
    }
}
