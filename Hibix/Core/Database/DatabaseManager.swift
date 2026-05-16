import Foundation
import GRDB
import os.log

enum DatabaseError: LocalizedError {
    case documentsDirectoryUnavailable

    var errorDescription: String? {
        switch self {
        case .documentsDirectoryUnavailable:
            return "Documents ディレクトリが見つかりません"
        }
    }
}

final class DatabaseManager {
    let dbPool: DatabasePool

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Database")
    private static let databaseFileName = "hibix.sqlite"

    init(databaseURL: URL) throws {
        var configuration = Configuration()
        configuration.label = "hibix"
        let pool = try DatabasePool(path: databaseURL.path, configuration: configuration)
        try Migrations.migrator.migrate(pool)
        self.dbPool = pool
        Self.logger.info("Database initialized at \(databaseURL.path, privacy: .public)")
    }

    static func defaultURL() throws -> URL {
        guard let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first else {
            throw DatabaseError.documentsDirectoryUnavailable
        }
        return documents.appendingPathComponent(databaseFileName)
    }
}
