import SwiftUI
import UIKit

struct MoodPickerView: View {
    let selected: MoodLevel?
    let onSelect: (MoodLevel) -> Void

    private static let buttonCount: Int = MoodLevel.allCases.count
    private static let maxDiameter: CGFloat = 56
    private static let minDiameter: CGFloat = 44
    private static let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let totalSpacing = Self.spacing * CGFloat(Self.buttonCount - 1)
            let perButton = (proxy.size.width - totalSpacing) / CGFloat(Self.buttonCount)
            let diameter = min(Self.maxDiameter, max(Self.minDiameter, perButton))
            HStack(spacing: Self.spacing) {
                ForEach(MoodLevel.allCases, id: \.self) { level in
                    MoodPickerButton(level: level,
                                     isSelected: selected == level,
                                     diameter: diameter,
                                     onTap: { onSelect(level) })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: Self.maxDiameter)
        .accessibilityElement(children: .contain)
    }
}

private struct MoodPickerButton: View {
    let level: MoodLevel
    let isSelected: Bool
    let diameter: CGFloat
    let onTap: () -> Void

    private static let selectionStrokeWidth: CGFloat = 3

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTap()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.moodColor(for: level))
                Circle()
                    .strokeBorder(Color.primary, lineWidth: isSelected ? Self.selectionStrokeWidth : 0)
            }
            .frame(width: diameter, height: diameter)
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(.easeOut(duration: 0.1), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.accessibilityLabel)
        .accessibilityHint("タップして今日の気分を記録")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var selected: MoodLevel? = .good
    return MoodPickerView(selected: selected) { level in
        selected = level
    }
    .padding()
}
