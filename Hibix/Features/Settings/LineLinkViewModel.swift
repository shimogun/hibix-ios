import Foundation
import Observation
import os.log

/// LINE 連携画面（コード発行・友だち追加・status ポーリング）の状態管理。
/// PRD v1.1 §8.12（C案）。失敗は画面内に明示する（同期失敗時 UX 方針）。
@MainActor
@Observable
final class LineLinkViewModel {
    enum Phase: Equatable {
        case loading
        case code(LineLinkService.LineLinkCode)
        case linked
        case expired
        case error(String)
    }

    private(set) var phase: Phase = .loading

    @ObservationIgnored private let service: LineLinkService
    @ObservationIgnored private let localContactID: Int64

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "LineLinkVM")

    init(service: LineLinkService, localContactID: Int64) {
        self.service = service
        self.localContactID = localContactID
    }

    /// コードを発行して表示状態にする。
    func start() async {
        phase = .loading
        do {
            let code = try await service.issueCode(localContactID: localContactID)
            phase = .code(code)
        } catch {
            Self.logger.error("issueCode failed: \(error.localizedDescription, privacy: .public)")
            phase = .error("連携コードの発行に失敗しました。通信状況を確認して、もう一度お試しください。")
        }
    }

    func reissue() async {
        await start()
    }

    /// linked になったら true。呼び出し側が一定間隔で回す。
    func pollOnce() async -> Bool {
        guard case .code(let code) = phase else { return false }
        if code.expiresAt <= Date() {
            phase = .expired
            return false
        }
        do {
            let status = try await service.fetchStatus(localContactID: localContactID)
            if status == .linked {
                phase = .linked
                return true
            }
            return false
        } catch {
            Self.logger.error("fetchStatus failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// ShareLink 用テキスト（コード＋手順）。
    var shareText: String {
        guard case .code(let code) = phase else { return "" }
        return "Hibix の見守り通知を LINE で受け取るには、公式アカウントを友だち追加して、このコードをトークに送ってください: \(code.code)"
    }
}
