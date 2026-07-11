import Foundation

/// アプリで扱う課金商品 ID（PRD §5.3）。
///
/// v1.1 でハイブリッド課金に刷新（2026-07-11 オーナー承認）:
/// - 自動更新サブスク `pro.monthly`（7日間無料トライアル → ¥480/月）
/// - 買い切り lifetime `pro.lifetime`（¥5,800）
enum StoreKitProduct {
    /// 自動更新サブスク（主役プラン）。7日間無料トライアル付き。
    static let proMonthlyID = "com.shimogun.hibix.pro.monthly"
    /// 買い切り lifetime（第2プラン）。
    static let proLifetimeID = "com.shimogun.hibix.pro.lifetime"

    /// アプリ全体で扱う商品 ID 一覧。`Product.products(for:)` に渡す。
    static let allIDs: Set<String> = [proMonthlyID, proLifetimeID]

    /// 有効な Entitlement とみなす商品か（サブスク or lifetime）。
    static func grantsPro(_ productID: String) -> Bool {
        allIDs.contains(productID)
    }
}
