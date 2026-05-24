import SwiftUI

extension Color {
    static func moodColor(for level: MoodLevel) -> Color {
        switch level {
        case .down:    return Color(moodHex: 0x4A5568)
        case .calm:    return Color(moodHex: 0x38B2AC)
        case .neutral: return Color(moodHex: 0xECC94B)
        case .good:    return Color(moodHex: 0xF687B3)
        case .best:    return Color(moodHex: 0xED8936)
        }
    }

    static var moodEmptyCell: Color { Color(moodHex: 0xE5E7EB) }

    fileprivate init(moodHex hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
