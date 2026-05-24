import Foundation
import Observation
import SwiftUI
import os.log

/// アプリ全体の外観モード (システム / ライト / ダーク) を保持・永続化する。
/// SettingsRepository (settings テーブル) を真の永続層として使用。
@MainActor
@Observable
final class AppearanceManager {
    private(set) var mode: AppearanceMode = .system

    @ObservationIgnored
    private let settings: any SettingsRepositoryProtocol

    @ObservationIgnored
    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Appearance")

    init(settings: any SettingsRepositoryProtocol) {
        self.settings = settings
    }

    /// 起動時に呼び出して、永続値からモードを復元する。
    func load() async {
        do {
            let raw = try await settings.string(forKey: .appearance)
            if let raw, let restored = AppearanceMode(rawValue: raw) {
                mode = restored
            } else {
                mode = .system
            }
        } catch {
            Self.logger.error("Load appearance failed: \(error.localizedDescription, privacy: .public)")
            mode = .system
        }
    }

    /// モードを更新し永続化する。
    func update(_ newMode: AppearanceMode) async {
        mode = newMode
        do {
            try await settings.setString(newMode.rawValue, forKey: .appearance, now: Date())
        } catch {
            Self.logger.error("Save appearance failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// SwiftUI .preferredColorScheme に渡す値。.system のときは nil。
    var preferredColorScheme: ColorScheme? {
        switch mode {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
