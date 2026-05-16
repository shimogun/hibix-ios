import Testing
import Foundation
@testable import Hibix

@Suite("KeychainStore")
struct KeychainStoreTests {

    private func makeStore() throws -> KeychainStore {
        let service = "com.shimogun.hibix.tests.\(UUID().uuidString)"
        let store = KeychainStore(service: service, synchronizable: false)
        try store.reset()
        return store
    }

    @Test
    func loadOrIssueAnonymousUUID_firstCall_returnsValidUUID() throws {
        let store = try makeStore()
        defer { try? store.reset() }

        let uuid = try store.loadOrIssueAnonymousUUID()
        #expect(!uuid.isEmpty)
        #expect(UUID(uuidString: uuid) != nil)
    }

    @Test
    func loadOrIssueAnonymousUUID_secondCall_returnsSameUUID() throws {
        let store = try makeStore()
        defer { try? store.reset() }

        let first = try store.loadOrIssueAnonymousUUID()
        let second = try store.loadOrIssueAnonymousUUID()
        #expect(first == second)
    }

    @Test
    func entitlementPro_defaultsToFalse() throws {
        let store = try makeStore()
        defer { try? store.reset() }

        #expect(store.entitlementPro == false)
    }

    @Test
    func entitlementPro_persistsAfterSet() throws {
        let store = try makeStore()
        defer { try? store.reset() }

        try store.setEntitlementPro(true)
        #expect(store.entitlementPro == true)

        try store.setEntitlementPro(false)
        #expect(store.entitlementPro == false)
    }
}
