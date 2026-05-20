import AppKit
import SwiftUI

struct MarkdownTheme {
    var bodyFontScale: Double = 1.0
    var bodyColor: Color = .primary
    var headingFonts: [Int: Font] = [
        1: .title, 2: .title2, 3: .title3,
        4: .headline, 5: .headline, 6: .headline
    ]
    var headingColor: Color = .primary
    var codeFont: Font = .system(.body, design: .monospaced)
    var codeBackgroundColor: Color = Color(nsColor: .textBackgroundColor).opacity(0.8)
    var quoteColor: Color = .secondary
    var quoteBarColor: Color = .accentColor
    var hrColor: Color = Color(nsColor: .separatorColor)
    var listItemBullet: String = "\u{2022}"
    var contentMaxWidth: CGFloat? = 800
    var contentPadding: CGFloat = 24

    var bodyFont: Font { .system(size: NSFont.systemFontSize * bodyFontScale) }
    var bodyCaptionFont: Font { .system(size: NSFont.smallSystemFontSize * bodyFontScale) }
    var bodySubheadlineFont: Font { .system(size: NSFont.systemFontSize(for: .small) * bodyFontScale) }
    var bodyMonospacedFont: Font { .system(size: NSFont.systemFontSize * bodyFontScale, design: .monospaced) }
}
