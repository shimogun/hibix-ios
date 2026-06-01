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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .hibixWatercolorBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
                Image(mood.iconAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                Text(mood.displayName)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.hibixNavy)
                Spacer()
            }
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .focused($isEditorFocused)
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(Color.hibixNavy)
            .tint(Color.hibixNavy)
            .scrollContentBackground(.hidden)
            .padding(12)
            .frame(minHeight: 200)
            .hibixGlassCard(cornerRadius: 28)
            .accessibilityLabel("メモ入力")
    }

    private var counter: some View {
        HStack {
            Spacer()
            Text("\(characterCount) / \(Self.characterLimit)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isOverLimit ? Color.red : Color.hibixCounterText)
                .monospacedDigit()
                .accessibilityLabel("文字数 \(characterCount) / \(Self.characterLimit)")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("今日のメモ")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.hibixNavy)
        }
        ToolbarItem(placement: .topBarLeading) {
            Button {
                onSkip()
            } label: {
                pillLabel("戻る")
            }
            .buttonStyle(.plain)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Task { await onSave(text) }
            } label: {
                pillLabel("保存")
            }
            .buttonStyle(.plain)
            .disabled(isOverLimit)
        }
    }

    private func pillLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.hibixNavy)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .hibixRoundButton(cornerRadius: 18)
    }
}

#Preview {
    MoodMemoView(initialMemo: "今日は穏やかな1日。",
                 mood: .good,
                 onSave: { _ in },
                 onSkip: {})
}
