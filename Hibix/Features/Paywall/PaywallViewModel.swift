import Foundation
import Observation
import StoreKit
import os.log

/// ペイウォールで選べるプラン。
enum PaywallPlan: Equatable, Sendable {
    case subscription   // 7日間無料 → ¥480/月（主役）
    case lifetime       // 買い切り ¥5,800（第2）
}

/// `PaywallView` の状態とアクションを管理。
/// StoreKit `Product.products(for:)` / `purchase()` / `AppStore.sync()` を扱う。
/// v1.1: サブスク（トライアル）と買い切り lifetime のハイブリッド。
@MainActor
@Observable
final class PaywallViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded(offer: PaywallOffer)
        case failed(message: String)
    }

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case restoring
        case completed
        case cancelledByUser
        case pendingApproval   // Ask to Buy 等の承認待ち
        case failed(message: String)
    }

    private(set) var loadState: LoadState = .idle
    private(set) var purchaseState: PurchaseState = .idle

    @ObservationIgnored private let entitlement: EntitlementProviding
    /// 購入履歴を App Store と強制同期する処理（既定は `AppStore.sync()`）。
    /// テストで sync の throw を再現するため注入可能にしている。
    @ObservationIgnored private let syncAppStore: @Sendable () async throws -> Void
    /// 購入用に保持する実 Product（View には display モデルのみ渡す）。
    @ObservationIgnored private var subscriptionProduct: Product?
    @ObservationIgnored private var lifetimeProduct: Product?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Paywall")

    init(entitlement: EntitlementProviding,
         syncAppStore: @escaping @Sendable () async throws -> Void = { try await AppStore.sync() }) {
        self.entitlement = entitlement
        self.syncAppStore = syncAppStore
    }

    func loadProducts() async {
        loadState = .loading
        do {
            let products = try await Product.products(for: Array(StoreKitProduct.allIDs))
            let subscription = products.first { $0.id == StoreKitProduct.proMonthlyID }
            let lifetime = products.first { $0.id == StoreKitProduct.proLifetimeID }
            self.subscriptionProduct = subscription
            self.lifetimeProduct = lifetime

            guard subscription != nil || lifetime != nil else {
                loadState = .failed(message: "商品情報が取得できませんでした")
                return
            }
            let offer = await makeOffer(subscription: subscription, lifetime: lifetime)
            loadState = .loaded(offer: offer)
        } catch {
            Self.logger.error("Product fetch failed: \(error.localizedDescription, privacy: .public)")
            loadState = .failed(message: "商品情報が取得できませんでした")
        }
    }

    func purchase(_ plan: PaywallPlan) async {
        guard let product = product(for: plan) else {
            purchaseState = .failed(message: "購入に失敗しました。時間を置いて再度お試しください")
            return
        }
        purchaseState = .purchasing
        do {
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
                // Ask to Buy 等。無言終了に見せず「承認待ち」を明示（後で Transaction.updates で反映）。
                purchaseState = .pendingApproval
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

        // `AppStore.sync()` は App Store と購入履歴を強制同期するが、購入自体は
        // sync 無しでも `Transaction.currentEntitlements` から読める。Sandbox では
        // sync が良性理由で throw することがあるため、throw を復元失敗とはみなさず、
        // 最終判定は必ず `entitlement.refresh()`（＝currentEntitlements）に委ねる。
        var syncFailed = false
        do {
            try await syncAppStore()
        } catch {
            // 認証シートをユーザーが閉じた場合はエラー表示せず静かに戻す（.userCancelled 規約）。
            if let skError = error as? StoreKitError, case .userCancelled = skError {
                Self.logger.info("Restore cancelled by user during AppStore.sync")
                purchaseState = .cancelledByUser
                return
            }
            syncFailed = true
            Self.logger.error("AppStore.sync failed during restore (falling back to currentEntitlements): \(error.localizedDescription, privacy: .public)")
        }

        await entitlement.refresh()
        if await entitlement.isPro {
            // sync が throw しても currentEntitlements に購入があれば復元成功。
            purchaseState = .completed
        } else if syncFailed {
            // 同期失敗かつ購入未検出のときだけ本当の失敗として再試行を促す。
            purchaseState = .failed(message: "復元に失敗しました。時間を置いて再度お試しください")
        } else {
            // 同期成功・購入なし＝購入履歴が無い（エラーではない・F-14）。
            purchaseState = .failed(message: "購入履歴がありません")
        }
    }

    // MARK: - Private

    private func product(for plan: PaywallPlan) -> Product? {
        switch plan {
        case .subscription: return subscriptionProduct
        case .lifetime: return lifetimeProduct
        }
    }

    /// StoreKit 商品から View 表示用オファーを組み立てる（トライアル eligibility 判定含む）。
    private func makeOffer(subscription: Product?, lifetime: Product?) async -> PaywallOffer {
        var subscriptionDisplay: SubscriptionDisplay?
        if let subscription, let info = subscription.subscription {
            let isEligible = await info.isEligibleForIntroOffer
            let hasFreeTrial = info.introductoryOffer?.paymentMode == .freeTrial
            subscriptionDisplay = SubscriptionDisplay(
                id: subscription.id,
                displayName: subscription.displayName,
                displayPrice: subscription.displayPrice,
                hasFreeTrial: hasFreeTrial,
                isEligibleForTrial: isEligible && hasFreeTrial,
                trialText: (isEligible && hasFreeTrial) ? "7日間無料" : nil
            )
        }

        var lifetimeDisplay: StoreKitProductDisplay?
        if let lifetime {
            lifetimeDisplay = StoreKitProductDisplay(
                id: lifetime.id,
                displayName: lifetime.displayName,
                description: lifetime.description,
                displayPrice: lifetime.displayPrice
            )
        }
        return PaywallOffer(subscription: subscriptionDisplay, lifetime: lifetimeDisplay)
    }
}

/// ペイウォールが表示する 2 プランの表示モデル。
struct PaywallOffer: Equatable, Sendable {
    let subscription: SubscriptionDisplay?
    let lifetime: StoreKitProductDisplay?
}

/// サブスク（月額）の表示モデル。
struct SubscriptionDisplay: Equatable, Sendable {
    let id: String
    let displayName: String
    /// 例: "¥480"
    let displayPrice: String
    /// イントロオファーに無料トライアルがあるか。
    let hasFreeTrial: Bool
    /// このユーザーが無料トライアル対象か（新規のみ）。
    let isEligibleForTrial: Bool
    /// トライアル文言（対象時のみ・例: "7日間無料"）。
    let trialText: String?
}

/// 買い切り lifetime の表示モデル。
struct StoreKitProductDisplay: Equatable, Sendable {
    let id: String
    let displayName: String
    let description: String
    /// 例: "¥5,800"
    let displayPrice: String
}
