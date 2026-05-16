# StoreKit 2 / 課金規約

## 商品ID(変更不可)

| 商品ID | 種類 | 価格 |
|---|---|---|
| `com.shimogun.hibix.pro.lifetime` | Non-Consumable | ¥2,800(Tier 18) |

**この商品IDは PRD §5.3 で確定**。コード内では必ず定数として宣言:

```swift
enum HibixProducts {
    static let lifetimeProID = "com.shimogun.hibix.pro.lifetime"
    static let allProductIDs: [String] = [lifetimeProID]
}
```

商品ID文字列を複数箇所にハードコードしない。

## EntitlementManager 設計

`actor` で実装(データ競合防止):

```swift
actor EntitlementManager {
    static let shared = EntitlementManager()
    private(set) var isPro: Bool = false

    func refresh() async { ... }
    func observe() async { ... }  // Transaction.updates を購読
}
```

- 起動時に `refresh()` → `Transaction.currentEntitlements` 確認
- 結果を Keychain (`hibix.entitlement.pro`) に保存
- オフライン時は Keychain の値を信頼

## 購入フロー(F-12)

```swift
func purchase() async throws {
    let products = try await Product.products(for: [HibixProducts.lifetimeProID])
    guard let product = products.first else {
        throw PurchaseError.productNotFound
    }
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
        let transaction = try checkVerified(verification)
        await transaction.finish()
        await EntitlementManager.shared.refresh()
    case .userCancelled:
        // エラー表示しない(PRD §6 F-12)
        return
    case .pending:
        // 親の承認待ち等。後で Transaction.updates で通知される
        return
    @unknown default:
        throw PurchaseError.unknown
    }
}

private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified: throw PurchaseError.unverified
    case .verified(let safe): return safe
    }
}
```

## Transaction.updates 購読

アプリ起動時に Task で常時購読:

```swift
func observe() async {
    for await result in Transaction.updates {
        if case .verified(let transaction) = result {
            await transaction.finish()
            await refresh()
        }
    }
}
```

## 購入復元(F-14)

```swift
func restore() async throws {
    try await AppStore.sync()
    await EntitlementManager.shared.refresh()
}
```

- 未購入で復元してもエラーにせず「購入履歴がありません」を表示(PRD §6 F-14)
- ペイウォール下部と 設定 > 購入を復元 の2箇所に導線

## FeatureGate(F-13)

機能ゲーティングは `FeatureGate` に集約。判定箇所を散らさない:

```swift
enum Feature {
    case modeSwitch
    case emergencyContact
    case appLock
    case reminders
    case fullPixelHistory
}

struct FeatureGate {
    static func isAllowed(_ feature: Feature) async -> Bool {
        await EntitlementManager.shared.isPro
    }
}
```

機能追加時は enum を1ケース追加するだけ。判定式を増やさない。

## ペイウォール表示トリガー(PRD §5.6)

無料ユーザーが以下に到達した時に `PaywallView` をモーダル表示:
- 設定 > モード で `solo` 以外を選ぼうとした時
- 設定 > 緊急連絡先 で追加ボタンタップ時
- 設定 > アプリロック で ON にしようとした時
- ピクセルカレンダーで1年より過去にスクロール試行時
- ホームから「Pro にアップグレード」明示タップ時

## Keychain との整合

- 購入完了 → Keychain `hibix.entitlement.pro = "true"`
- 起動時はKeychain値を即UI反映 → 非同期でStoreKitと突き合わせ → 差分があればKeychain更新
- iCloud Keychain 同期で機種変対応(PRD §10.2)

## テスト方針

- StoreKit Configuration File(`.storekit`)を使ったSandboxテスト
- ユニットテスト: `Transaction.currentEntitlements` のモック注入(`StoreKitTest`)
- 受け入れ基準: PRD F-12/F-14 のチェックリスト

## 禁止事項

- **商品IDのハードコード散在**(定数化必須)
- **VerificationResult.unverified の信頼**(必ず checkVerified を通す)
- **transaction.finish() の省略**(消費されないトランザクションが残る)
- **`.userCancelled` でのエラー表示**(ユーザー操作なので静かに戻す)
- **サブスク商品の追加**(v0.1スコープ外・PRD §14)
- **レシート検証のサーバー実装**(v0.1ではサーバーは Entitlement を信頼するだけ・PRD §6 F-13)

## 共通参照

機微データ取扱は `common-security/SKILL.md` を参照。
