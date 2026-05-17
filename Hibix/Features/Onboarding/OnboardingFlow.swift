import SwiftUI
import os.log

struct OnboardingFlow: View {
    let dependencies: AppDependencies
    let onCompleted: () -> Void

    @State private var pageIndex: Int = 0
    @State private var isRequestingAuthorization: Bool = false
    @State private var didDecideAuthorization: Bool = false
    @State private var authorizationGranted: Bool = false
    @State private var isFinishing: Bool = false

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Onboarding")
    private static let pageCount: Int = 3

    var body: some View {
        VStack(spacing: 16) {
            TabView(selection: $pageIndex) {
                OnboardingConceptPage()
                    .tag(0)
                OnboardingWatchPage()
                    .tag(1)
                OnboardingPermissionPage(
                    isRequestingAuthorization: isRequestingAuthorization,
                    didDecideAuthorization: didDecideAuthorization,
                    authorizationGranted: authorizationGranted,
                    onAllow: { Task { await requestAuthorization() } },
                    onSkip: { skipAuthorization() },
                    onStart: { Task { await finish() } }
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: pageIndex)

            pagination

            if pageIndex < Self.pageCount - 1 {
                Button(action: advance) {
                    Text("次へ")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 24)
    }

    private var pagination: some View {
        HStack(spacing: 8) {
            ForEach(0..<Self.pageCount, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private func advance() {
        guard pageIndex < Self.pageCount - 1 else { return }
        pageIndex += 1
    }

    private func requestAuthorization() async {
        guard !isRequestingAuthorization else { return }
        isRequestingAuthorization = true
        let granted = await dependencies.notificationScheduler.requestAuthorization()
        authorizationGranted = granted
        didDecideAuthorization = true
        isRequestingAuthorization = false
        if granted {
            await dependencies.notificationScheduler.rescheduleDailyNotifications()
        }
    }

    private func skipAuthorization() {
        authorizationGranted = false
        didDecideAuthorization = true
    }

    private func finish() async {
        guard !isFinishing else { return }
        isFinishing = true
        do {
            try await dependencies.settingsRepository.setBool(true, forKey: .onboardingDone)
        } catch {
            Self.logger.error("onboarding_done write failed: \(error.localizedDescription, privacy: .public)")
        }
        onCompleted()
    }
}
