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
