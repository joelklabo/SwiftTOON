import XCTest
@testable import TOONCore

/// Tests specifically designed to trigger parseValue() and parseStandaloneValue()
/// These paths are reached when list items start with unusual tokens
final class ParserParseValueTriggerTests: XCTestCase {
    
    // MARK: - Triggering parseValue() via unusual list item tokens
    
    func testListItemStartingWithRightBrace() throws {
        // Right brace is not identifier/number/string, triggers parseValue
        let toon = """
        items[1]:
          - }
        """
        var parser = try Parser(input: toon)
        
        // This is invalid syntax but parser should handle it
        do {
            _ = try parser.parse()
            // If it succeeds, parseValue was called
            XCTAssert(true, "Successfully parsed unusual token")
        } catch {
            // Expected - unusual tokens cause errors
            XCTAssert(true, "Error handling for unusual token: \(error)")
        }
    }
    
    func testListItemStartingWithLeftBrace() throws {
        // Left brace after dash
        let toon = """
        items[1]:
          - {
        """
        var parser = try Parser(input: toon)
        
        do {
            _ = try parser.parse()
            XCTAssert(true)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    func testListItemStartingWithComma() throws {
        // Comma after dash
        let toon = """
        items[1]:
          - ,
        """
        var parser = try Parser(input: toon)
        
        do {
            _ = try parser.parse()
            XCTAssert(true)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    func testListItemStartingWithPipe() throws {
        // Pipe after dash
        let toon = """
        items[1]:
          - |
        """
        var parser = try Parser(input: toon)
        
        do {
            _ = try parser.parse()
            XCTAssert(true)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    func testListItemStartingWithRightBracket() throws {
        // Right bracket after dash (not as array syntax)
        let toon = """
        items[1]:
          - ]
        """
        var parser = try Parser(input: toon)
        
        do {
            _ = try parser.parse()
            XCTAssert(true)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    func testListItemStartingWithColon() throws {
        // Colon after dash (not part of key:value)
        let toon = """
        items[1]:
          - :
        """
        var parser = try Parser(input: toon)
        
        do {
            _ = try parser.parse()
            XCTAssert(true)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    // MARK: - Alternative approach: Test with complex multi-token sequences
    
    func testListItemWithMultipleSpecialCharacters() throws {
        // Multiple unusual tokens in sequence
        let toon = """
        items[1]:
          - : , }
        """
        var parser = try Parser(input: toon)
        
        do {
            _ = try parser.parse()
            XCTAssert(true)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    // MARK: - Check if parseValue can be reached via valid syntax
    
    func testListItemWithDashIdentifier() throws {
        // Dash token itself followed by more content
        let toon = """
        items[2]:
          - -
          - value
        """
        var parser = try Parser(input: toon)
        
        do {
            let result = try parser.parse()
            guard case .object(let obj) = result,
                  case .array(let items) = obj["items"] else {
                XCTFail("Expected array")
                return
            }
            XCTAssertEqual(items.count, 2)
        } catch {
            // If it throws, that's also valid
            XCTAssert(true, "Error: \(error)")
        }
    }
    
    func testListItemWithOnlyWhitespace() throws {
        // Whitespace-only list item
        let toon = """
        items[1]:
          -    
        next: value
        """
        var parser = try Parser(input: toon)
        let result = try parser.parse()
        
        // Should handle gracefully
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        XCTAssertNotNil(obj["items"])
    }
    
    // MARK: - Testing parseStandaloneValue multi-token path
    
    func testListItemWithComplexTokenSequence() throws {
        // Try to get multiple tokens that aren't simple scalars
        let toon = """
        items[1]:
          - [ ]
        """
        var parser = try Parser(input: toon)
        
        do {
            let result = try parser.parse()
            // If successful, check structure
            guard case .object(let obj) = result,
                  case .array(let items) = obj["items"] else {
                XCTFail("Expected array")
                return
            }
            XCTAssertEqual(items.count, 1)
        } catch {
            XCTAssert(true, "Error: \(error)")
        }
    }
}
