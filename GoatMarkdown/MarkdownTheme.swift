import SwiftUI

struct MarkdownTheme {
    var bodyFont: Font = .body
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
}
