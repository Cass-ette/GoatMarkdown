import SwiftUI

struct MarkdownRenderer: View {
    let document: MarkdownDocument
    var theme: MarkdownTheme = MarkdownTheme()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                    renderBlock(block)
                }
            }
            .frame(maxWidth: theme.contentMaxWidth)
            .padding(theme.contentPadding)
        }
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(theme.headingFonts[level] ?? .headline)
                .foregroundStyle(theme.headingColor)

        case .paragraph(let text):
            Text(text)
                .font(theme.bodyFont)
                .foregroundStyle(theme.bodyColor)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(theme.listItemBullet)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                        Text(item)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                    }
                }
            }

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                            .frame(width: 28, alignment: .trailing)
                        Text(item)
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.bodyColor)
                    }
                }
            }

        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.quoteBarColor)
                    .frame(width: 4)
                Text(text)
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.quoteColor)
                    .padding(.leading, 12)
                    .padding(.vertical, 4)
            }

        case .codeBlock(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let language {
                    Text(language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
                Text(code)
                    .font(theme.codeFont)
                    .foregroundStyle(theme.bodyColor)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.codeBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))

        case .thematicBreak:
            Divider()
                .background(theme.hrColor)
                .padding(.vertical, 4)
        }
    }
}
