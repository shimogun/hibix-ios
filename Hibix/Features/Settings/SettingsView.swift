import SwiftUI

/// PRD v2.2.0 §6 F-06/F-07/F-08/F-14。STEP6.1 ではフレーム + 購入復元のみ。
/// モード切替 / 緊急連絡先 / アプリロック の編集画面は STEP6.2-6.4 で接続。
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @Bindable private var entitlement: EntitlementManager
    let onDismiss: () -> Void

    private let dependencies: AppDependencies

    init(dependencies: AppDependencies, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: SettingsViewModel(
            settings: dependencies.settingsRepository,
            contacts: dependencies.emergencyContactsRepository,
            entitlement: dependencies.entitlementManager
        ))
        self.entitlement = dependencies.entitlementManager
        self.dependencies = dependencies
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            List {
                accountSection
                watchSection
                securitySection
                purchaseSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", action: onDismiss)
                }
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
            NavigationLink {
                EmergencyContactsView(dependencies: dependencies)
            } label: {
                HStack {
                    Text("緊急連絡先")
                    Spacer()
                    Text("\(viewModel.emergencyContactsCount) 件")
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
