import SwiftUI

final class TagRegistry {
    static let shared = TagRegistry()

    private init() {}

    func color(for tag: String) -> Color {
        let hash = stableHash(tag)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.75)
    }

    private func stableHash(_ string: String) -> UInt {
        // FNV-1a hash for stability across runs
        var hash: UInt = 14695981039346656037
        for byte in string.utf8 {
            hash ^= UInt(byte)
            hash &*= 1099511628211
        }
        return hash
    }
}
