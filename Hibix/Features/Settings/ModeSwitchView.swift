import SwiftUI

/// PRD v2.2.0 §6 F-06/F-07 見守り設定の統合画面。
///
/// 見守りモード選択に加え、「記録なし日数しきい値」と「緊急連絡先」を 1 画面で一括管理する。
/// `solo`(おひとりさま) 選択中は見守り通知が発生しないため、日数/連絡先セクションは無効化する。
struct ModeSwitchView: View {
    @State private var viewModel: ModeSwitchViewModel
    @State private var contactsViewModel: EmergencyContactsViewModel
    @Bindable private var entitlement: EntitlementManager
    private let dependencies: AppDependencies
    private let makePaywallViewModel: () -> PaywallViewModel

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: ModeSwitchViewModel(
            settings: dependencies.settingsRepository,
            entitlement: dependencies.entitlementManager
        ))
        _contactsViewModel = State(initialValue: EmergencyContactsViewModel(
            repo: dependencies.emergencyContactsRepository,
            contactsSync: dependencies.contactsSyncService
        ))
        self.entitlement = dependencies.entitlementManager
        self.dependencies = dependencies
        let manager = dependencies.entitlementManager
        self.makePaywallViewModel = { PaywallViewModel(entitlement: manager) }
    }

    var body: some View {
        @Bindable var bindable = viewModel
        List {
            modeSection
            selectedModeSection
            watchDaysSection
            contactsSection
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
            await contactsViewModel.load()
        }
    }

    // MARK: - モード選択

    private var modeSection: some View {
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
    }

    private var selectedModeSection: some View {
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

    // MARK: - 記録なし日数

    private var watchDaysSection: some View {
        Section {
            Picker("記録がない日数", selection: watchDaysBinding) {
                ForEach(ModeSwitchViewModel.watchDaysRange, id: \.self) { day in
                    Text("\(day)日").tag(day)
                }
            }
            .pickerStyle(.menu)
            .disabled(!viewModel.canEditWatchSettings)
        } header: {
            Text("記録なし日数")
        } footer: {
            if viewModel.canEditWatchSettings {
                Text("チェックインがこの日数だけ途絶えると、登録した緊急連絡先にお知らせが届きます。")
            } else {
                Text("見守りモードを選ぶと設定できます。")
            }
        }
    }

    private var watchDaysBinding: Binding<Int> {
        Binding(
            get: { viewModel.watchDays },
            set: { newValue in
                Task { await viewModel.setWatchDays(newValue) }
            }
        )
    }

    // MARK: - 緊急連絡先

    private var contactsSection: some View {
        @Bindable var contactsBindable = contactsViewModel
        return Group {
            Section {
                if contactsViewModel.contacts.isEmpty {
                    Text("登録されていません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(contactsViewModel.contacts) { contact in
                        Button {
                            contactsViewModel.presentEditSheet(contact)
                        } label: {
                            contactRow(for: contact)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        Task { await contactsViewModel.delete(at: offsets) }
                    }
                }

                Button {
                    contactsViewModel.presentAddSheet()
                } label: {
                    Label("緊急連絡先を追加", systemImage: "plus")
                }
                .disabled(!contactsViewModel.canAdd)
                .accessibilityLabel("緊急連絡先を追加")
            } header: {
                Text("緊急連絡先")
            } footer: {
                Text("最大 3 件まで登録できます。チェックインが途絶えたとき、登録した連絡先にお知らせが届きます。")
            }
            .disabled(!viewModel.canEditWatchSettings)

            if let message = contactsViewModel.lastErrorMessage {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .sheet(item: $contactsBindable.editingTarget) { target in
            EmergencyContactEditView(
                mode: target.editMode,
                dependencies: dependencies,
                onSaved: {
                    contactsViewModel.dismissEditSheet()
                    Task { await contactsViewModel.load() }
                },
                onCancel: {
                    contactsViewModel.dismissEditSheet()
                },
                onDeleted: {
                    contactsViewModel.dismissEditSheet()
                    Task { await contactsViewModel.load() }
                }
            )
        }
    }

    private func contactRow(for contact: EmergencyContact) -> some View {
        HStack(spacing: 12) {
            Image(systemName: contact.contactType.iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.label?.isEmpty == false ? (contact.label ?? "") : "(ラベルなし)")
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(contact.email)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(contact.contactType.displayName) \(contact.displayTitle)")
    }

    // MARK: - モード行

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

private extension EmergencyContactsViewModel.EditingTarget {
    var editMode: EmergencyContactEditViewModel.Mode {
        switch self {
        case .new: return .new
        case .existing(let contact): return .existing(contact)
        }
    }
}
