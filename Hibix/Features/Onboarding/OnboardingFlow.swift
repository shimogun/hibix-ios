import StoreKit
import SwiftUI
import os.log

struct OnboardingFlow: View {
    let dependencies: AppDependencies
    let mode: OnboardingViewModel.Mode
    let onCompleted: () -> Void
    let onClose: () -> Void

    @State private var viewModel: OnboardingViewModel
    @State private var pageIndex: Int = 0
    /// Pro ページの動的価格。StoreKit 取得成功時のみ非 nil。
    @State private var proPricing: OnboardingProPricing?

    private static let logger = Logger(subsystem: "com.shimogun.hibix", category: "Onboarding")
    /// firstRun=9ページ(0..8) / review=8ページ(0..7、開始ページ⑨を除外)
    private var pageCount: Int { mode == .review ? 8 : 9 }
    private var isLastPage: Bool { pageIndex == pageCount - 1 }

    init(dependencies: AppDependencies,
         mode: OnboardingViewModel.Mode = .firstRun,
         onCompleted: @escaping () -> Void = {},
         onClose: @escaping () -> Void = {}) {
        self.dependencies = dependencies
        self.mode = mode
        self.onCompleted = onCompleted
        self.onClose = onClose

        let settings = dependencies.settingsRepository
        let entitlement = dependencies.entitlementManager
        let scheduler = dependencies.notificationScheduler
        let complete = onCompleted
        _viewModel = State(initialValue: OnboardingViewModel(
            mode: mode,
            isPro: { entitlement.isPro },
            saveMode: { selected in
                do {
                    try await settings.setString(selected.rawValue, forKey: .watchMode, now: Date())
                } catch {
                    OnboardingFlow.logger.error("watch_mode write failed: \(error.localizedDescription, privacy: .public)")
                }
            },
            requestNotifications: {
                let granted = await scheduler.requestAuthorization()
                if granted { await scheduler.rescheduleDailyNotifications() }
            },
            markComplete: {
                do {
                    try await settings.setBool(true, forKey: .onboardingDone, now: Date())
                } catch {
                    OnboardingFlow.logger.error("onboarding_done write failed: \(error.localizedDescription, privacy: .public)")
                }
                complete()
            }
        ))
    }

    var body: some View {
        @Bindable var bindable = viewModel
        VStack(spacing: 16) {
            if mode == .review {
                HStack {
                    Spacer()
                    Button("閉じる") { onClose() }
                        .fontWeight(.semibold)
                        .tint(Color.hibixNavy)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }
            }

            TabView(selection: $pageIndex) {
                OnboardingConceptPage().tag(0)
                OnboardingMoodPage().tag(1)
                OnboardingCalendarPage().tag(2)
                OnboardingWatchModePage().tag(3)
                OnboardingSafetyPage().tag(4)
                OnboardingPrivacyPage().tag(5)
                OnboardingAppLockPage().tag(6)
                OnboardingProPage(pricing: proPricing).tag(7)
                if mode != .review {
                    OnboardingStartPage(onSelectMode: { selected in
                        Task { await viewModel.selectStartMode(selected) }
                    })
                    .tag(8)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: pageIndex)

            pagination

            if !isLastPage {
                Button(action: advance) {
                    Text("次へ")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.hibixNavy)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .hibixRoundButton(cornerRadius: 25)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hibixWatercolorBackground()
        .task {
            await loadProPricing()
        }
        .sheet(isPresented: $bindable.isPaywallPresented) {
            PaywallView(
                entitlement: dependencies.entitlementManager,
                onPurchaseCompleted: {
                    Task { await viewModel.handlePurchaseCompleted() }
                },
                onDismiss: {
                    Task { await viewModel.handlePaywallDismissedWithoutPurchase() }
                }
            )
            .interactiveDismissDisabled()
        }
    }

    private var pagination: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? Color.hibixNavy : Color.hibixPeriwinkle.opacity(0.35))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
    }

    private func advance() {
        guard pageIndex < pageCount - 1 else { return }
        pageIndex += 1
    }

    /// StoreKit から Pro ページ用の価格を取得する。失敗時は nil のままフォールバック文言。
    private func loadProPricing() async {
        guard proPricing == nil else { return }
        do {
            let products = try await Product.products(for: Array(StoreKitProduct.allIDs))
            guard let monthly = products.first(where: { $0.id == StoreKitProduct.proMonthlyID }),
                  let lifetime = products.first(where: { $0.id == StoreKitProduct.proLifetimeID }) else {
                return
            }
            proPricing = OnboardingProPricing(
                monthlyPrice: monthly.displayPrice,
                lifetimePrice: lifetime.displayPrice
            )
        } catch {
            OnboardingFlow.logger.error("Pro pricing fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
