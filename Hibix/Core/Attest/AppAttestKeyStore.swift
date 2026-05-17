import Foundation
import KeychainAccess
import os.log

/// App Attest 関連の永続状態(key_id / 登録済みフラグ)を Keychain に保存する。
///
/// `synchronizable = false`: App Attest 鍵は端末バインドのため iCloud 同期させない。
/// 機種変更時は新端末で再 attest が必要(PRD v2.2.0 §10.7)。
enum AppAttestKeychainKey {
    static let keyId = "hibix.attest.key_id"
    static let registered = "hibix.attest.registered"
}

final class AppAttestKeyStore {
    private let keychain: Keychain
    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Attest")

    init(service: String = "com.shimogun.hibix") {
        self.keychain = Keychain(service: service)
            .synchronizable(false)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    func loadKeyId() -> String? {
        do {
            let value = try keychain.get(AppAttestKeychainKey.keyId)
            return value?.isEmpty == false ? value : nil
        } catch {
            Self.logger.error("Failed to read attest key_id: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func saveKeyId(_ keyId: String) throws {
        try keychain.set(keyId, key: AppAttestKeychainKey.keyId)
    }

    var isRegistered: Bool {
        do {
            return try keychain.get(AppAttestKeychainKey.registered) == "true"
        } catch {
            return false
        }
    }

    func setRegistered(_ registered: Bool) throws {
        try keychain.set(registered ? "true" : "false", key: AppAttestKeychainKey.registered)
    }

    func reset() throws {
        try keychain.remove(AppAttestKeychainKey.keyId)
        try keychain.remove(AppAttestKeychainKey.registered)
    }
}
