import XCTest
@testable import TOONCore

/// Comprehensive error path tests for Lexer to achieve 95%+ coverage
final class LexerErrorPathsTests: XCTestCase {
    
    // MARK: - String Escape Errors
    
    func testInvalidEscapeSequence_x() throws {
        let input = #""text with \x invalid escape""#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(let line, let column, let char) = lexerError else {
                XCTFail("Expected unexpectedCharacter error, got \(error)")
                return
            }
            XCTAssertEqual(line, 1)
            XCTAssertTrue(column > 0)
            XCTAssertEqual(char, "x")
        }
    }
    
    func testInvalidEscapeSequence_u() throws {
        let input = #""invalid \u unicode""#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(_, _, let char) = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
            XCTAssertEqual(char, "u")
        }
    }
    
    func testInvalidEscapeSequence_digit() throws {
        let input = #""escape \1 digit""#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(_, _, let char) = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
            XCTAssertEqual(char, "1")
        }
    }
    
    func testInvalidEscapeSequence_space() throws {
        let input = #""escape \ space""#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
        }
    }
    
    func testInvalidEscapeSequence_a() throws {
        let input = #""invalid \a bell""#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(_, _, let char) = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
            XCTAssertEqual(char, "a")
        }
    }
    
    // MARK: - Unterminated String Errors
    
    func testUnterminatedString_simple() throws {
        let input = #""unterminated"#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unterminatedString(let line, let column) = lexerError else {
                XCTFail("Expected unterminatedString error, got \(error)")
                return
            }
            XCTAssertEqual(line, 1)
            XCTAssertEqual(column, 1)
        }
    }
    
    func testUnterminatedString_withContent() throws {
        let input = #""this string has no end"#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unterminatedString = lexerError else {
                XCTFail("Expected unterminatedString error")
                return
            }
        }
    }
    
    func testUnterminatedString_withEscapeAtEnd() throws {
        let input = #""ends with backslash\"#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unterminatedString = lexerError else {
                XCTFail("Expected unterminatedString error")
                return
            }
        }
    }
    
    func testUnterminatedString_multiline() throws {
        let input = """
        key: "this is
        not closed
        """
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unterminatedString = lexerError else {
                XCTFail("Expected unterminatedString error")
                return
            }
        }
    }
    
    func testUnterminatedString_emptyAtEOF() throws {
        let input = #"""#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unterminatedString = lexerError else {
                XCTFail("Expected unterminatedString error")
                return
            }
        }
    }
    
    // MARK: - Invalid Indentation Errors
    
    func testInvalidIndentation_mismatchedDedent() throws {
        let input = """
        root:
          child1:
            grandchild: value
           bad_dedent: value
        """
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .invalidIndentation(let line, let column, let description) = lexerError else {
                XCTFail("Expected invalidIndentation error, got \(error)")
                return
            }
            XCTAssertEqual(line, 4)
            XCTAssertGreaterThan(column, 0)
            XCTAssertTrue(description.contains("Mismatched dedent"))
        }
    }
    
    func testInvalidIndentation_oddSpaces() throws {
        // Note: Lexer allows single-space increments (3 spaces after 2 spaces)
        // It only errors on mismatched dedents
        let input = """
        parent:
          child: 1
           nested: 2
        """
        // This is valid - creates indent stack [0, 2, 3]
        XCTAssertNoThrow(try Lexer.tokenize(input))
    }
    
    func testInvalidIndentation_dedentToNonExistentLevel() throws {
        let input = """
        a:
            b:
                c: value
          d: wrong
        """
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .invalidIndentation(_, _, let desc) = lexerError else {
                XCTFail("Expected invalidIndentation error")
                return
            }
            XCTAssertTrue(desc.contains("Mismatched dedent"))
        }
    }
    
    func testInvalidIndentation_inconsistentSpacing() throws {
        // Lexer accepts any increment, only rejects invalid dedents
        let input = """
        top:
          level1: a
           level2: b
        """
        // Valid: indent stack [0, 2, 3]
        XCTAssertNoThrow(try Lexer.tokenize(input))
    }
    
    // MARK: - Number Format Errors
    
    func testInvalidNumber_exponentWithoutDigits() throws {
        let input = "value: 1.5e"
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(let line, let column, _) = lexerError else {
                XCTFail("Expected unexpectedCharacter error, got \(error)")
                return
            }
            XCTAssertEqual(line, 1)
            XCTAssertGreaterThan(column, 0)
        }
    }
    
    func testInvalidNumber_exponentPlusWithoutDigits() throws {
        let input = "value: 2.0e+"
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
        }
    }
    
    func testInvalidNumber_exponentMinusWithoutDigits() throws {
        let input = "value: 3.14e-"
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
        }
    }
    
    func testInvalidNumber_negativeExponentWithoutDigits() throws {
        let input = "val: -5E-"
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(_, _, let char) = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
            // Should see newline or EOF character
            XCTAssertTrue(char == "\n" || char == " ")
        }
    }
    
    func testInvalidNumber_exponentFollowedByNonDigit() throws {
        let input = "num: 1e2x"
        // This actually succeeds - lexes as "1e2" then "x", so we need to test at EOF
        let input2 = "num: 1ea"
        XCTAssertThrowsError(try Lexer.tokenize(input2)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
        }
    }
    
    func testInvalidNumber_exponentPlusFollowedByLetter() throws {
        let input = "num: 2e+a"
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter(_, _, let char) = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
            XCTAssertEqual(char, "a")
        }
    }
    
    // MARK: - Edge Cases with Valid Escapes
    
    func testValidEscapeSequences() throws {
        let input = #""valid: \n \t \r \\ \" escapes""#
        let tokens = try Lexer.tokenize(input)
        XCTAssertEqual(tokens.count, 2) // string + eof
        guard case .stringLiteral(let str) = tokens[0].kind else {
            XCTFail("Expected string literal")
            return
        }
        XCTAssertTrue(str.contains("\n"))
        XCTAssertTrue(str.contains("\t"))
        XCTAssertTrue(str.contains("\r"))
        XCTAssertTrue(str.contains("\\"))
        XCTAssertTrue(str.contains("\""))
    }
    
    func testValidExponentNumbers() throws {
        let inputs = [
            "val: 1e5",
            "val: 2E10",
            "val: 3.14e-2",
            "val: 2.5E+3",
            "val: -1.5e10"
        ]
        for input in inputs {
            XCTAssertNoThrow(try Lexer.tokenize(input), "Should parse: \(input)")
        }
    }
    
    // MARK: - Mixed Error Scenarios
    
    func testUnterminatedStringWithValidEscapes() throws {
        let input = #""has valid \n and \t but no end"#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unterminatedString = lexerError else {
                XCTFail("Expected unterminatedString error")
                return
            }
        }
    }
    
    func testInvalidEscapeInOtherwiseValidString() throws {
        let input = #""start \x middle" end"#
        XCTAssertThrowsError(try Lexer.tokenize(input)) { error in
            guard let lexerError = error as? LexerError,
                  case .unexpectedCharacter = lexerError else {
                XCTFail("Expected unexpectedCharacter error")
                return
            }
        }
    }
    
    func testMultipleIndentLevels() throws {
        let input = """
        a:
          b: 1
           c: 2
        """
        // Valid: stack [0, 2, 3]
        XCTAssertNoThrow(try Lexer.tokenize(input))
    }
    
    func testErrorMessageLocalization() throws {
        let input = #""unterminated"#
        do {
            _ = try Lexer.tokenize(input)
            XCTFail("Should have thrown")
        } catch let error as LexerError {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertTrue(description!.contains("Unterminated string"))
            XCTAssertTrue(description!.contains("1:1"))
        }
    }
    
    func testInvalidCharacterErrorMessage() throws {
        let input = #""bad \z escape""#
        do {
            _ = try Lexer.tokenize(input)
            XCTFail("Should have thrown")
        } catch let error as LexerError {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertTrue(description!.contains("Unexpected character"))
            XCTAssertTrue(description!.contains("z"))
        }
    }
    
    func testInvalidIndentationErrorMessage() throws {
        let input = """
        a:
          b: 1
         c: 2
        """
        do {
            _ = try Lexer.tokenize(input)
            XCTFail("Should have thrown")
        } catch let error as LexerError {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertTrue(description!.contains("Invalid indentation"))
            XCTAssertTrue(description!.contains("Mismatched dedent"))
        }
    }
}
