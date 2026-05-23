import SwiftUI
import XCTest
@testable import GoatMarkdown

final class GoatMarkdownTests: XCTestCase {
    func testThemeDefinesReadableBodySelectionTint() {
        XCTAssertEqual(MarkdownTheme().bodySelectionTint, .blue)
    }
}
