import XCTest
@testable import TOONCore

final class LexerTests: XCTestCase {
    func testSimpleKeyValue() throws {
        let tokens = try Lexer.tokenize("name: Alice\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("name"),
            .colon,
            .identifier("Alice"),
            .newline,
            .eof,
        ])
    }

    func testIndentationProducesIndentAndDedent() throws {
        let input = """
        user:
          id: 1
          role: admin
        """
        let tokens = try Lexer.tokenize(input + "\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("user"),
            .colon,
            .newline,
            .indent(level: 2),
            .identifier("id"),
            .colon,
            .number("1"),
            .newline,
            .identifier("role"),
            .colon,
            .identifier("admin"),
            .newline,
            .dedent(level: 0),
            .eof,
        ])
    }

    func testDottedIdentifierAndDelimiters() throws {
        let tokens = try Lexer.tokenize("data.meta[2]{id,name}:")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("data.meta"),
            .leftBracket,
            .number("2"),
            .rightBracket,
            .leftBrace,
            .identifier("id"),
            .comma,
            .identifier("name"),
            .rightBrace,
            .colon,
            .eof,
        ])
    }

    func testStringLiteralEscapes() throws {
        let input = "title: \"Hello\\nWorld\"\n"
        let tokens = try Lexer.tokenize(input)
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("title"),
            .colon,
            .stringLiteral("Hello\nWorld"),
            .newline,
            .eof,
        ])
    }

    func testDecimalNumbers() throws {
        let tokens = try Lexer.tokenize("value: 3.1415\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("value"),
            .colon,
            .number("3.1415"),
            .newline,
            .eof,
        ])
    }

    func testTabIndentationThrows() {
        XCTAssertThrowsError(try Lexer.tokenize("key:\n\tvalue: 1")) { error in
            guard case .invalidIndentation = error as? LexerError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
    }

    func testRandomizedWhitespaceKeepsTokenCount() throws {
        let sample = "alpha: 1\nbeta: 2\n"
        let expected = try Lexer.tokenize(sample).map(\.kind)
        for spaces in 0..<5 {
            let mutated = sample.replacingOccurrences(of: " ", with: String(repeating: " ", count: spaces + 1))
            let tokens = try Lexer.tokenize(mutated)
            XCTAssertEqual(tokens.map(\.kind), expected)
        }
    }

    func testUnicodeIdentifierTokens() throws {
        let tokens = try Lexer.tokenize("café: 1\n你好: true\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("café"),
            .colon,
            .number("1"),
            .newline,
            .identifier("你好"),
            .colon,
            .identifier("true"),
            .newline,
            .eof,
        ])
    }

    func testDelimiterTokensForTabAndPipe() throws {
        let tokens = try Lexer.tokenize("[2\t]{id|name}:\n  A1\tAda\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .leftBracket,
            .number("2"),
            .delimiterTab,
            .rightBracket,
            .leftBrace,
            .identifier("id"),
            .pipe,
            .identifier("name"),
            .rightBrace,
            .colon,
            .newline,
            .indent(level: 2),
            .identifier("A1"),
            .delimiterTab,
            .identifier("Ada"),
            .newline,
            .dedent(level: 0),
            .eof,
        ])
    }

    func testNegativeNumbersAreTokenized() throws {
        let tokens = try Lexer.tokenize("value: -42\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("value"),
            .colon,
            .number("-42"),
            .newline,
            .eof,
        ])
    }

    func testCarriageReturnEscapeSequences() throws {
        let tokens = try Lexer.tokenize("note: \"line1\\rline2\"\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("note"),
            .colon,
            .stringLiteral("line1\rline2"),
            .newline,
            .eof,
        ])
    }
}
