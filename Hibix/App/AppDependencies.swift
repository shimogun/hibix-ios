import Foundation
import Observation
import os.log

@MainActor
@Observable
final class AppDependencies {
    let database: DatabaseManager
    let keychain: KeychainStore
    let anonymousUUID: String
    let moodEntryRepository: MoodEntryRepository

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "App")

    init() throws {
        let databaseURL = try DatabaseManager.defaultURL()
        let database = try DatabaseManager(databaseURL: databaseURL)
        self.database = database
        let store = KeychainStore()
        self.keychain = store
        self.anonymousUUID = try store.loadOrIssueAnonymousUUID()
        self.moodEntryRepository = MoodEntryRepository(writer: database.dbPool)
        Self.logger.info("AppDependencies bootstrapped")
    }
}
