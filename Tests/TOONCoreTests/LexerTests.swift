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

    func testMultipleDedentsAreEmitted() throws {
        let input = """
        root:
          child:
            value: 1
          sibling: true
        """
        let tokens = try Lexer.tokenize(input + "\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("root"),
            .colon,
            .newline,
            .indent(level: 2),
            .identifier("child"),
            .colon,
            .newline,
            .indent(level: 4),
            .identifier("value"),
            .colon,
            .number("1"),
            .newline,
            .dedent(level: 2),
            .identifier("sibling"),
            .colon,
            .identifier("true"),
            .newline,
            .dedent(level: 0),
            .eof,
        ])
    }

    func testBlankLinesDoNotAffectIndentation() throws {
        let input = """
        root:
          alpha: 1

          beta: 2
        """
        let tokens = try Lexer.tokenize(input + "\n")
        XCTAssertEqual(tokens.map(\.kind), [
            .identifier("root"),
            .colon,
            .newline,
            .indent(level: 2),
            .identifier("alpha"),
            .colon,
            .number("1"),
            .newline,
            .newline,
            .identifier("beta"),
            .colon,
            .number("2"),
            .newline,
            .dedent(level: 0),
            .eof,
        ])
    }

    func testUnterminatedStringThrows() {
        XCTAssertThrowsError(try Lexer.tokenize("note: \"unterminated")) { error in
            guard case .unterminatedString = error as? LexerError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRandomTokenRangesRemainMonotonic() throws {
        struct RNG {
            var state: UInt64
            mutating func next() -> UInt64 {
                state = state &* 6364136223846793005 &+ 1
                return state
            }
        }

        func randomToken(rng: inout RNG) -> String {
            switch rng.next() % 6 {
            case 0: return "key\(rng.next()%9):"
            case 1: return " value"
            case 2: return " \"value\""
            case 3: return "[2]{a,b}:"
            case 4: return " \(rng.next()%10)"
            default: return " |"
            }
        }

        var rng = RNG(state: 0xC0FFEE)
        for _ in 0..<30 {
            var builder = ""
            let lines = Int(rng.next() % 5) + 2
            for lineIndex in 0..<lines {
                if lineIndex > 0 {
                    builder.append("\n")
                }
                builder += ""
                let segments = Int(rng.next() % 4) + 1
                for _ in 0..<segments {
                    builder += randomToken(rng: &rng)
                }
            }
            builder.append("\n")
            let tokens = try Lexer.tokenize(builder)
            var previousUpper = 0
            for token in tokens {
                XCTAssert(token.range.lowerBound >= previousUpper, "Tokens overlap: \(token)")
                XCTAssert(token.range.upperBound >= token.range.lowerBound, "Invalid range")
                previousUpper = token.range.upperBound
            }
        }
    }
}
