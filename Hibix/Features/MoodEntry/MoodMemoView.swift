import SwiftUI

struct MoodMemoView: View {
    let initialMemo: String?
    let mood: MoodLevel?
    let onSave: (String) async -> Void
    let onSkip: () -> Void

    @State private var text: String = ""
    @FocusState private var isEditorFocused: Bool

    private static let characterLimit: Int = MoodEntryRepository.memoCharacterLimit

    private var characterCount: Int { text.count }
    private var isOverLimit: Bool { characterCount > Self.characterLimit }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                moodBadge
                editor
                counter
            }
            .padding(16)
            .navigationTitle("今日のメモ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear {
                text = initialMemo ?? ""
                isEditorFocused = true
            }
        }
    }

    @ViewBuilder
    private var moodBadge: some View {
        if let mood {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.moodColor(for: mood))
                    .frame(width: 32, height: 32)
                Text(mood.displayName)
                    .font(.headline)
                Spacer()
            }
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .focused($isEditorFocused)
            .font(.body)
            .scrollContentBackground(.hidden)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(minHeight: 200)
            .accessibilityLabel("メモ入力")
    }

    private var counter: some View {
        HStack {
            Spacer()
            Text("\(characterCount) / \(Self.characterLimit)")
                .font(.caption)
                .foregroundStyle(isOverLimit ? .red : .secondary)
                .monospacedDigit()
                .accessibilityLabel("文字数 \(characterCount) / \(Self.characterLimit)")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("スキップ") {
                onSkip()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("保存") {
                Task { await onSave(text) }
            }
            .fontWeight(.semibold)
            .disabled(isOverLimit)
        }
    }
}

#Preview {
    MoodMemoView(initialMemo: "今日は穏やかな1日。",
                 mood: .good,
                 onSave: { _ in },
                 onSkip: {})
}
