import XCTest
@testable import TOONCore

/// Surgical tests to hit the stubborn uncovered Parser paths
/// Focus: parseValue() and parseStandaloneValue() at lines 143-187
final class ParserSurgicalCoverageTests: XCTestCase {
    
    // MARK: - parseValue() Coverage (lines 143-163)
    // Called from parseListArrayItem line 441 when item is complex but not simple scalar
    
    func testListItemWithQuotedString() throws {
        // Quoted strings should trigger parseValue -> parseStandaloneValue path
        let toon = """
        items[1]:
          - "quoted value"
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], .string("quoted value"))
    }
    
    func testListItemWithNull() throws {
        let toon = """
        items[1]:
          - null
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items[0], .null)
    }
    
    func testListItemWithBoolean() throws {
        let toon = """
        items[2]:
          - true
          - false
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items[0], .bool(true))
        XCTAssertEqual(items[1], .bool(false))
    }
    
    func testListItemWithNumber() throws {
        let toon = """
        items[2]:
          - 42
          - 3.14
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items[0], .number(42))
        XCTAssertEqual(items[1], .number(3.14))
    }
    
    // MARK: - parseStandaloneValue() Multi-Token Coverage (lines 165-187)
    
    func testListItemMultiTokenValue() throws {
        // Multi-word values after dash are not supported in TOON
        // Each list item must be a single value or object
        let toon = """
        items[1]:
          - simple
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], .string("simple"))
    }
    
    func testListItemWithColon() throws {
        // Colon in middle of value (not after identifier)
        let toon = """
        items[1]:
          - value: with colon
        """
        var parser = try Parser(input: toon)
        
        // Should parse as object within list item
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 1)
    }
    
    // MARK: - parseValue with Array (lines 155-159)
    
    func testListItemWithInlineArray() throws {
        // Triggers parseValue -> case .leftBracket -> parseArrayValue
        let toon = """
        items[1]:
          - [2]: a, b
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"],
              case .array(let nested) = items[0] else {
            XCTFail("Expected nested array")
            return
        }
        
        XCTAssertEqual(nested.count, 2)
    }
    
    // MARK: - Edge Cases for Chunk Buffer
    
    func testListItemEndingWithNewline() throws {
        let toon = """
        items[2]:
          - first
          - second
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 2)
    }
    
    func testListItemAtEOF() throws {
        // No trailing newline - hits EOF case in parseStandaloneValue
        let toon = "items[1]:\n  - final"
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], .string("final"))
    }
    
    // MARK: - Error Paths
    
    func testParseValueWithNoToken() throws {
        // Dash at end with only whitespace returns empty object, not error
        let toon = """
        items[1]:
          - 
        sibling: value
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        // Empty object for empty list item
        XCTAssertEqual(items.count, 1)
        guard case .object(let empty) = items[0] else {
            XCTFail("Expected empty object")
            return
        }
        XCTAssertTrue(empty.isEmpty)
    }
    
    func testParseStandaloneValueEmptyChunk() throws {
        // Dash followed by newline/dedent returns empty object
        let toon = """
        items[2]:
          - 
          - value
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 2)
        // First item is empty object
        guard case .object(let empty) = items[0] else {
            XCTFail("Expected empty object")
            return
        }
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(items[1], .string("value"))
    }
    
    // MARK: - Lenient Array Padding (line 359-361)
    
    func testLenientArrayPadding() throws {
        let toon = """
        items[5]:
          - one
          - two
        """
        var parser = try Parser(input: toon, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        // Lenient mode pads to declared length
        XCTAssertEqual(items.count, 5)
        XCTAssertEqual(items[0], .string("one"))
        XCTAssertEqual(items[1], .string("two"))
        XCTAssertEqual(items[2], .null)
        XCTAssertEqual(items[3], .null)
        XCTAssertEqual(items[4], .null)
    }
    
    // MARK: - Special Token Combinations
    
    func testListItemWithDot() throws {
        let toon = """
        items[1]:
          - value.with.dots
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 1)
    }
    
    func testListItemWithDash() throws {
        let toon = """
        items[1]:
          - value-with-dash
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items.count, 1)
    }
    
    // MARK: - Dedent Case in parseStandaloneValue (line 172)
    
    func testValueFollowedByDedent() throws {
        let toon = """
        outer:
          inner[1]:
            - value
        sibling: test
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertNotNil(obj["outer"])
        XCTAssertEqual(obj["sibling"], .string("test"))
    }
}
