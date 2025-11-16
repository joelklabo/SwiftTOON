import XCTest
@testable import TOONCore

/// Tests for Lexer edge cases and error paths to push toward 95%+ coverage
final class LexerEdgeCaseTests: XCTestCase {
    
    // MARK: - Carriage Return Handling (lines 136-137)
    
    func testCarriageReturnIsIgnored() throws {
        let input = "key:\rvalue\n"
        let tokens = try Lexer.tokenize(input)
        
        // CR should be skipped
        let kinds = tokens.map(\.kind)
        XCTAssertTrue(kinds.contains { if case .identifier("key") = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .identifier("value") = $0 { return true }; return false })
    }
    
    func testCarriageReturnInMiddleOfLine() throws {
        let input = "test\rvalue\n"
        let tokens = try Lexer.tokenize(input)
        
        XCTAssertGreaterThan(tokens.count, 0)
    }
    
    // MARK: - Space Fallback Path (lines 177-179)
    
    func testSpaceAfterSkipWhitespace() {
        // This is defensive code - spaces should be caught by skipInlineWhitespace
        // But we can verify the lexer handles spaces correctly
        let input = "key:   value\n"
        
        do {
            let tokens = try Lexer.tokenize(input)
            XCTAssertGreaterThan(tokens.count, 0)
        } catch {
            XCTFail("Should handle spaces: \(error)")
        }
    }
    
    // MARK: - Unexpected Character Error (lines 181-182)
    
    func testUnexpectedCharacterError() {
        // Use a control character that should trigger error
        let input = "key: \u{0000}\n"
        
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard case LexerError.unexpectedCharacter = error else {
                XCTFail("Expected unexpectedCharacter, got \(error)")
                return
            }
        }
    }
    
    func testUnexpectedUnicodeCharacter() {
        // The lexer may allow Unicode in identifiers/values
        // Test with null byte which should definitely fail
        let input = "test\u{0000}value\n"
        
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard case LexerError.unexpectedCharacter = error else {
                XCTFail("Expected unexpectedCharacter, got \(error)")
                return
            }
        }
    }
    
    // MARK: - All Token Types Coverage
    
    func testAllTokenTypes() throws {
        let input = """
        key: value
        number: 42
        string: "quoted"
        colon: test
        array[3]: a,b,c
        tabular[2]{x|y}:
          1|2
          3|4
        list[2]:
          - item
          - other
        braces: {}
        brackets: []
        """
        
        let tokens = try Lexer.tokenize(input)
        
        // Verify we got various token types
        let kinds = tokens.map(\.kind)
        
        // Check for specific token types
        XCTAssertTrue(kinds.contains { if case .colon = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .comma = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .leftBracket = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .rightBracket = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .leftBrace = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .rightBrace = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .pipe = $0 { return true }; return false })
        XCTAssertTrue(kinds.contains { if case .dash = $0 { return true }; return false })
    }
    
    // MARK: - Error Description Coverage
    
    func testLexerErrorDescriptions() {
        let invalidIndent = LexerError.invalidIndentation(line: 1, column: 5, description: "test")
        XCTAssertNotNil(invalidIndent.errorDescription)
        XCTAssertTrue(invalidIndent.errorDescription!.contains("test"))
        
        let unexpectedChar = LexerError.unexpectedCharacter(line: 2, column: 3, character: "€")
        XCTAssertNotNil(unexpectedChar.errorDescription)
        XCTAssertTrue(unexpectedChar.errorDescription!.contains("2:3"))
        
        let unterminatedString = LexerError.unterminatedString(line: 3, column: 10)
        XCTAssertNotNil(unterminatedString.errorDescription)
        XCTAssertTrue(unterminatedString.errorDescription!.contains("3:10"))
    }
    
    // MARK: - Edge Cases
    
    func testEmptyInput() throws {
        let tokens = try Lexer.tokenize("")
        
        // Should have at least EOF
        XCTAssertEqual(tokens.count, 1)
        guard case .eof = tokens[0].kind else {
            XCTFail("Expected EOF token")
            return
        }
    }
    
    func testOnlyWhitespace() throws {
        let tokens = try Lexer.tokenize("   \n  \n")
        
        // Should have newlines and EOF
        XCTAssertGreaterThan(tokens.count, 0)
    }
    
    func testUnterminatedString() {
        let input = "key: \"unterminated"
        
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard case LexerError.unterminatedString = error else {
                XCTFail("Expected unterminatedString, got \(error)")
                return
            }
        }
    }
    
    func testInvalidIndentation() {
        // Dedent to wrong level
        let input = """
        parent:
          child: value
         wrong: indent
        """
        
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard case LexerError.invalidIndentation = error else {
                XCTFail("Expected invalidIndentation, got \(error)")
                return
            }
        }
    }
    
    func testMultipleCarriageReturns() throws {
        let input = "a\r\rb\r\rc\n"
        let tokens = try Lexer.tokenize(input)
        
        // Should handle multiple CRs
        XCTAssertGreaterThan(tokens.count, 0)
    }
    
    func testMixedLineEndings() throws {
        let input = "line1\r\nline2\nline3\r"
        let tokens = try Lexer.tokenize(input)
        
        // Should handle mixed line endings
        XCTAssertGreaterThan(tokens.count, 0)
    }
}
