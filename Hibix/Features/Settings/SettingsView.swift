import SwiftUI

/// PRD v2.2.0 §6 F-06/F-07/F-08/F-14。STEP6.1 ではフレーム + 購入復元のみ。
/// モード切替 / 緊急連絡先 / アプリロック の編集画面は STEP6.2-6.4 で接続。
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var isHelpPresented: Bool = false
    @State private var isPaywallPresented: Bool = false
    @Bindable private var entitlement: EntitlementManager
    @Environment(\.openURL) private var openURL
    let onDismiss: () -> Void

    private let dependencies: AppDependencies
    private let makePaywallViewModel: () -> PaywallViewModel

    init(dependencies: AppDependencies, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(
            settings: dependencies.settingsRepository,
            entitlement: dependencies.entitlementManager
        ))
        self.entitlement = dependencies.entitlementManager
        self.dependencies = dependencies
        let manager = dependencies.entitlementManager
        self.makePaywallViewModel = { PaywallViewModel(entitlement: manager) }
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                helpSection
                appearanceSection
                watchSection
                securitySection
                purchaseSection
                infoSection
                dangerSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onDismiss)
                }
            }
            .sheet(isPresented: $isHelpPresented) {
                OnboardingFlow(dependencies: dependencies, mode: .review, onClose: {
                    isHelpPresented = false
                })
            }
            .sheet(isPresented: $isPaywallPresented) {
                PaywallView(
                    viewModel: makePaywallViewModel(),
                    onPurchaseCompleted: { isPaywallPresented = false },
                    onDismiss: { isPaywallPresented = false }
                )
            }
            .task {
                await viewModel.load()
            }
            .onAppear {
                Task { await viewModel.load() }
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section("外観") {
            Picker("外観モード", selection: appearanceBinding) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { dependencies.appearanceManager.mode },
            set: { newMode in
                Task { await dependencies.appearanceManager.update(newMode) }
            }
        )
    }

    private var accountSection: some View {
        Section("アカウント") {
            HStack {
                Text(entitlement.isPro ? "Hibix Pro" : "無料プラン")
                Spacer()
                if entitlement.isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)

            if !entitlement.isPro {
                Button {
                    isPaywallPresented = true
                } label: {
                    HStack {
                        Label("Pro にアップグレード", systemImage: "sparkles")
                            .foregroundStyle(.tint)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityHint("7日間無料トライアルや購入プランを表示します")
            }
        }
    }

    private var helpSection: some View {
        Section {
            Button {
                isHelpPresented = true
            } label: {
                Label("使い方をもう一度見る", systemImage: "questionmark.circle")
            }
            .accessibilityHint("オンボーディングを最初から見直します")
        }
    }

    private var watchSection: some View {
        Section("見守り設定") {
            NavigationLink {
                ModeSwitchView(dependencies: dependencies)
            } label: {
                HStack {
                    Text("見守りモード")
                    Spacer()
                    Text(displayWatchMode(viewModel.watchMode))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var securitySection: some View {
        Section("セキュリティ") {
            NavigationLink {
                AppLockSettingsView(dependencies: dependencies)
            } label: {
                HStack {
                    Text("アプリロック")
                    Spacer()
                    Text(viewModel.appLockEnabled ? "オン" : "オフ")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var purchaseSection: some View {
        Section("購入") {
            Button {
                Task { await viewModel.restorePurchases() }
            } label: {
                HStack {
                    Text("購入を復元")
                    Spacer()
                    restoreIndicator
                }
            }
            .disabled(viewModel.restoreState == .restoring)

            if case .failed(let message) = viewModel.restoreState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var infoSection: some View {
        Section("情報") {
            Button {
                if let url = URL(string: "https://shimogun.com/tokushoho") {
                    openURL(url)
                }
            } label: {
                HStack {
                    Text("特定商取引法に基づく表記")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("外部ブラウザで特定商取引法に基づく表記を開きます")
        }
    }

    private var dangerSection: some View {
        Section("危険な操作") {
            NavigationLink {
                DataDeletionView(dependencies: dependencies)
            } label: {
                HStack {
                    Text("データを削除")
                        .foregroundStyle(.red)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityHint("アプリ内とサーバー上の全データを完全に削除します")
        }
    }

    @ViewBuilder
    private var restoreIndicator: some View {
        switch viewModel.restoreState {
        case .restoring:
            ProgressView()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        case .idle, .failed:
            EmptyView()
        }
    }

    private func placeholder(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func displayWatchMode(_ raw: String) -> String {
        switch raw {
        case "solo": return "おひとりさま"
        case "gentle": return "ゆるつながり"
        case "daily": return "まいにち共有"
        default: return "—"
        }
    }
}
