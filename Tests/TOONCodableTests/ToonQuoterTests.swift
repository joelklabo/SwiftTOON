import XCTest
@testable import TOONCodable

final class ToonQuoterTests: XCTestCase {
    func testLeavesSafeStringsUnquoted() {
        XCTAssertEqual(ToonQuoter.encode("alpha"), "alpha")
        XCTAssertEqual(ToonQuoter.encode("User_01"), "User_01")
    }

    func testQuotesWhitespaceSensitiveValues() {
        XCTAssertEqual(ToonQuoter.encode(" beta"), "\" beta\"")
        XCTAssertEqual(ToonQuoter.encode("beta "), "\"beta \"")
    }

    func testQuotesEmptyString() {
        XCTAssertEqual(ToonQuoter.encode(""), "\"\"")
    }

    func testQuotesStringsContainingDelimiter() {
        XCTAssertEqual(ToonQuoter.encode("a,b"), "\"a,b\"")
        XCTAssertEqual(ToonQuoter.encode("a|b", delimiter: "|"), "\"a|b\"")
    }

    func testQuotesValuesThatLookLikeNumbersOrLiterals() {
        XCTAssertEqual(ToonQuoter.encode("05"), "\"05\"")
        XCTAssertEqual(ToonQuoter.encode("1.5000"), "\"1.5000\"")
        XCTAssertEqual(ToonQuoter.encode("-1E+03"), "\"-1E+03\"")
        XCTAssertEqual(ToonQuoter.encode("true"), "\"true\"")
        XCTAssertEqual(ToonQuoter.encode("null"), "\"null\"")
    }

    func testQuotesStructuralCharacters() {
        XCTAssertEqual(ToonQuoter.encode("note: value"), "\"note: value\"")
        XCTAssertEqual(ToonQuoter.encode("items[0]"), "\"items[0]\"")
    }

    func testEscapesSpecialCharactersWhenQuoted() {
        XCTAssertEqual(ToonQuoter.encode("hello \"world\""), "\"hello \\\"world\\\"\"")
        XCTAssertEqual(ToonQuoter.encode("line1\nline2"), "\"line1\\nline2\"")
        XCTAssertEqual(ToonQuoter.encode("tab\there"), "\"tab\\there\"")
    }
}
