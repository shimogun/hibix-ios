import Foundation
import StoreKit
import os.log

/// 購入完了時に `POST /api/storekit/verify` を呼んでサーバー側 `is_pro` を確定する。
///
/// PRD v2.2.0 §8.9 / C-01:
/// - 失敗してもユーザー UX は阻害しない(ローカル StoreKit が真実)
/// - App Attest 非対応(シミュレータ等)では呼ばずにサイレントスキップ
@MainActor
final class StoreKitVerifyService {
    @ObservationIgnored private let apiClient: APIClient
    @ObservationIgnored private let attest: AppAttestClient
    @ObservationIgnored private weak var deletionPending: DeletionPendingCoordinator?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "StoreKitVerify")

    init(apiClient: APIClient,
         attest: AppAttestClient,
         deletionPending: DeletionPendingCoordinator? = nil) {
        self.apiClient = apiClient
        self.attest = attest
        self.deletionPending = deletionPending
    }

    func attach(deletionPending: DeletionPendingCoordinator) {
        self.deletionPending = deletionPending
    }

    /// `Transaction` を JWS 文字列化してサーバーへ送る。失敗はログに残すのみ。
    func verify(_ transaction: Transaction) async {
        guard attest.isSupported, attest.isRegistered else {
            Self.logger.notice("Skip storekit verify: attest unavailable")
            return
        }
        let jws = transaction.jsonRepresentation
        guard let jwsString = String(data: jws, encoding: .utf8) else {
            Self.logger.error("Failed to encode transaction JWS as UTF-8")
            return
        }
        do {
            let response: StoreKitVerifyResponse = try await apiClient.request(
                .storekitVerify(StoreKitVerifyBody(jws: jwsString))
            )
            Self.logger.info("Server confirmed is_pro=\(response.is_pro, privacy: .public) for product=\(response.product_id, privacy: .public)")
        } catch let error as APIError {
            Self.logger.error("storekit/verify failed (APIError): \(error.localizedDescription, privacy: .public)")
            if error.isDeletionPending {
                deletionPending?.report(error)
            }
        } catch {
            Self.logger.error("storekit/verify failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
