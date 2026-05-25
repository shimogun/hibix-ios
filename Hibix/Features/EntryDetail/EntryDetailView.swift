import SwiftUI

struct EntryDetailView: View {
    let date: String
    let viewModel: HomeViewModel

    @State private var isEditing: Bool = false
    @State private var editedLevel: MoodLevel?
    @State private var editedMemo: String = ""

    private static let characterLimit: Int = MoodEntryRepository.memoCharacterLimit

    private var existingEntry: MoodEntry? {
        viewModel.calendarEntries[date]
    }

    private var isOverLimit: Bool {
        editedMemo.count > Self.characterLimit
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isEditing {
                    editorSection
                } else if let entry = existingEntry {
                    displaySection(entry: entry)
                } else {
                    emptyStateSection
                }
                if let lastErrorMessage = viewModel.lastErrorMessage {
                    Text(lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear { hydrateFromEntry() }
    }

    @ViewBuilder
    private func displaySection(entry: MoodEntry) -> some View {
        VStack(alignment: .center, spacing: 16) {
            if let mood = entry.mood {
                Image(mood.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                Text(mood.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .frame(maxWidth: .infinity)
        VStack(alignment: .leading, spacing: 8) {
            Text("メモ")
                .font(.headline)
                .foregroundStyle(.secondary)
            if let memo = entry.memo, !memo.isEmpty {
                Text(memo)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("メモは未入力です")
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Text("記録なし")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button {
                editedLevel = .neutral
                editedMemo = ""
                isEditing = true
            } label: {
                Text("今この日に記録する")
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(date > HibixDate.todayString())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var editorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("気分").font(.headline)
                MoodPickerView(selected: editedLevel) { level in
                    editedLevel = level
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("メモ").font(.headline)
                TextEditor(text: $editedMemo)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("メモ入力")
                HStack {
                    Spacer()
                    Text("\(editedMemo.count) / \(Self.characterLimit)")
                        .font(.caption)
                        .foregroundStyle(isOverLimit ? .red : .secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isEditing {
                Button("保存") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .disabled(editedLevel == nil || isOverLimit)
            } else if existingEntry != nil {
                Button("編集") {
                    hydrateFromEntry()
                    isEditing = true
                }
            }
        }
        if isEditing && existingEntry != nil {
            ToolbarItem(placement: .topBarLeading) {
                Button("キャンセル") {
                    hydrateFromEntry()
                    isEditing = false
                }
            }
        }
    }

    private func hydrateFromEntry() {
        editedLevel = existingEntry?.mood
        editedMemo = existingEntry?.memo ?? ""
    }

    private func save() async {
        guard let level = editedLevel else { return }
        await viewModel.editEntry(date: date, level: level, memo: editedMemo)
        if viewModel.lastErrorMessage == nil {
            isEditing = false
        }
    }

    private var formattedDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.calendar = Calendar(identifier: .gregorian)
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "en_US_POSIX")
        guard let parsedDate = inputFormatter.date(from: date) else { return date }
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ja_JP")
        outputFormatter.dateFormat = "M月d日 (E)"
        return outputFormatter.string(from: parsedDate)
    }
}
