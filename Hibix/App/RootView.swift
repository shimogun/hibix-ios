import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.scenePhase) private var scenePhase

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
        .overlay {
            if dependencies.appLockManager.isLocked {
                AppLockOverlay(appLock: dependencies.appLockManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: dependencies.appLockManager.isLocked)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
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

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if dependencies.appLockManager.isLocked {
                Task { _ = await dependencies.appLockManager.authenticate() }
            }
        case .inactive, .background:
            dependencies.appLockManager.onEnterBackground()
        @unknown default:
            break
        }
    }
}

/// ロック中に上から被せる認証画面。コンテンツを完全に隠す。
private struct AppLockOverlay: View {
    @Bindable var appLock: AppLockManager

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Hibix")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("認証して開きます")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Button {
                    Task { _ = await appLock.authenticate() }
                } label: {
                    Text("認証する")
                        .frame(minWidth: 160, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                if let message = appLock.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
