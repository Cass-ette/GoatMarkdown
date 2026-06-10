import Foundation

@Observable
final class HighlightState {
    private(set) var highlights: [Highlight] = []

    func add(_ highlight: Highlight) {
        highlights.removeAll { $0.id == highlight.id }
        highlights.append(highlight)
    }

    func remove(id: UUID) {
        highlights.removeAll { $0.id == id }
    }

    func find(blockIndex: Int, textIndex: Int, range: Range<Int>) -> Highlight? {
        highlights.first { existing in
            existing.blockIndex == blockIndex
            && existing.textIndex == textIndex
            && existing.rangeStart < range.upperBound
            && existing.rangeEnd > range.lowerBound
        }
    }

    func toggle(blockIndex: Int, textIndex: Int, range: Range<Int>, color: HighlightColor = .yellow) -> Highlight? {
        if let existing = find(blockIndex: blockIndex, textIndex: textIndex, range: range) {
            remove(id: existing.id)
            return nil
        }
        let new = Highlight(
            blockIndex: blockIndex,
            textIndex: textIndex,
            rangeStart: range.lowerBound,
            rangeEnd: range.upperBound,
            color: color
        )
        add(new)
        return new
    }

    func highlights(in blockIndex: Int, textIndex: Int) -> [Highlight] {
        highlights.filter { $0.blockIndex == blockIndex && $0.textIndex == textIndex }
    }

    func load(_ items: [Highlight]) {
        highlights = items
    }

    func updateNote(id: UUID, note: String?) {
        guard let index = highlights.firstIndex(where: { $0.id == id }) else { return }
        highlights[index].note = note
    }
}
