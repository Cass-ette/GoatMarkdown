import Foundation
import XCTest
@testable import GoatMarkdown

final class BookmarkStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "BookmarkStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAddingBookmarkPersistsAcrossInstances() {
        let store = BookmarkStore(defaults: defaults)
        let bookmark = Bookmark(
            id: UUID(),
            blockIndex: 2,
            blockSignature: "heading-Intro",
            title: "Intro",
            preview: "Welcome",
            isDefault: false,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        store.add(bookmark, for: "/tmp/A.md")

        let reloaded = BookmarkStore(defaults: defaults)
        XCTAssertEqual(reloaded.bookmarks(for: "/tmp/A.md"), [bookmark])
    }

    func testSettingDefaultClearsPreviousDefaultInSameFile() {
        let store = BookmarkStore(defaults: defaults)
        let first = Bookmark.fixture(blockIndex: 1, isDefault: true)
        let second = Bookmark.fixture(blockIndex: 5, isDefault: false)
        store.add(first, for: "/tmp/A.md")
        store.add(second, for: "/tmp/A.md")

        store.setDefault(second.id, for: "/tmp/A.md")

        let stored = store.bookmarks(for: "/tmp/A.md")
        XCTAssertEqual(stored.filter(\.isDefault).map(\.id), [second.id])
    }

    func testRemovingBookmarkUpdatesPersistedList() {
        let store = BookmarkStore(defaults: defaults)
        let keep = Bookmark.fixture(blockIndex: 1)
        let drop = Bookmark.fixture(blockIndex: 9)
        store.add(keep, for: "/tmp/A.md")
        store.add(drop, for: "/tmp/A.md")

        store.remove(drop.id, for: "/tmp/A.md")

        XCTAssertEqual(store.bookmarks(for: "/tmp/A.md").map(\.id), [keep.id])
    }

    func testDefaultBookmarkLookup() {
        let store = BookmarkStore(defaults: defaults)
        let normal = Bookmark.fixture(blockIndex: 2, isDefault: false)
        let star = Bookmark.fixture(blockIndex: 3, isDefault: true)
        store.add(normal, for: "/tmp/A.md")
        store.add(star, for: "/tmp/A.md")

        XCTAssertEqual(store.defaultBookmark(for: "/tmp/A.md")?.id, star.id)
        XCTAssertNil(store.defaultBookmark(for: "/tmp/B.md"))
    }
}

private extension Bookmark {
    static func fixture(blockIndex: Int, isDefault: Bool = false) -> Bookmark {
        Bookmark(
            id: UUID(),
            blockIndex: blockIndex,
            blockSignature: "sig-\(blockIndex)",
            title: "Block \(blockIndex)",
            preview: "preview \(blockIndex)",
            isDefault: isDefault,
            createdAt: Date(timeIntervalSince1970: TimeInterval(blockIndex))
        )
    }
}
