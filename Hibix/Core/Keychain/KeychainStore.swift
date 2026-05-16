import Foundation
import KeychainAccess
import os.log

enum KeychainKey {
    static let anonymousUUID = "hibix.anonymous_uuid"
    static let entitlementPro = "hibix.entitlement.pro"
}

final class KeychainStore {
    private let keychain: Keychain
    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Keychain")
    private static let defaultService = "com.shimogun.hibix"

    init(
        service: String = KeychainStore.defaultService,
        synchronizable: Bool = true,
        accessibility: Accessibility = .afterFirstUnlock
    ) {
        self.keychain = Keychain(service: service)
            .synchronizable(synchronizable)
            .accessibility(accessibility)
    }

    func loadOrIssueAnonymousUUID() throws -> String {
        if let existing = try keychain.get(KeychainKey.anonymousUUID), !existing.isEmpty {
            return existing
        }
        let newValue = UUID().uuidString
        try keychain.set(newValue, key: KeychainKey.anonymousUUID)
        Self.logger.info("Issued new anonymous UUID")
        return newValue
    }

    var entitlementPro: Bool {
        do {
            return try keychain.get(KeychainKey.entitlementPro) == "true"
        } catch {
            Self.logger.error("Failed to read entitlementPro: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func setEntitlementPro(_ value: Bool) throws {
        try keychain.set(value ? "true" : "false", key: KeychainKey.entitlementPro)
    }

    func reset() throws {
        try keychain.removeAll()
    }
}
