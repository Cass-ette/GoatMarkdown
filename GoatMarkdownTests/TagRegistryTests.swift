import Foundation
import XCTest
import SwiftUI
@testable import GoatMarkdown

final class TagRegistryTests: XCTestCase {
    func testColorForTagIsStable() {
        let color1 = TagRegistry.shared.color(for: "important")
        let color2 = TagRegistry.shared.color(for: "important")
        XCTAssertEqual(color1, color2)
    }

    func testDifferentTagsProduceDifferentColors() {
        let c1 = TagRegistry.shared.color(for: "important")
        let c2 = TagRegistry.shared.color(for: "todo")
        XCTAssertNotEqual(c1, c2)
    }

    func testEmptyTagReturnsColor() {
        let color = TagRegistry.shared.color(for: "")
        // Should not crash, returns some color
        XCTAssertNotNil(color)
    }
}
