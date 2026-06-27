import Testing
import Foundation
import GRDB
@testable import Hibix

@Suite("ModeSwitchViewModel", .serialized)
@MainActor
struct ModeSwitchViewModelTests {

    /// attest 未登録の APIClient（settings sync は no-op になる）でローカル挙動のみ検証する。
    private func makeVM(isPro: Bool) throws -> (ModeSwitchViewModel, EmergencyContactsRepository) {
        let dbQueue = try DatabaseQueue()
        try Migrations.migrator.migrate(dbQueue)
        let settings = SettingsRepository(writer: dbQueue)
        let contacts = EmergencyContactsRepository(writer: dbQueue)
        let keychain = KeychainStore(service: UUID().uuidString)
        if isPro { try keychain.setEntitlementPro(true) }
        let entitlement = EntitlementManager(keychain: keychain)
        let client = TestSupport.makeStubAPIClient { request in
            TestSupport.ok(request, #"{"watch_days":2,"watch_mode":"gentle","is_pro":true}"#)
        }
        // 未登録 attest → ContactsSyncService.syncSettings は read-only スキップ（ローカル挙動のみ検証）。
        let attest = try TestSupport.makeUnregisteredAttestClient()
        let sync = ContactsSyncService(apiClient: client, contactsRepo: contacts, settings: settings, attest: attest)
        let vm = ModeSwitchViewModel(settings: settings, entitlement: entitlement,
                                     contacts: contacts, contactsSync: sync)
        return (vm, contacts)
    }

    @Test
    func selectGentle_withNoEmailContact_blocksAndStaysSolo() async throws {
        let (vm, _) = try makeVM(isPro: true)
        await vm.select(.gentle)
        #expect(vm.selectedMode == .solo)
        #expect(vm.requiresEmailContactAlert == true)
    }

    @Test
    func selectGentle_withEmailContact_succeeds() async throws {
        let (vm, repo) = try makeVM(isPro: true)
        _ = try await repo.add(contactType: .email, value: "a@example.com", label: nil, now: Date())
        await vm.select(.gentle)
        #expect(vm.selectedMode == .gentle)
        #expect(vm.requiresEmailContactAlert == false)
    }

    @Test
    func selectGentle_whenFree_showsPaywallNotEmailAlert() async throws {
        let (vm, _) = try makeVM(isPro: false)
        await vm.select(.gentle)
        #expect(vm.isPaywallPresented == true)
        #expect(vm.selectedMode == .solo)
    }

    @Test
    func selectGentle_withOnlyLineContact_blocks() async throws {
        let (vm, repo) = try makeVM(isPro: true)
        _ = try await repo.add(contactType: .line, value: "兄", label: nil, now: Date())
        await vm.select(.gentle)
        #expect(vm.selectedMode == .solo)
        #expect(vm.requiresEmailContactAlert == true)
    }
}
