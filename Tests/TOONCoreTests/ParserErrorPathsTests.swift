import XCTest
@testable import TOONCore

final class ParserErrorPathsTests: XCTestCase {
    
    // MARK: - Array Length Mismatch Tests
    
    func testInlineArrayTooFewValues() throws {
        let toonText = "arr[3]: 1, 2"
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case let ParserError.inlineArrayLengthMismatch(expected, actual, _, _) = error else {
                XCTFail("Expected inlineArrayLengthMismatch, got \(error)")
                return
            }
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(actual, 2)
        }
    }
    
    func testInlineArrayTooManyValues() throws {
        let toonText = "arr[2]: 1, 2, 3"
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.inlineArrayLengthMismatch = error else {
                XCTFail("Expected inlineArrayLengthMismatch, got \(error)")
                return
            }
        }
    }
    
    func testInlineArrayExtraValueAfterCompletion() throws {
        let toonText = "arr[2]: 1, 2, 3"
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case let ParserError.inlineArrayLengthMismatch(expected, actual, _, _) = error else {
                XCTFail("Expected inlineArrayLengthMismatch, got \(error)")
                return
            }
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(actual, 3)
        }
    }
    
    // MARK: - Array Declaration Errors
    
    func testArrayMissingNewlineAfterDeclaration() throws {
        let toonText = """
        data[2]:
          - item1
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken = error else {
                XCTFail("Expected unexpectedToken, got \(error)")
                return
            }
        }
    }
    
    func testInvalidArrayLengthLiteral() throws {
        let toonText = "arr[abc]: 1"
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case let ParserError.invalidNumberLiteral(value, _, _) = error else {
                XCTFail("Expected invalidNumberLiteral, got \(error)")
                return
            }
            // Lexer consumes identifier "abc" as empty string for number context
            XCTAssertTrue(value.isEmpty || value == "abc", "Expected empty or 'abc', got '\(value)'")
        }
    }
    
    func testArrayDeclarationMissingClosingBracket() throws {
        let toonText = "arr[3: 1"
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken = error else {
                XCTFail("Expected unexpectedToken for missing bracket, got \(error)")
                return
            }
        }
    }
    
    // MARK: - List Array Errors
    
    func testListArrayMissingDash() throws {
        let toonText = """
        items[2]:
          - first
          second
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken = error else {
                XCTFail("Expected unexpectedToken for missing dash, got \(error)")
                return
            }
        }
    }
    
    func testListArrayTooFewItems() throws {
        let toonText = """
        items[3]:
          - first
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken = error else {
                XCTFail("Expected unexpectedToken for insufficient items, got \(error)")
                return
            }
        }
    }
    
    func testListArrayTooManyItemsStrictMode() throws {
        let toonText = """
        items[2]:
          - first
          - second
          - third
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken = error else {
                XCTFail("Expected unexpectedToken for extra items, got \(error)")
                return
            }
        }
    }
    
    // Note: "- " with no value is valid per spec (yields null), so no error test needed
    
    // MARK: - Lenient Mode Recovery
    
    func testLenientModeAllowsTooFewListItems() throws {
        let toonText = """
        items[3]:
          - first
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            XCTFail("Expected object with array")
            return
        }
        
        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[0], .string("first"))
        XCTAssertEqual(arr[1], .null)
        XCTAssertEqual(arr[2], .null)
    }
    
    func testLenientModeAllowsNonDashTermination() throws {
        let toonText = """
        items[2]:
          - first
        key: value
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            XCTFail("Expected object with array")
            return
        }
        
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0], .string("first"))
        XCTAssertEqual(arr[1], .null)
    }
    
    func testLenientModeAllowsExtraListItems() throws {
        let toonText = """
        items[2]:
          - first
          - second
          - third
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            XCTFail("Expected object with array")
            return
        }
        
        // Lenient mode should consume exactly the declared length
        XCTAssertEqual(arr.count, 2)
    }
    
    // MARK: - Tabular Array Errors
    
    func testTabularRowFieldMismatch() throws {
        let toonText = """
        data[2]{id,name,age}:
          1,Alice
          2,Bob,30
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case let ParserError.tabularRowFieldMismatch(expected, actual, _, _) = error else {
                XCTFail("Expected tabularRowFieldMismatch, got \(error)")
                return
            }
            XCTAssertEqual(expected, 3)
            XCTAssertEqual(actual, 2)
        }
    }
    
    func testTabularRowTooManyFields() throws {
        let toonText = """
        data[1]{id,name}:
          1,Alice,extra
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case let ParserError.tabularRowFieldMismatch(expected, actual, _, _) = error else {
                XCTFail("Expected tabularRowFieldMismatch, got \(error)")
                return
            }
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(actual, 3)
        }
    }
    
    func testTabularArrayMissingRows() throws {
        let toonText = """
        data[3]{id,name}:
          1,Alice
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            // Parser may report tabularRowFieldMismatch when it encounters EOF
            // before consuming all expected rows
            guard case ParserError.tabularRowFieldMismatch = error else {
                XCTFail("Expected tabularRowFieldMismatch for missing rows, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Parser State Errors
    
    // Note: Parser accepts ":" and "key:" as valid (empty object, null value)
    // These cases are valid per spec, so no error tests needed
    
    // MARK: - Nested Structure Errors
    
    func testNestedArrayWithInvalidStructure() throws {
        // List array with inline array: outer[1] followed by "- [2]: a" (only 1 value, expects 2)
        let toonText = """
        outer[1]:
          - [2]: a
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.inlineArrayLengthMismatch = error else {
                XCTFail("Expected inlineArrayLengthMismatch, got \(error)")
                return
            }
        }
    }
    
    func testArrayWithMissingNestedValue() throws {
        let toonText = """
        data[1]
        - 
            key:
        """
        var parser = try Parser(input: toonText)
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken = error else {
                XCTFail("Expected unexpectedToken for missing nested value, got \(error)")
                return
            }
        }
    }
}
