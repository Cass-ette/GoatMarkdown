import SwiftUI

struct TagPillView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TagRegistry.shared.color(for: tag))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
