import XCTest
@testable import TOONCore

/// Tests for lenient array parsing mode.
/// Targets: All `if options.lenientArrays` branches in Parser.swift
/// Goal: Increase Parser.swift coverage by testing padding/truncation behaviors
/// Note: Tests reflect actual implementation - inline arrays allow mismatch but don't auto-pad/truncate
final class LenientModeTests: XCTestCase {
    
    // MARK: - Tabular Array Lenient Tests
    
    func testLenientPadsShortTabularRow() throws {
        let toonText = """
        users[2]{id,name}:
          1,Alice
          2
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let users) = obj["users"] else {
            XCTFail("Expected users array")
            return
        }
        
        XCTAssertEqual(users.count, 2)
        
        // First row complete
        guard case .object(let user1) = users[0] else {
            XCTFail("Expected object in users[0]")
            return
        }
        guard case .number(let id1) = user1["id"],
              case .string(let name1) = user1["name"] else {
            XCTFail("Expected id and name in user1")
            return
        }
        XCTAssertEqual(id1, 1)
        XCTAssertEqual(name1, "Alice")
        
        // Second row should be padded with null
        guard case .object(let user2) = users[1] else {
            XCTFail("Expected object in users[1]")
            return
        }
        guard case .number(let id2) = user2["id"] else {
            XCTFail("Expected id in user2")
            return
        }
        XCTAssertEqual(id2, 2)
        
        // Name should be padded to null in lenient mode
        if let nameValue = user2["name"] {
            XCTAssertEqual(nameValue, .null)
        } else {
            XCTFail("Expected name field (even if null) in lenient mode")
        }
    }
    
    func testLenientTruncatesLongTabularRow() throws {
        let toonText = """
        items[2]{a,b}:
          1,2
          3,4,5,6
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected items array")
            return
        }
        
        XCTAssertEqual(items.count, 2)
        
        // Second row should truncate extra values
        guard case .object(let item2) = items[1] else {
            XCTFail("Expected object in items[1]")
            return
        }
        
        // Only first two fields should be present
        guard case .number(let a) = item2["a"],
              case .number(let b) = item2["b"] else {
            XCTFail("Expected a and b fields")
            return
        }
        XCTAssertEqual(a, 3)
        XCTAssertEqual(b, 4)
    }
    
    func testLenientHandlesMultipleShortRows() throws {
        let toonText = """
        data[3]{x,y,z}:
          1,2,3
          4,5
          6
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let data) = obj["data"],
              data.count == 3 else {
            XCTFail("Expected data array with 3 rows")
            return
        }
        
        // Row 2 should have x and y present, z padded to null
        guard case .object(let row2) = data[1] else {
            XCTFail("Expected object in data[1]")
            return
        }
        guard case .number(let x2) = row2["x"],
              case .number(let y2) = row2["y"] else {
            XCTFail("Expected x and y in row2")
            return
        }
        XCTAssertEqual(x2, 4)
        XCTAssertEqual(y2, 5)
        XCTAssertEqual(row2["z"], .null)
        
        // Row 3 should have x present, y and z padded to null
        guard case .object(let row3) = data[2] else {
            XCTFail("Expected object in data[2]")
            return
        }
        guard case .number(let x3) = row3["x"] else {
            XCTFail("Expected x in row3")
            return
        }
        XCTAssertEqual(x3, 6)
        XCTAssertEqual(row3["y"], .null)
        XCTAssertEqual(row3["z"], .null)
    }
    
    func testStrictModeRejectsShortTabularRow() throws {
        let toonText = """
        users[2]{id,name}:
          1,Alice
          2
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: false))
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard let parserError = error as? ParserError else {
                XCTFail("Expected ParserError, got: \(error)")
                return
            }
            
            // Should be a tabular row field mismatch error
            XCTAssertTrue(parserError.localizedDescription.contains("field"))
        }
    }
    
    func testStrictModeRejectsLongTabularRow() throws {
        let toonText = """
        items[1]{a}:
          1,2,3
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: false))
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard let parserError = error as? ParserError else {
                XCTFail("Expected ParserError, got: \(error)")
                return
            }
            
            XCTAssertTrue(parserError.localizedDescription.contains("field"))
        }
    }
    
    // MARK: - List Array Lenient Tests
    
    func testLenientPadsShortListArray() throws {
        let toonText = """
        items[5]:
          - a
          - b
          - c
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected items array")
            return
        }
        
        // Should have 5 items (3 values + 2 nulls)
        XCTAssertEqual(items.count, 5)
        
        guard case .string(let first) = items[0],
              case .string(let second) = items[1],
              case .string(let third) = items[2] else {
            XCTFail("Expected strings in first 3 items")
            return
        }
        
        XCTAssertEqual(first, "a")
        XCTAssertEqual(second, "b")
        XCTAssertEqual(third, "c")
        
        // Last two should be null
        XCTAssertEqual(items[3], .null)
        XCTAssertEqual(items[4], .null)
    }
    
    func testLenientIgnoresExtraListItems() throws {
        let toonText = """
        items[2]:
          - a
          - b
          - c
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected items array")
            return
        }
        
        // Lenient mode reads exactly length items, ignoring extras
        XCTAssertEqual(items.count, 2)
        
        guard case .string(let first) = items[0],
              case .string(let second) = items[1] else {
            XCTFail("Expected strings")
            return
        }
        
        XCTAssertEqual(first, "a")
        XCTAssertEqual(second, "b")
    }
    
    func testLenientPadsEmptyListWithIndent() throws {
        let toonText = """
        items[3]:
          otherKey: value
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected items array")
            return
        }
        
        // When no dash items found, pads entire array with nulls
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], .null)
        XCTAssertEqual(items[1], .null)
        XCTAssertEqual(items[2], .null)
    }
    
    func testStrictModeRejectsShortListArray() throws {
        let toonText = """
        items[5]:
          - a
          - b
          otherKey: value
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: false))
        
        XCTAssertThrowsError(try parser.parse()) { error in
            // Should throw when not enough dash items and indented content follows
            XCTAssert(error is ParserError)
        }
    }
    
    func testStrictModeRejectsLongListArray() throws {
        let toonText = """
        items[2]:
          - a
          - b
          - c
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: false))
        
        XCTAssertThrowsError(try parser.parse()) { error in
            // Should throw when too many dash items
            XCTAssert(error is ParserError)
        }
    }
    
    // MARK: - Inline Array Lenient Tests
    
    func testLenientAllowsShortInlineArray() throws {
        // Lenient mode allows mismatch but doesn't auto-pad inline arrays
        let toonText = """
        values[5]: 1,2,3
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let values) = obj["values"] else {
            XCTFail("Expected values array")
            return
        }
        
        // Parser allows the mismatch in lenient mode (doesn't throw)
        // but doesn't auto-pad - just returns what was provided
        XCTAssertEqual(values.count, 3)
        
        guard case .number(let v1) = values[0],
              case .number(let v2) = values[1],
              case .number(let v3) = values[2] else {
            XCTFail("Expected numbers")
            return
        }
        
        XCTAssertEqual(v1, 1)
        XCTAssertEqual(v2, 2)
        XCTAssertEqual(v3, 3)
    }
    
    func testLenientAllowsLongInlineArray() throws {
        // Lenient mode allows mismatch but doesn't auto-truncate inline arrays
        let toonText = """
        values[2]: 1,2,3,4,5
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let values) = obj["values"] else {
            XCTFail("Expected values array")
            return
        }
        
        // Parser allows the mismatch in lenient mode (doesn't throw)
        // but doesn't auto-truncate - just returns what was provided
        XCTAssertEqual(values.count, 5)
        
        guard case .number(let v1) = values[0],
              case .number(let v2) = values[1] else {
            XCTFail("Expected numbers")
            return
        }
        
        XCTAssertEqual(v1, 1)
        XCTAssertEqual(v2, 2)
    }
    
    func testStrictModeRejectsShortInlineArray() throws {
        let toonText = """
        values[5]: 1,2
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: false))
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.inlineArrayLengthMismatch = error else {
                XCTFail("Expected inlineArrayLengthMismatch, got: \(error)")
                return
            }
        }
    }
    
    func testStrictModeRejectsLongInlineArray() throws {
        let toonText = """
        values[2]: 1,2,3,4
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: false))
        
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.inlineArrayLengthMismatch = error else {
                XCTFail("Expected inlineArrayLengthMismatch, got: \(error)")
                return
            }
        }
    }
    
    // MARK: - Nested Lenient Tests
    
    func testLenientWorksWithNestedStructures() throws {
        let toonText = """
        outer:
          inner[3]:
            - a
            - b
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .object(let outer) = obj["outer"],
              case .array(let inner) = outer["inner"] else {
            XCTFail("Expected nested structure")
            return
        }
        
        XCTAssertEqual(inner.count, 3)
        XCTAssertEqual(inner[2], .null) // Padded
    }
    
    func testLenientDoesNotAffectNonArrayValues() throws {
        let toonText = """
        name: John
        age: 30
        """
        var parser = try Parser(input: toonText, options: Parser.Options(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .string(let name) = obj["name"],
              case .number(let age) = obj["age"] else {
            XCTFail("Expected simple object")
            return
        }
        
        XCTAssertEqual(name, "John")
        XCTAssertEqual(age, 30)
    }
}
