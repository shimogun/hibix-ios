import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        HomeView(dependencies: dependencies)
    }
}
