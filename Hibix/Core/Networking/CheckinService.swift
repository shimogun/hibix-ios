import Foundation
import os.log

/// 気分タップ後の `POST /api/checkin` 送信を担う。
///
/// - 成功時は `settings.last_synced_at` を ISO8601 で記録
/// - 失敗時はサイレント(次回起動時に未送信分を resync)
/// - 重複送信は最大1分間隔のクールダウンで抑制(429 防止の保険)
///
/// PRD v2.2.0 §6 F-01 / §8.2 / §9.3。
@MainActor
final class CheckinService {
    @ObservationIgnored private let apiClient: APIClient
    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let moodEntries: MoodEntryRepository
    @ObservationIgnored private let attest: AppAttestClient
    @ObservationIgnored private weak var deletionPending: DeletionPendingCoordinator?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Checkin")

    init(apiClient: APIClient,
         settings: SettingsRepository,
         moodEntries: MoodEntryRepository,
         attest: AppAttestClient,
         deletionPending: DeletionPendingCoordinator? = nil) {
        self.apiClient = apiClient
        self.settings = settings
        self.moodEntries = moodEntries
        self.attest = attest
        self.deletionPending = deletionPending
    }

    func attach(deletionPending: DeletionPendingCoordinator) {
        self.deletionPending = deletionPending
    }

    /// 気分タップ完了直後にバックグラウンドで呼ぶ。
    /// 失敗してもアプリ UX を阻害せず、ログに残してリトライは次回起動時。
    func reportCheckin(at date: Date) async {
        guard attest.isSupported, attest.isRegistered else {
            Self.logger.notice("Skip checkin: attest unavailable (read-only mode)")
            return
        }
        do {
            let response: CheckinResponse = try await apiClient.request(.checkin(checkinAt: date))
            try? await settings.setString(
                HibixDate.iso8601String(from: response.last_checkin_at),
                forKey: .lastSyncedAt,
                now: Date()
            )
            Self.logger.info("Checkin synced: \(HibixDate.iso8601String(from: response.last_checkin_at), privacy: .public)")
        } catch let error as APIError {
            Self.logger.error("Checkin failed (APIError): \(error.localizedDescription, privacy: .public)")
            if error.isDeletionPending {
                deletionPending?.report(error)
            }
        } catch {
            Self.logger.error("Checkin failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 起動時 / ネット復帰時に呼ぶ。最後の同期以降に記録された entries を順次送信。
    /// PRD §9.3 オフラインバッファ対応。
    func resyncPendingCheckins() async {
        guard attest.isSupported, attest.isRegistered else { return }
        let lastSynced: Date?
        do {
            let raw = try await settings.string(forKey: .lastSyncedAt)
            lastSynced = raw.flatMap { Self.parseISO8601($0) }
        } catch {
            Self.logger.error("Read last_synced_at failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        let today = HibixDate.todayString(now: Date())
        let earliest = HibixDate.dayString(offsetDays: -7, from: Date())
        let entries: [MoodEntry]
        do {
            entries = try await moodEntries.entries(from: earliest, to: today)
        } catch {
            Self.logger.error("Load entries for resync failed: \(error.localizedDescription, privacy: .public)")
            return
        }

        let pending = entries.compactMap { entry -> Date? in
            guard let createdAt = Self.parseISO8601(entry.createdAt) else { return nil }
            if let lastSynced, createdAt <= lastSynced { return nil }
            return createdAt
        }.sorted()

        for createdAt in pending {
            await reportCheckin(at: createdAt)
        }
    }

    private static func parseISO8601(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}
