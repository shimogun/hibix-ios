import SwiftUI

/// PRD v2.2.0 §6 F-06 見守りモード切替画面。
struct ModeSwitchView: View {
    @State private var viewModel: ModeSwitchViewModel
    @Bindable private var entitlement: EntitlementManager
    private let makePaywallViewModel: () -> PaywallViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: ModeSwitchViewModel(
            settings: dependencies.settingsRepository,
            entitlement: dependencies.entitlementManager
        ))
        self.entitlement = dependencies.entitlementManager
        let manager = dependencies.entitlementManager
        self.makePaywallViewModel = { PaywallViewModel(entitlement: manager) }
    }

    var body: some View {
        @Bindable var bindable = viewModel
        List {
            Section {
                ForEach(WatchMode.allCases) { mode in
                    row(for: mode)
                }
            } footer: {
                if !entitlement.isPro {
                    Text("「ゆるつながり」「まいにち共有」は Hibix Pro で利用できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("選択中のモード") {
                Text(viewModel.selectedMode.description)
                    .font(.body)
                if viewModel.selectedMode == .daily {
                    Text("※「まいにち共有」の毎日通知は次期アップデート予定です(現状は『ゆるつながり』と同じ動作)。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("見守りモード")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $bindable.isPaywallPresented) {
            PaywallView(
                viewModel: makePaywallViewModel(),
                onPurchaseCompleted: {
                    viewModel.isPaywallPresented = false
                },
                onDismiss: {
                    viewModel.isPaywallPresented = false
                }
            )
        }
        .task {
            await viewModel.load()
        }
    }

    private func row(for mode: WatchMode) -> some View {
        Button {
            Task { await viewModel.select(mode) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(viewModel.selectedMode == mode ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.displayName)
                        .foregroundStyle(.primary)
                }
                Spacer()
                if !entitlement.isPro && mode.requiresPro {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: mode))
        .accessibilityAddTraits(viewModel.selectedMode == mode ? [.isSelected, .isButton] : .isButton)
    }

    private func accessibilityLabel(for mode: WatchMode) -> String {
        let lock = (!entitlement.isPro && mode.requiresPro) ? "、Pro 限定" : ""
        let selected = viewModel.selectedMode == mode ? "、選択中" : ""
        return "\(mode.displayName)\(lock)\(selected)"
    }
}
