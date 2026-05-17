import Foundation

/// PRD v2.2.0 §5.3 で確定した唯一の課金商品。
enum StoreKitProduct {
    static let proLifetimeID = "com.shimogun.hibix.pro.lifetime"

    /// アプリ全体で扱う商品 ID 一覧。`Product.products(for:)` に渡す。
    static let allIDs: Set<String> = [proLifetimeID]
}
