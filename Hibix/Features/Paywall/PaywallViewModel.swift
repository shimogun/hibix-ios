import Foundation
import Observation
import StoreKit
import os.log

/// `PaywallView` の状態とアクションを管理。StoreKit `Product.products(for:)` / `purchase()` / `AppStore.sync()` を扱う。
@MainActor
@Observable
final class PaywallViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(product: StoreKitProductDisplay)
        case failed(message: String)
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case restoring
        case completed
        case cancelledByUser
        case failed(message: String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var purchaseState: PurchaseState = .idle

    @ObservationIgnored private let entitlement: EntitlementManager

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Paywall")

    init(entitlement: EntitlementManager) {
        self.entitlement = entitlement
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: [StoreKitProduct.proLifetimeID])
            guard let product = products.first(where: { $0.id == StoreKitProduct.proLifetimeID }) else {
                loadState = .failed(message: "商品情報が取得できませんでした")
                return
            }
            loadState = .loaded(product: StoreKitProductDisplay(
                id: product.id,
                displayName: product.displayName,
                description: product.description,
                displayPrice: product.displayPrice
            ))
        } catch {
            Self.logger.error("Product fetch failed: \(error.localizedDescription, privacy: .public)")
            loadState = .failed(message: "商品情報が取得できませんでした")
        }
    }

    func purchase() async {
        guard case .loaded = loadState else { return }
        purchaseState = .purchasing
        do {
            let products = try await Product.products(for: [StoreKitProduct.proLifetimeID])
            guard let product = products.first else {
                purchaseState = .failed(message: "購入に失敗しました。時間を置いて再度お試しください")
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await entitlement.handlePurchase(verification)
                    await transaction.finish()
                    purchaseState = .completed
                case .unverified:
                    purchaseState = .failed(message: "購入の検証に失敗しました")
                }
            case .userCancelled:
                purchaseState = .cancelledByUser
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed(message: "購入に失敗しました")
            }
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            purchaseState = .failed(message: "購入に失敗しました。時間を置いて再度お試しください")
        }
    }

    func restorePurchases() async {
        purchaseState = .restoring
        do {
            try await AppStore.sync()
            await entitlement.refresh()
            if entitlement.isPro {
                purchaseState = .completed
            } else {
                purchaseState = .failed(message: "購入履歴がありません")
            }
        } catch {
            Self.logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            purchaseState = .failed(message: "復元に失敗しました。時間を置いて再度お試しください")
        }
    }
}

/// View 側に渡す軽量な商品表示モデル。
struct StoreKitProductDisplay: Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    let displayPrice: String
}
