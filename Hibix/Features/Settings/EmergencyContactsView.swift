import SwiftUI

/// PRD v2.2.0 §6 F-07 緊急連絡先一覧。最大 3 件、追加/編集は保存時に Pro 判定。
struct EmergencyContactsView: View {
    @State private var viewModel: EmergencyContactsViewModel
    @Bindable private var entitlement: EntitlementManager
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        _viewModel = State(initialValue: EmergencyContactsViewModel(
            repo: dependencies.emergencyContactsRepository
        ))
        self.entitlement = dependencies.entitlementManager
        self.dependencies = dependencies
    }

    var body: some View {
        @Bindable var bindable = viewModel
        List {
            Section {
                if viewModel.contacts.isEmpty {
                    Text("登録されていません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.contacts) { contact in
                        Button {
                            viewModel.presentEditSheet(contact)
                        } label: {
                            row(for: contact)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        Task { await viewModel.delete(at: offsets) }
                    }
                }
            } footer: {
                Text("最大 3 件まで登録できます。「ゆるつながり」「まいにち共有」モードでチェックインが途絶えたとき、登録メールアドレスにお知らせが届きます。")
            }

            if !entitlement.isPro {
                Section {
                    Label("追加・編集は Hibix Pro で利用できます", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = viewModel.lastErrorMessage {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("緊急連絡先")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.presentAddSheet()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!viewModel.canAdd)
                .accessibilityLabel("緊急連絡先を追加")
            }
        }
        .sheet(item: $bindable.editingTarget) { target in
            EmergencyContactEditView(
                mode: target.editMode,
                dependencies: dependencies,
                onSaved: {
                    viewModel.dismissEditSheet()
                    Task { await viewModel.load() }
                },
                onCancel: {
                    viewModel.dismissEditSheet()
                },
                onDeleted: {
                    viewModel.dismissEditSheet()
                    Task { await viewModel.load() }
                }
            )
        }
        .task {
            await viewModel.load()
        }
    }

    private func row(for contact: EmergencyContact) -> some View {
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
}

private extension EmergencyContactsViewModel.EditingTarget {
    var editMode: EmergencyContactEditViewModel.Mode {
        switch self {
        case .new: return .new
        case .existing(let contact): return .existing(contact)
        }
    }
}
