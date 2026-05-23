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

    /// `VerificationResult` の JWS 表現をサーバーへ送る。失敗はログに残すのみ。
    /// `Transaction.jsonRepresentation` は JSON Data であって JWS ではないため、
    /// `VerificationResult.jwsRepresentation` を使う (PRD v2.2.0 §8.9)。
    func verify(_ verification: VerificationResult<Transaction>) async {
        guard attest.isSupported, attest.isRegistered else {
            Self.logger.notice("Skip storekit verify: attest unavailable")
            return
        }
        let jwsString = verification.jwsRepresentation
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
