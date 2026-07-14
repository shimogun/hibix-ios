import Testing
import StoreKit
@testable import Hibix

/// 購入復元（Restore / F-14）の回帰テスト。
///
/// リリースブロッカー（Apple Guideline 3.1.1）だった不具合の再発防止:
/// `AppStore.sync()` が Sandbox で良性 throw した際、旧実装は catch に落ちて
/// 「復元に失敗しました」を表示し、真実源である `Transaction.currentEntitlements`
/// （＝`entitlement.refresh()`）に到達していなかった。修正後は sync の throw を
/// 復元失敗とみなさず、エンタイトルメント再評価の結果で成否を判定する。
@Suite("PaywallViewModel restore", .serialized)
@MainActor
struct PaywallRestoreTests {

    /// `refresh()` で isPro を確定できる Fake。sync とエンタイトルメントを独立に制御する。
    @MainActor
    private final class FakeEntitlement: EntitlementProviding {
        var proValue: Bool
        private(set) var refreshCalled = false
        init(isPro: Bool) { self.proValue = isPro }
        var isPro: Bool { get async { proValue } }
        func refresh() async { refreshCalled = true }
        func handlePurchase(_ verification: VerificationResult<Transaction>) async {}
    }

    /// 報告された不具合の核心: sync が（userCancelled 以外で）throw しても、
    /// currentEntitlements に購入があれば復元は成功しなければならない。
    @Test
    func restoreSucceeds_whenSyncThrowsButEntitlementPresent() async {
        let entitlement = FakeEntitlement(isPro: true)
        let vm = PaywallViewModel(entitlement: entitlement,
                                  syncAppStore: { throw StoreKitError.unknown })

        await vm.restorePurchases()

        #expect(entitlement.refreshCalled)          // sync throw 後も refresh に到達している
        #expect(vm.purchaseState == .completed)     // 修正前は .failed("復元に失敗しました…") だった
    }

    /// 認証シートをユーザーが閉じた場合はエラー表示せず静かに戻す（.userCancelled 規約）。
    @Test
    func restoreCancelsSilently_whenUserCancelsSync() async {
        let vm = PaywallViewModel(entitlement: FakeEntitlement(isPro: false),
                                  syncAppStore: { throw StoreKitError.userCancelled })

        await vm.restorePurchases()

        #expect(vm.purchaseState == .cancelledByUser)
    }

    /// 同期成功・購入なしは「購入履歴がありません」（エラーではない・F-14）。
    @Test
    func restoreReportsNoHistory_whenSyncOkButNoEntitlement() async {
        let vm = PaywallViewModel(entitlement: FakeEntitlement(isPro: false),
                                  syncAppStore: {})

        await vm.restorePurchases()

        #expect(vm.purchaseState == .failed(message: "購入履歴がありません"))
    }

    /// 同期失敗かつ購入未検出のときだけ本当の失敗として再試行を促す。
    @Test
    func restoreFails_whenSyncThrowsAndNoEntitlement() async {
        let vm = PaywallViewModel(entitlement: FakeEntitlement(isPro: false),
                                  syncAppStore: { throw StoreKitError.unknown })

        await vm.restorePurchases()

        #expect(vm.purchaseState == .failed(message: "復元に失敗しました。時間を置いて再度お試しください"))
    }
}
