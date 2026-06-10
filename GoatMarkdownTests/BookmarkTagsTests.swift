import Foundation
import XCTest
@testable import GoatMarkdown

final class BookmarkTagsTests: XCTestCase {
    func testBookmarkDefaultsToEmptyTags() {
        let b = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "Test", preview: "preview", isDefault: false, createdAt: Date()
        )
        XCTAssertEqual(b.tags, [])
    }

    func testBookmarkStoresTags() {
        let b = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "Test", preview: "preview", isDefault: false, createdAt: Date(),
            tags: ["important", "todo"]
        )
        XCTAssertEqual(b.tags, ["important", "todo"])
    }

    func testBookmarkTagsRoundTripCodable() throws {
        let original = Bookmark(
            id: UUID(), blockIndex: 1, blockSignature: "sig-1",
            title: "Heading", preview: "text", isDefault: false, createdAt: Date(),
            tags: ["review", "chapter1"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Bookmark.self, from: data)
        XCTAssertEqual(decoded.tags, ["review", "chapter1"])
    }

    func testBookmarkWithoutTagsDecodesFromLegacyData() throws {
        let legacy = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "Old", preview: "p", isDefault: false, createdAt: Date()
        )
        let data = try JSONEncoder().encode(legacy)
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "tags")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Bookmark.self, from: legacyData)
        XCTAssertEqual(decoded.tags, [])
    }
}

final class BookmarkStoreTagTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "BookmarkStoreTagTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testUpdateTagsPersists() {
        let store = BookmarkStore(defaults: defaults)
        let bookmark = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig",
            title: "T", preview: "p", isDefault: false, createdAt: Date()
        )
        store.add(bookmark, for: "/tmp/A.md")
        store.updateTags(bookmark.id, tags: ["important", "review"], for: "/tmp/A.md")

        let stored = store.bookmarks(for: "/tmp/A.md").first
        XCTAssertEqual(stored?.tags, ["important", "review"])
    }

    func testAllTagsReturnsUniqueTags() {
        let store = BookmarkStore(defaults: defaults)
        let b1 = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig-0",
            title: "A", preview: "", isDefault: false, createdAt: Date(), tags: ["foo", "bar"]
        )
        let b2 = Bookmark(
            id: UUID(), blockIndex: 1, blockSignature: "sig-1",
            title: "B", preview: "", isDefault: false, createdAt: Date(), tags: ["bar", "baz"]
        )
        store.add(b1, for: "/tmp/A.md")
        store.add(b2, for: "/tmp/A.md")

        let allTags = store.allTags(for: "/tmp/A.md")
        XCTAssertEqual(Set(allTags), Set(["foo", "bar", "baz"]))
    }

    func testFilterBookmarksByTag() {
        let store = BookmarkStore(defaults: defaults)
        let b1 = Bookmark(
            id: UUID(), blockIndex: 0, blockSignature: "sig-0",
            title: "A", preview: "", isDefault: false, createdAt: Date(), tags: ["important"]
        )
        let b2 = Bookmark(
            id: UUID(), blockIndex: 1, blockSignature: "sig-1",
            title: "B", preview: "", isDefault: false, createdAt: Date(), tags: ["todo"]
        )
        store.add(b1, for: "/tmp/A.md")
        store.add(b2, for: "/tmp/A.md")

        let filtered = store.bookmarks(for: "/tmp/A.md", withTag: "important")
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "A")
    }
}
