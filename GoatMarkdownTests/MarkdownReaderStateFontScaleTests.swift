import Foundation
import XCTest
@testable import GoatMarkdown

final class MarkdownReaderStateFontScaleTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MarkdownReaderStateFontScaleTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBodyFontScaleDefaultsToOne() {
        let state = MarkdownReaderState(defaults: defaults)
        XCTAssertEqual(state.bodyFontScale, 1.0)
    }

    func testIncreasingAndDecreasingBodyFontScaleClampsAndPersists() {
        let state = MarkdownReaderState(defaults: defaults)

        state.increaseBodyFontScale()
        state.increaseBodyFontScale()
        XCTAssertEqual(state.bodyFontScale, 1.2, accuracy: 0.0001)

        state.decreaseBodyFontScale()
        XCTAssertEqual(state.bodyFontScale, 1.1, accuracy: 0.0001)

        let reloaded = MarkdownReaderState(defaults: defaults)
        XCTAssertEqual(reloaded.bodyFontScale, 1.1, accuracy: 0.0001)
    }

    func testBodyFontScaleDoesNotExceedBounds() {
        let state = MarkdownReaderState(defaults: defaults)

        for _ in 0..<30 { state.increaseBodyFontScale() }
        XCTAssertLessThanOrEqual(state.bodyFontScale, 1.8)

        for _ in 0..<50 { state.decreaseBodyFontScale() }
        XCTAssertGreaterThanOrEqual(state.bodyFontScale, 0.8)
    }
}
