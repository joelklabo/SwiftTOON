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

    func testInvalidNumberLiteral() {
        var parser = JSONTextParser(text: "{\"value\": 00}")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case .invalidNumber = error as? JSONTextParserError else {
                XCTFail("Expected invalidNumber, got \(error)")
                return
            }
        }
    }

    func testUnexpectedEndOfInput() {
        var parser = JSONTextParser(text: "{\"value\": \"missing\"")
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case JSONTextParserError.unexpectedEndOfInput = error else {
                XCTFail("Expected unexpectedEndOfInput, got \(error)")
                return
            }
        }
    }
}
