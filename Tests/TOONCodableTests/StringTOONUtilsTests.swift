import XCTest
@testable import TOONCodable

final class StringTOONUtilsTests: XCTestCase {
    
    // MARK: - indentString(count:) Tests
    
    func testIndentStringWithZeroReturnsEmpty() {
        let result = "".indentString(count: 0)
        XCTAssertEqual(result, "")
    }
    
    func testIndentStringWithNegativeReturnsEmpty() {
        let result = "".indentString(count: -5)
        XCTAssertEqual(result, "")
    }
    
    func testIndentStringWithOneSpace() {
        let result = "".indentString(count: 1)
        XCTAssertEqual(result, " ")
    }
    
    func testIndentStringWithFourSpaces() {
        let result = "".indentString(count: 4)
        XCTAssertEqual(result, "    ")
    }
    
    func testIndentStringWithLargeCount() {
        let result = "".indentString(count: 20)
        XCTAssertEqual(result, "                    ")
        XCTAssertEqual(result.count, 20)
    }
    
    // MARK: - stripIndent(count:) Tests
    
    func testStripIndentWithZeroReturnsOriginal() {
        let input = "  hello"
        let result = input.stripIndent(count: 0)
        XCTAssertEqual(result, "  hello")
    }
    
    func testStripIndentWithNegativeReturnsOriginal() {
        let input = "  hello"
        let result = input.stripIndent(count: -3)
        XCTAssertEqual(result, "  hello")
    }
    
    func testStripIndentRemovesLeadingSpaces() {
        let input = "    hello"
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "hello")
    }
    
    func testStripIndentPartialRemoval() {
        let input = "      world"
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "    world")
    }
    
    func testStripIndentMoreThanAvailable() {
        let input = "  text"
        let result = input.stripIndent(count: 10)
        XCTAssertEqual(result, "text")
    }
    
    func testStripIndentOnStringWithoutLeadingSpaces() {
        let input = "hello"
        let result = input.stripIndent(count: 5)
        XCTAssertEqual(result, "hello")
    }
    
    func testStripIndentEmptyString() {
        let input = ""
        let result = input.stripIndent(count: 5)
        XCTAssertEqual(result, "")
    }
    
    func testStripIndentOnlySpaces() {
        let input = "    "
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "  ")
    }
    
    func testStripIndentExactMatch() {
        let input = "   text"
        let result = input.stripIndent(count: 3)
        XCTAssertEqual(result, "text")
    }
    
    func testStripIndentPreservesTrailingSpaces() {
        let input = "  hello  "
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "hello  ")
    }
    
    func testStripIndentWithTabsStopsImmediately() {
        let input = "\t\thello"
        let result = input.stripIndent(count: 5)
        XCTAssertEqual(result, "\t\thello")
    }
    
    func testStripIndentMixedSpacesAndTabs() {
        let input = "  \thello"
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "\thello")
    }
    
    // MARK: - Edge Cases
    
    func testIndentStringWithMaxReasonableIndent() {
        let result = "".indentString(count: 100)
        XCTAssertEqual(result.count, 100)
        XCTAssertTrue(result.allSatisfy { $0 == " " })
    }
    
    func testStripIndentUnicodeString() {
        let input = "  café"
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "café")
    }
    
    func testStripIndentEmojiString() {
        let input = "    🚀 launch"
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "🚀 launch")
    }
}
