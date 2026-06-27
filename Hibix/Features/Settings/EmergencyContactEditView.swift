import SwiftUI

/// 緊急連絡先の追加/編集フォーム。新規・編集を共通化。
struct EmergencyContactEditView: View {
    /// LINE 連携シート提示用の Identifiable ラッパ（localContactID）。
    private struct LineLinkTarget: Identifiable { let id: Int64 }

    @State private var viewModel: EmergencyContactEditViewModel
    @State private var lineLinkTarget: LineLinkTarget?
    private let makePaywallViewModel: () -> PaywallViewModel
    private let lineLinkService: LineLinkService
    let onSaved: () -> Void
    let onCancel: () -> Void
    let onDeleted: () -> Void

    init(mode: EmergencyContactEditViewModel.Mode,
         dependencies: AppDependencies,
         onSaved: @escaping () -> Void,
         onCancel: @escaping () -> Void,
         onDeleted: @escaping () -> Void) {
        _viewModel = State(initialValue: EmergencyContactEditViewModel(
            mode: mode,
            repo: dependencies.emergencyContactsRepository,
            entitlement: dependencies.entitlementManager,
            contactsSync: dependencies.contactsSyncService,
            settings: dependencies.settingsRepository
        ))
        let manager = dependencies.entitlementManager
        self.makePaywallViewModel = { PaywallViewModel(entitlement: manager) }
        self.lineLinkService = dependencies.lineLinkService
        self.onSaved = onSaved
        self.onCancel = onCancel
        self.onDeleted = onDeleted
    }

    var body: some View {
        @Bindable var bindable = viewModel
        NavigationStack {
            Form {
                Section("連絡種別") {
                    Picker("連絡種別", selection: $bindable.contactType) {
                        ForEach(ContactType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 120)
                    .accessibilityLabel("連絡種別を選択")
                }

                Section(viewModel.contactType.fieldLabel) {
                    TextField(viewModel.contactType.placeholder, text: $bindable.value)
                        .keyboardType(keyboardType(for: viewModel.contactType))
                        .textContentType(textContentType(for: viewModel.contactType))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if viewModel.contactType != .line {
                    Section("ラベル (任意)") {
                        TextField("例: お母さん", text: $bindable.label)
                            .textInputAutocapitalization(.words)
                    }
                }

                if viewModel.contactType == .line {
                    lineLinkSection
                }

                if let message = viewModel.saveErrorMessage {
                    Section {
                        Text(message)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                }

                if viewModel.isExisting {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                let ok = await viewModel.delete()
                                if ok { onDeleted() }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("この連絡先を削除")
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }
            }
            .navigationTitle(viewModel.isExisting ? "連絡先を編集" : "連絡先を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル", action: onCancel)
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task {
                            let ok = await viewModel.save()
                            if ok { onSaved() }
                        }
                    }
                    .disabled(!viewModel.isInputValid || viewModel.isSaving)
                }
            }
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
            .sheet(item: $lineLinkTarget, onDismiss: { onSaved() }) { target in
                LineLinkView(viewModel: LineLinkViewModel(service: lineLinkService,
                                                          localContactID: target.id))
            }
        }
    }

    @ViewBuilder
    private var lineLinkSection: some View {
        Section {
            if let contact = viewModel.editingContact, contact.lineLinkStatus == .linked {
                Label("連携済み", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                if let contact = viewModel.editingContact, contact.lineLinkStatus == .pending {
                    Label("連携待ち（コード送信待ち）", systemImage: "clock")
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        if let localID = await viewModel.prepareLineLink() {
                            lineLinkTarget = LineLinkTarget(id: localID)
                        }
                    }
                } label: {
                    Label("LINEで連携する", systemImage: "message.fill")
                }
                .disabled(viewModel.isSaving || !viewModel.isInputValid)
            }
        } header: {
            Text("LINE連携")
        } footer: {
            Text("LINE で受け取るには連携が必要です。相手に友だち追加とコードの送信をお願いします。")
        }
    }

    private func keyboardType(for type: ContactType) -> UIKeyboardType {
        switch type {
        case .email: return .emailAddress
        case .line:  return .default
        }
    }

    private func textContentType(for type: ContactType) -> UITextContentType? {
        switch type {
        case .email: return .emailAddress
        case .line:  return nil
        }
    }
}
