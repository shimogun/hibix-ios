import SwiftUI
import os.log

@main
struct HibixApp: App {
    @State private var dependencies: AppDependencies = HibixApp.bootstrap()
    @State private var instanceId: UUID = UUID()

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(instanceId)
                .environment(dependencies)
                .environment(\.appRebooter, AppRebooter(reboot: reboot))
                .task(id: instanceId) {
                    await dependencies.warmUp()
                }
        }
    }

    /// F-11 データ削除完了後に呼ばれる。新規 `AppDependencies` を生成し、
    /// SwiftUI ルートを `.id()` で完全に作り直してオンボーディング初期状態に戻す。
    private func reboot() {
        let new = HibixApp.bootstrap()
        dependencies = new
        instanceId = UUID()
    }

    private static func bootstrap() -> AppDependencies {
        do {
            return try AppDependencies()
        } catch {
            Logger(subsystem: "com.shimogun.hibix", category: "App")
                .error("Bootstrap failed: \(error.localizedDescription, privacy: .public)")
            fatalError("Bootstrap failed: \(error)")
        }
    }
}
