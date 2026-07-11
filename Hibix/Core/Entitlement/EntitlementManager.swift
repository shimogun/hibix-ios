import Foundation
import Observation
import StoreKit
import os.log

/// 課金状態 (`isPro`) の単一ソース (PRD v2.2.0 §5.1 / §5.4)。
///
/// - 起動時: Keychain 値を即座に反映 → 非同期で `Transaction.currentEntitlements` 確認
/// - 実行中: `Transaction.updates` を購読して購入/失効に追従
/// - サーバー同期: 購入完了時に `StoreKitVerifyService` に JWS を流す(別途呼び出し)
///
/// オフライン時は Keychain の値を最後の真実として動作。
@MainActor
@Observable
final class EntitlementManager: EntitlementProviding {
    private(set) var isPro: Bool

    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private let onVerifyTransaction: @Sendable (VerificationResult<Transaction>) async -> Void
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Entitlement")

    init(keychain: KeychainStore,
         onVerifyTransaction: @escaping @Sendable (VerificationResult<Transaction>) async -> Void = { _ in }) {
        self.keychain = keychain
        self.isPro = keychain.entitlementPro
        self.onVerifyTransaction = onVerifyTransaction
    }

    deinit {
        updatesTask?.cancel()
    }

    /// 起動直後に呼ぶ。`Transaction.currentEntitlements` を確認 + `Transaction.updates` 監視を開始。
    func warmUp() async {
        await refresh()
        startObservingUpdates()
    }

    /// `Transaction.currentEntitlements` を再評価。明示的リフレッシュ用(購入復元など)。
    /// 見つかった検証済みトランザクションは `onVerifyTransaction` にも渡し、
    /// サーバー側 `is_pro` をリストア (PRD v2.2.0 §5 / §10.7 / C-01)。
    func refresh() async {
        var detectedPro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               StoreKitProduct.grantsPro(transaction.productID),
               transaction.revocationDate == nil {
                // 有効なサブスク（トライアル中含む）はここに現れ、失効すると外れる。
                detectedPro = true
                await onVerifyTransaction(result)
            }
        }
        await applyEntitlement(detectedPro)
    }

    /// 購入成功時に呼ぶ。サーバーへの JWS 送信 + Entitlement 反映。
    /// `VerificationResult` を受け取って `jwsRepresentation` をサーバーに送る。
    func handlePurchase(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification,
              StoreKitProduct.grantsPro(transaction.productID) else { return }
        await onVerifyTransaction(verification)
        await applyEntitlement(true)
    }

    /// テスト用の状態リセット (データ削除権実装でも使用)。
    func reset() async {
        await applyEntitlement(false)
    }

    // MARK: - Private

    private func startObservingUpdates() {
        updatesTask?.cancel()
        updatesTask = Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handlePurchase(result)
                    await transaction.finish()
                }
            }
        }
    }

    private func applyEntitlement(_ value: Bool) async {
        let changed = isPro != value
        isPro = value
        do {
            try keychain.setEntitlementPro(value)
        } catch {
            Self.logger.error("Failed to persist entitlement: \(error.localizedDescription, privacy: .public)")
        }
        if changed {
            Self.logger.info("Entitlement updated: isPro=\(value, privacy: .public)")
        }
    }
}
