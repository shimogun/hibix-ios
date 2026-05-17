import Foundation
import GRDB

nonisolated struct MoodEntry: Codable, FetchableRecord, MutablePersistableRecord, Equatable, Sendable {
    var id: Int64?
    var entryDate: String
    var moodLevel: Int
    var memo: String?
    var createdAt: String
    var updatedAt: String

    static let databaseTableName: String = "mood_entries"

    enum CodingKeys: String, CodingKey {
        case id
        case entryDate = "entry_date"
        case moodLevel = "mood_level"
        case memo
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension MoodEntry {
    var mood: MoodLevel? { MoodLevel(rawValue: moodLevel) }
}
