import SwiftUI

enum MoodEmojiPalette {
    static func emojis(for level: MoodLevel) -> [String] {
        switch level {
        case .down:    return ["😔", "😟", "🌧️", "💧", "🥀", "☁️"]
        case .calm:    return ["🕊️", "😌", "🍃", "🌫️", "🍵", "📖"]
        case .neutral: return ["🙂", "😐", "☕", "💭", "🚶", "📚"]
        case .good:    return ["😊", "☀️", "🌻", "🍀", "✨", "😄"]
        case .best:    return ["🤩", "🎉", "🌈", "🎆", "⭐", "💯"]
        }
    }
}

struct MoodEmojiPaletteView: View {
    let level: MoodLevel
    let onSelect: (String) -> Void

    private static let buttonSize: CGFloat = 44
    private static let spacing: CGFloat = 6

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Self.spacing) {
                ForEach(MoodEmojiPalette.emojis(for: level), id: \.self) { emoji in
                    Button {
                        onSelect(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 24))
                            .frame(width: Self.buttonSize, height: Self.buttonSize)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("絵文字 \(emoji) を挿入")
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(height: Self.buttonSize + 4)
    }
}
