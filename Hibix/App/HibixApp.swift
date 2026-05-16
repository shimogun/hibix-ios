import SwiftUI
import os.log

@main
struct HibixApp: App {
    @State private var dependencies = HibixApp.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
        }
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
