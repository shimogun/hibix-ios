import Foundation
import Observation
import os.log

@MainActor
@Observable
final class AppDependencies {
    let database: DatabaseManager
    let keychain: KeychainStore
    let anonymousUUID: String

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "App")

    init() throws {
        let databaseURL = try DatabaseManager.defaultURL()
        self.database = try DatabaseManager(databaseURL: databaseURL)
        let store = KeychainStore()
        self.keychain = store
        self.anonymousUUID = try store.loadOrIssueAnonymousUUID()
        Self.logger.info("AppDependencies bootstrapped")
    }
}
