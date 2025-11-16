import XCTest
@testable import TOONCore

final class JSONTextParserTests: XCTestCase {
    func testParsesNestedObjectAndArray() throws {
        let text = """
        {
          "name": "Ada",
          "age": 37,
          "values": [1, 2, false, null, "hi", {"nested": "yes"}],
          "unicode": "\\u0041"
        }
        """
        var parser = JSONTextParser(text: text)
        let value = try parser.parse()
        let expected = JSONValue.object(
            JSONObject(dictionaryLiteral:
                ("name", .string("Ada")),
                ("age", .number(37)),
                ("values", .array([
                    .number(1),
                    .number(2),
                    .bool(false),
                    .null,
                    .string("hi"),
                    .object(JSONObject(dictionaryLiteral: ("nested", .string("yes")))),
                ])),
                ("unicode", .string("A"))
            )
        )
        XCTAssertEqual(value, expected)
    }

    func testUnexpectedCharacterThrows() {
        var parser = JSONTextParser(text: "!!")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case .unexpectedCharacter = error as? JSONTextParserError else {
                XCTFail("Expected unexpectedCharacter, got \(error)")
                return
            }
        }
    }

    func testInvalidEscapeSequence() {
        var parser = JSONTextParser(text: "\"\\q\"")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case .invalidEscape = error as? JSONTextParserError else {
                XCTFail("Expected invalidEscape, got \(error)")
                return
            }
        }
    }

    func testNumberLiteralAllowsLeadingZeros() throws {
        var parser = JSONTextParser(text: "{\"value\": 00}")
        let value = try parser.parse()
        let expected = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(0))))
        XCTAssertEqual(value, expected)
    }

    func testUnexpectedEndOfInput() {
        var parser = JSONTextParser(text: "{\"value\": \"missing\"")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case JSONTextParserError.unexpectedCharacter = error else {
                XCTFail("Expected unexpectedCharacter, got \(error)")
                return
            }
        }
    }

    func testParsesScientificNotationNumbers() throws {
        var parser = JSONTextParser(text: "{\"value\": -1.25e3}")
        let value = try parser.parse()
        let expected = JSONValue.object(["value": .number(-1250)])
        XCTAssertEqual(value, expected)
    }

    func testInvalidUnicodeEscapeThrows() {
        var parser = JSONTextParser(text: "\"\\u00GG\"")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case JSONTextParserError.invalidEscape = error else {
                XCTFail("Expected invalidEscape, got \(error)")
                return
            }
        }
    }

    func testConsumeDigitsFailureReportsCharacter() {
        var parser = JSONTextParser(text: "{\"value\": 1.}")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case JSONTextParserError.unexpectedCharacter = error else {
                XCTFail("Expected unexpectedCharacter, got \(error)")
                return
            }
        }
    }
}
