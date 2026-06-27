import SwiftUI

/// 緊急連絡先の追加/編集フォーム。新規・編集を共通化。
struct EmergencyContactEditView: View {
    @State private var viewModel: EmergencyContactEditViewModel
    private let makePaywallViewModel: () -> PaywallViewModel
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
            contactsSync: dependencies.contactsSyncService
        ))
        let manager = dependencies.entitlementManager
        self.makePaywallViewModel = { PaywallViewModel(entitlement: manager) }
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

                Section("ラベル (任意)") {
                    TextField("例: お母さん", text: $bindable.label)
                        .textInputAutocapitalization(.words)
                }

                if !viewModel.contactType.isDeliveredInV01 {
                    Section {
                        Label {
                            Text("\(viewModel.contactType.displayName) 種別は登録のみで、実際の通知送信は v1.1 で対応予定です。現在はメール宛のみ即時送信されます。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
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
