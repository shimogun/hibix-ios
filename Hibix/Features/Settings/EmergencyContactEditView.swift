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
            entitlement: dependencies.entitlementManager
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
                Section("メールアドレス") {
                    TextField("example@example.com", text: $bindable.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("ラベル (任意)") {
                    TextField("例: お母さん", text: $bindable.label)
                        .textInputAutocapitalization(.words)
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
}
