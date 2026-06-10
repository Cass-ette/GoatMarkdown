import Foundation

struct Bookmark: Equatable, Codable, Identifiable {
    let id: UUID
    var blockIndex: Int
    var blockSignature: String
    var title: String
    var preview: String
    var isDefault: Bool
    var createdAt: Date
    var tags: [String]

    init(
        id: UUID = UUID(),
        blockIndex: Int,
        blockSignature: String,
        title: String,
        preview: String,
        isDefault: Bool,
        createdAt: Date,
        tags: [String] = []
    ) {
        self.id = id
        self.blockIndex = blockIndex
        self.blockSignature = blockSignature
        self.title = title
        self.preview = preview
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.tags = tags
    }

    // Custom decoder to handle legacy data without tags
    private enum CodingKeys: String, CodingKey {
        case id, blockIndex, blockSignature, title, preview, isDefault, createdAt, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        blockIndex = try container.decode(Int.self, forKey: .blockIndex)
        blockSignature = try container.decode(String.self, forKey: .blockSignature)
        title = try container.decode(String.self, forKey: .title)
        preview = try container.decode(String.self, forKey: .preview)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

@Observable
final class BookmarkStore {
    private let defaults: UserDefaults
    private static let storageKey = "bookmarks.byFilePath.v1"

    private var byFilePath: [String: [Bookmark]] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: [Bookmark]].self, from: data) {
            byFilePath = decoded
        }
    }

    func bookmarks(for filePath: String) -> [Bookmark] {
        byFilePath[filePath] ?? []
    }

    func defaultBookmark(for filePath: String) -> Bookmark? {
        bookmarks(for: filePath).first(where: \.isDefault)
    }

    func add(_ bookmark: Bookmark, for filePath: String) {
        var list = byFilePath[filePath] ?? []
        if bookmark.isDefault {
            list = list.map { var copy = $0; copy.isDefault = false; return copy }
        }
        list.removeAll { $0.id == bookmark.id }
        list.append(bookmark)
        byFilePath[filePath] = list
        persist()
    }

    func setDefault(_ id: UUID, for filePath: String) {
        guard var list = byFilePath[filePath] else { return }
        list = list.map {
            var copy = $0
            copy.isDefault = (copy.id == id)
            return copy
        }
        byFilePath[filePath] = list
        persist()
    }

    func remove(_ id: UUID, for filePath: String) {
        guard var list = byFilePath[filePath] else { return }
        list.removeAll { $0.id == id }
        if list.isEmpty {
            byFilePath.removeValue(forKey: filePath)
        } else {
            byFilePath[filePath] = list
        }
        persist()
    }

    func updateTags(_ id: UUID, tags: [String], for filePath: String) {
        guard var list = byFilePath[filePath] else { return }
        guard let index = list.firstIndex(where: { $0.id == id }) else { return }
        list[index].tags = tags
        byFilePath[filePath] = list
        persist()
    }

    func allTags(for filePath: String) -> [String] {
        let bookmarks = byFilePath[filePath] ?? []
        let allTags = bookmarks.flatMap(\.tags)
        return Array(Set(allTags)).sorted()
    }

    func bookmarks(for filePath: String, withTag tag: String) -> [Bookmark] {
        let all = byFilePath[filePath] ?? []
        return all.filter { $0.tags.contains(tag) }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(byFilePath) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@Observable
final class HighlightStore {
    private let defaults: UserDefaults
    private static let storageKey = "highlights.byFilePath.v1"

    private var byFilePath: [String: [Highlight]] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([String: [Highlight]].self, from: data) {
            byFilePath = decoded
        }
    }

    func highlights(for filePath: String) -> [Highlight] {
        byFilePath[filePath] ?? []
    }

    func setHighlights(_ highlights: [Highlight], for filePath: String) {
        if highlights.isEmpty {
            byFilePath.removeValue(forKey: filePath)
        } else {
            byFilePath[filePath] = highlights
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(byFilePath) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
