import Testing
@testable import Hibix

/// エンタイトルメント境界（どの商品 ID が Pro を付与するか）の回帰テスト。
/// v1.1 でサブスク（monthly）と買い切り（lifetime）の両方が Pro を付与する。
@Suite("StoreKitProduct entitlement boundary")
struct StoreKitProductTests {

    @Test
    func grantsPro_forSubscription() {
        #expect(StoreKitProduct.grantsPro(StoreKitProduct.proMonthlyID))
    }

    @Test
    func grantsPro_forLifetime() {
        #expect(StoreKitProduct.grantsPro(StoreKitProduct.proLifetimeID))
    }

    @Test
    func grantsPro_falseForUnknownID() {
        #expect(!StoreKitProduct.grantsPro("com.shimogun.hibix.pro.unknown"))
    }

    @Test
    func allIDs_containsBothPlans() {
        #expect(StoreKitProduct.allIDs == [StoreKitProduct.proMonthlyID, StoreKitProduct.proLifetimeID])
    }
}
