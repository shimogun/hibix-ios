import Foundation
import SwiftUI

/// データ削除後に SwiftUI のルートを破棄して `AppDependencies` を再生成するためのトリガ。
///
/// `HibixApp` がインスタンスを 1 つ生成し、Environment 経由で配布する。
/// 呼び出されると `RootView` が `.id(...)` の差し替えで完全に再構築され、
/// オンボーディング初期状態から再スタートする。
///
/// Environment 値の defaultValue で `Sendable` 制約を満たすため、内部クロージャは
/// MainActor 隔離だが `@unchecked Sendable` でラップする(SwiftUI Environment は実行時 MainActor)。
final class AppRebooter: @unchecked Sendable {
    private let _reboot: () -> Void

    init(reboot: @escaping () -> Void) {
        self._reboot = reboot
    }

    @MainActor
    func reboot() {
        _reboot()
    }
}

private struct AppRebooterKey: EnvironmentKey {
    static let defaultValue: AppRebooter = AppRebooter(reboot: {})
}

extension EnvironmentValues {
    var appRebooter: AppRebooter {
        get { self[AppRebooterKey.self] }
        set { self[AppRebooterKey.self] = newValue }
    }
}
