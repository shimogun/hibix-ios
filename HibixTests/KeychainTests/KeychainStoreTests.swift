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

    /// PRD §4.3: anonymous_uuid は iCloud Keychain 同期される必要がある。
    /// 実機 2 台でのクロスデバイス同期は TestFlight フェーズで検証するが、
    /// ここでは kSecAttrSynchronizable=true が SecItem 層で確実に書かれていることを検証する。
    @Test
    func anonymousUUID_isStoredWith_synchronizableAttribute() throws {
        let service = "com.shimogun.hibix.sync.\(UUID().uuidString)"
        let store = KeychainStore(service: service, synchronizable: true)
        try store.reset()
        defer { try? store.reset() }

        _ = try store.loadOrIssueAnonymousUUID()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: KeychainKey.anonymousUUID,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        #expect(status == errSecSuccess)

        let attributes = result as? [String: Any]
        let synchronizable = attributes?[kSecAttrSynchronizable as String] as? Bool
        #expect(synchronizable == true)
    }
}
