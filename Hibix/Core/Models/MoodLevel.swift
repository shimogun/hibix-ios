import Foundation

nonisolated enum MoodLevel: Int, CaseIterable, Sendable {
    case down = 1
    case sink = 2
    case calm = 3
    case neutral = 4
    case good = 5
    case uplift = 6
    case best = 7

    var displayName: String {
        switch self {
        case .down:    return "落ち込み"
        case .sink:    return "沈み"
        case .calm:    return "平静"
        case .neutral: return "普通"
        case .good:    return "良い"
        case .uplift:  return "高揚"
        case .best:    return "最高"
        }
    }

    var accessibilityLabel: String {
        "気分\(rawValue)、\(displayName)"
    }
}
