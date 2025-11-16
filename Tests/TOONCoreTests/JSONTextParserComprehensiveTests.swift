import XCTest
@testable import TOONCore

final class JSONTextParserComprehensiveTests: XCTestCase {
    
    // MARK: - Unicode Escape Sequences
    
    func testBasicUnicodeEscape() throws {
        // \u0041 = "A"
        let json = #""\u0041""#
        let result = try JSONTextParser.parse(json)
        guard case .string(let str) = result else {
            return XCTFail("Expected string")
        }
        XCTAssertEqual(str, "A")
    }
    
    func testMultipleUnicodeEscapes() throws {
        // \u0048\u0065\u006C\u006C\u006F = "Hello"
        let json = #""\u0048\u0065\u006C\u006C\u006F""#
        let result = try JSONTextParser.parse(json)
        guard case .string(let str) = result else {
            return XCTFail("Expected string")
        }
        XCTAssertEqual(str, "Hello")
    }
    
    func testInvalidUnicodeEscape() {
        // Invalid hex digits
        let json = #""\uZZZZ""#
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    func testTruncatedUnicodeEscape() {
        // Only 3 hex digits
        let json = #""\u004""#
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    // MARK: - All Escape Characters
    
    func testAllBasicEscapes() throws {
        let json = #""\t\r\n\"\\\/""#
        let result = try JSONTextParser.parse(json)
        guard case .string(let str) = result else {
            return XCTFail("Expected string")
        }
        XCTAssertEqual(str, "\t\r\n\"\\/")
    }
    
    func testEscapeAtStringBoundaries() throws {
        // Escape at start and end
        let json = #""\ttext\n""#
        let result = try JSONTextParser.parse(json)
        guard case .string(let str) = result else {
            return XCTFail("Expected string")
        }
        XCTAssertEqual(str, "\ttext\n")
    }
    
    func testInvalidEscapeSequence() {
        // \x is not valid in JSON
        let json = #""\x41""#
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    // MARK: - Scientific Notation
    
    func testScientificNotationPositiveExponent() throws {
        let json = "1.23e10"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, 1.23e10, accuracy: 0.0001)
    }
    
    func testScientificNotationNegativeExponent() throws {
        let json = "1.5e-308"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, 1.5e-308)
    }
    
    func testScientificNotationOverflow() throws {
        // Should handle gracefully (infinity)
        let json = "1e309"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertTrue(n.isInfinite)
    }
    
    func testScientificNotationCapitalE() throws {
        let json = "2.5E3"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, 2500.0)
    }
    
    func testScientificNotationWithPlusSign() throws {
        let json = "1.5e+10"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, 1.5e10, accuracy: 0.0001)
    }
    
    // MARK: - Numeric Edge Cases
    
    func testNegativeZero() throws {
        let json = "-0"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, -0.0)
        XCTAssertTrue(n.sign == .minus)
    }
    
    func testTrailingDecimalPoint() {
        // 1. is invalid (must have digits after decimal)
        let json = "1."
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    func testLeadingDecimalPoint() {
        // .5 is invalid (must have leading digit)
        let json = ".5"
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    func testVeryLargeInteger() throws {
        let json = "9007199254740992"  // 2^53
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, 9007199254740992.0)
    }
    
    // MARK: - Malformed JSON Error Recovery
    
    func testUnterminatedString() {
        let json = #""unterminated"#
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    func testUnexpectedToken() {
        let json = "]["
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    func testUnexpectedEndOfInput() {
        let json = #"{"key":"#
        XCTAssertThrowsError(try JSONTextParser.parse(json))
    }
    
    // MARK: - Additional Edge Cases
    
    func testEmptyString() throws {
        let json = #""""#
        let result = try JSONTextParser.parse(json)
        guard case .string(let str) = result else {
            return XCTFail("Expected string")
        }
        XCTAssertEqual(str, "")
    }
    
    func testStringWithOnlyWhitespace() throws {
        let json = #""   ""#
        let result = try JSONTextParser.parse(json)
        guard case .string(let str) = result else {
            return XCTFail("Expected string")
        }
        XCTAssertEqual(str, "   ")
    }
    
    func testZero() throws {
        let json = "0"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, 0.0)
    }
    
    func testNegativeNumber() throws {
        let json = "-42.5"
        let result = try JSONTextParser.parse(json)
        guard case .number(let n) = result else {
            return XCTFail("Expected number")
        }
        XCTAssertEqual(n, -42.5)
    }
    
    func testBooleanTrue() throws {
        let json = "true"
        let result = try JSONTextParser.parse(json)
        guard case .bool(let b) = result else {
            return XCTFail("Expected bool")
        }
        XCTAssertTrue(b)
    }
    
    func testBooleanFalse() throws {
        let json = "false"
        let result = try JSONTextParser.parse(json)
        guard case .bool(let b) = result else {
            return XCTFail("Expected bool")
        }
        XCTAssertFalse(b)
    }
    
    func testNull() throws {
        let json = "null"
        let result = try JSONTextParser.parse(json)
        guard case .null = result else {
            return XCTFail("Expected null")
        }
    }
}
