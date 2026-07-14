import Foundation
import StoreKit

/// `EntitlementManager` を利用側（`PaywallViewModel` 等）から見た口。
/// テスト時に Fake で差し替え可能にする（購入・復元フローの単体検証用）。
protocol EntitlementProviding: Sendable {
    var isPro: Bool { get async }
    /// `Transaction.currentEntitlements` を再評価してエンタイトルメントを更新する。
    func refresh() async
    /// 購入成功時の検証済みトランザクションを反映する。
    func handlePurchase(_ verification: VerificationResult<Transaction>) async
}
