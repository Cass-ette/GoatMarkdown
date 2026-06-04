import SwiftUI

enum HighlightColor: String, Codable, CaseIterable, Equatable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.3)
        case .green: return Color.green.opacity(0.3)
        case .blue: return Color.blue.opacity(0.3)
        case .pink: return Color.pink.opacity(0.3)
        case .purple: return Color.purple.opacity(0.3)
        }
    }
}
