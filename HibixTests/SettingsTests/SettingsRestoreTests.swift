import Testing
import StoreKit
import GRDB
@testable import Hibix

/// 設定画面「購入を復元」(F-14) の回帰テスト。
///
/// ペイウォールと同じ復元バグ（`AppStore.sync()` の throw で currentEntitlements に
/// 到達せず「復元に失敗しました」を表示）が設定側 `SettingsViewModel` にも存在した。
/// 修正後は sync の throw を復元失敗とみなさず、エンタイトルメント再評価で判定する。
@Suite("SettingsViewModel restore", .serialized)
@MainActor
struct SettingsRestoreTests {

    @MainActor
    private final class FakeEntitlement: EntitlementProviding {
        var proValue: Bool
        init(isPro: Bool) { self.proValue = isPro }
        var isPro: Bool { get async { proValue } }
        func refresh() async {}
        func handlePurchase(_ verification: VerificationResult<Transaction>) async {}
    }

    private func makeVM(isPro: Bool,
                        sync: @escaping @Sendable () async throws -> Void) throws -> SettingsViewModel {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        return SettingsViewModel(settings: settings,
                                 entitlement: FakeEntitlement(isPro: isPro),
                                 syncAppStore: sync)
    }

    /// 核心の回帰: sync が（userCancelled 以外で）throw しても、購入があれば復元成功。
    @Test
    func restoreSucceeds_whenSyncThrowsButEntitlementPresent() async throws {
        let vm = try makeVM(isPro: true, sync: { throw StoreKitError.unknown })
        await vm.restorePurchases()
        #expect(vm.restoreState == .completed)   // 修正前は .failed("復元に失敗しました…")
    }

    /// 認証シートをユーザーが閉じた場合はエラー表示せず静かに戻す（.idle）。
    @Test
    func restoreReturnsIdle_whenUserCancelsSync() async throws {
        let vm = try makeVM(isPro: false, sync: { throw StoreKitError.userCancelled })
        await vm.restorePurchases()
        #expect(vm.restoreState == .idle)
    }

    /// 同期失敗かつ購入未検出のときだけ本当の失敗として再試行を促す。
    @Test
    func restoreFails_whenSyncThrowsAndNoEntitlement() async throws {
        let vm = try makeVM(isPro: false, sync: { throw StoreKitError.unknown })
        await vm.restorePurchases()
        #expect(vm.restoreState == .failed(message: "復元に失敗しました。時間を置いて再度お試しください"))
    }
}
