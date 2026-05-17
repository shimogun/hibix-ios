import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        Group {
            switch dependencies.onboardingDone {
            case .none:
                splash
            case .some(false):
                OnboardingFlow(dependencies: dependencies) {
                    dependencies.markOnboardingDone()
                }
            case .some(true):
                HomeView(dependencies: dependencies)
            }
        }
    }

    private var splash: some View {
        VStack {
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .accessibilityLabel("読み込み中")
    }
}
