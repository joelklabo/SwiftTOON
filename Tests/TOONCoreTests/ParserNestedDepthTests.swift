import XCTest
@testable import TOONCore

final class ParserNestedDepthTests: XCTestCase {
    
    // MARK: - Deeply Nested Objects
    
    func testDeeplyNestedObjects() throws {
        let toonText = """
        level1:
          level2:
            level3:
              level4:
                level5:
                  value: deep
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let l1) = result,
              case .object(let l2) = l1["level1"],
              case .object(let l3) = l2["level2"],
              case .object(let l4) = l3["level3"],
              case .object(let l5) = l4["level4"],
              case .object(let l6) = l5["level5"],
              case .string(let value) = l6["value"] else {
            XCTFail("Expected deeply nested structure")
            return
        }
        
        XCTAssertEqual(value, "deep")
    }
    
    func testDeeplyNestedArrays() throws {
        let toonText = """
        outer[1]:
          - inner[1]:
            - innermost[1]:
              - deepest
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let outer) = obj["outer"],
              case .array(let inner) = outer[0],
              case .array(let innermost) = inner[0],
              case .string(let value) = innermost[0] else {
            XCTFail("Expected deeply nested arrays")
            return
        }
        
        XCTAssertEqual(value, "deepest")
    }
    
    func testMixedNestedStructures() throws {
        let toonText = """
        root:
          objects[2]:
            - items[2]:
              - nested:
                  value: mixed
              - simple
            - second:
                deep: value
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let root) = result,
              case .object(let rootObj) = root["root"],
              case .array(let objects) = rootObj["objects"] else {
            XCTFail("Expected mixed nested structure")
            return
        }
        
        XCTAssertEqual(objects.count, 2)
    }
    
    // MARK: - Complex Nesting Patterns
    
    func testArrayOfObjectsWithNestedArrays() throws {
        let toonText = """
        users[2]:
          - name: Alice
            tags[3]: a,b,c
          - name: Bob  
            tags[2]: x,y
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let users) = obj["users"],
              case .object(let user1) = users[0],
              case .array(let tags1) = user1["tags"] else {
            XCTFail("Expected array of objects with nested arrays")
            return
        }
        
        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(tags1.count, 3)
    }
    
    func testObjectWithMultipleNestedArrayTypes() throws {
        let toonText = """
        data:
          inline[2]: a,b
          list[2]:
            - first
            - second
          tabular[2]{x,y}:
            1,2
            3,4
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .object(let data) = obj["data"],
              case .array(let inline) = data["inline"],
              case .array(let list) = data["list"],
              case .array(let tabular) = data["tabular"] else {
            XCTFail("Expected object with multiple array types")
            return
        }
        
        XCTAssertEqual(inline.count, 2)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(tabular.count, 2)
    }
    
    // MARK: - Indentation Edge Cases
    
    func testInconsistentButValidIndentation() throws {
        // Parser should handle valid multi-level indentation
        let toonText = """
        level1:
          level2a:
            level3a: value1
          level2b:
            level3b: value2
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .object(let l1) = obj["level1"],
              case .object(let l2a) = l1["level2a"],
              case .string(let v1) = l2a["level3a"],
              case .object(let l2b) = l1["level2b"],
              case .string(let v2) = l2b["level3b"] else {
            XCTFail("Expected multi-level structure")
            return
        }
        
        XCTAssertEqual(v1, "value1")
        XCTAssertEqual(v2, "value2")
    }
    
    func testDedentToRootLevel() throws {
        let toonText = """
        first:
          nested:
            deep: value
        second: backToRoot
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .object = obj["first"],
              case .string(let second) = obj["second"] else {
            XCTFail("Expected dedent to root")
            return
        }
        
        XCTAssertEqual(second, "backToRoot")
    }
    
    // MARK: - Array Nesting Complexity
    
    func testTabularArrayWithNestedObjects() throws {
        let toonText = """
        items[2]{id,meta}:
          1,key: value
          2,another: data
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"],
              case .object(let item1) = items[0] else {
            XCTFail("Expected tabular array with objects")
            return
        }
        
        XCTAssertEqual(items.count, 2)
        XCTAssertNotNil(item1["id"])
        XCTAssertNotNil(item1["meta"])
    }
    
    func testListArrayWithComplexItems() throws {
        let toonText = """
        items[3]:
          - simple
          - nested:
              value: complex
          - inline[2]: x,y
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected list array")
            return
        }
        
        XCTAssertEqual(items.count, 3)
        
        guard case .string(let first) = items[0],
              case .object(let second) = items[1],
              case .array(let third) = items[2] else {
            XCTFail("Expected mixed item types")
            return
        }
        
        XCTAssertEqual(first, "simple")
        XCTAssertNotNil(second["nested"])
        XCTAssertEqual(third.count, 2)
    }
}
