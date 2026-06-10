import Foundation

struct Highlight: Equatable, Codable, Identifiable {
    let id: UUID
    let blockIndex: Int
    let textIndex: Int
    let rangeStart: Int
    let rangeEnd: Int
    let color: HighlightColor
    let createdAt: Date
    var note: String?

    init(
        id: UUID = UUID(),
        blockIndex: Int,
        textIndex: Int,
        rangeStart: Int,
        rangeEnd: Int,
        color: HighlightColor,
        createdAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.blockIndex = blockIndex
        self.textIndex = textIndex
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.color = color
        self.createdAt = createdAt
        self.note = note
    }
}
