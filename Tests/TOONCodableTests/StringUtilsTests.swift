import XCTest
@testable import TOONCodable

final class StringUtilsTests: XCTestCase {
    
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
    
    func testIndentStringWithTwoSpaces() {
        let result = "".indentString(count: 2)
        XCTAssertEqual(result, "  ")
    }
    
    func testIndentStringWithFourSpaces() {
        let result = "".indentString(count: 4)
        XCTAssertEqual(result, "    ")
    }
    
    func testIndentStringWithLargeCount() {
        let result = "".indentString(count: 100)
        XCTAssertEqual(result.count, 100)
        XCTAssertTrue(result.allSatisfy { $0 == " " })
    }
    
    // MARK: - stripIndent(count:) Tests
    
    func testStripIndentWithZeroReturnsOriginal() {
        let input = "  hello"
        let result = input.stripIndent(count: 0)
        XCTAssertEqual(result, "  hello")
    }
    
    func testStripIndentWithNegativeReturnsOriginal() {
        let input = "  hello"
        let result = input.stripIndent(count: -5)
        XCTAssertEqual(result, "  hello")
    }
    
    func testStripIndentRemovesLeadingSpaces() {
        let input = "    hello"
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "hello")
    }
    
    func testStripIndentRemovesPartialLeadingSpaces() {
        let input = "    hello"
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "  hello")
    }
    
    func testStripIndentBeyondAvailableSpaces() {
        let input = "  hello"
        let result = input.stripIndent(count: 10)
        XCTAssertEqual(result, "hello")
    }
    
    func testStripIndentFromEmptyString() {
        let input = ""
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "")
    }
    
    func testStripIndentFromStringWithNoLeadingSpaces() {
        let input = "hello"
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "hello")
    }
    
    func testStripIndentFromStringWithOnlySpaces() {
        let input = "    "
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "  ")
    }
    
    func testStripIndentStopsAtNonSpace() {
        let input = "  \thello"
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "\thello")
    }
    
    func testStripIndentPreservesTrailingContent() {
        let input = "    hello world  "
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "hello world  ")
    }
    
    func testStripIndentWithExactMatch() {
        let input = "  "
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "")
    }
    
    // MARK: - Integration/Real-world scenarios
    
    func testIndentAndStripRoundTrip() {
        let original = "content"
        let indented = "".indentString(count: 4) + original
        XCTAssertEqual(indented, "    content")
        
        let stripped = indented.stripIndent(count: 4)
        XCTAssertEqual(stripped, original)
    }
    
    func testStripIndentWithMixedWhitespace() {
        let input = "  \n  text"
        let result = input.stripIndent(count: 2)
        XCTAssertEqual(result, "\n  text")
    }
    
    func testStripIndentPreservesInternalSpacing() {
        let input = "    key:  value"
        let result = input.stripIndent(count: 4)
        XCTAssertEqual(result, "key:  value")
    }
}
