import XCTest
@testable import TOONCore

final class ParserErrorDescriptionTests: XCTestCase {
    func testErrorDescriptionsCoverAllCases() {
        let unexpected = ParserError.unexpectedToken(line: 1, column: 2, expected: "value")
        XCTAssertEqual(unexpected.errorDescription, "Unexpected token at 1:2. Expected value.")

        let invalidLiteral = ParserError.invalidNumberLiteral("abc", line: 3, column: 4)
        XCTAssertEqual(invalidLiteral.errorDescription, "Invalid number literal 'abc' at 3:4.")

        let inlineMismatch = ParserError.inlineArrayLengthMismatch(expected: 2, actual: 3, line: 5, column: 6)
        XCTAssertEqual(inlineMismatch.errorDescription, "Array declared with 2 values but found 3 at 5:6.")

        let tabularMismatch = ParserError.tabularRowFieldMismatch(expected: 3, actual: 1, line: 7, column: 8)
        XCTAssertEqual(tabularMismatch.errorDescription, "Tabular row expected 3 fields but found 1 at 7:8.")
    }
}
