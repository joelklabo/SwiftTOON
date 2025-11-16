import XCTest
@testable import TOONCore

final class ParserEdgeCasesComprehensiveTests: XCTestCase {
    
    // MARK: - Lenient Mode Branches
    
    func testLenientPadsShortInlineArray() throws {
        let toonText = """
        items[3]: a,b
        """
        var parser = try Parser(input: toonText, options: .init(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            return XCTFail("Expected array")
        }
        
        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[0], .string("a"))
        XCTAssertEqual(arr[1], .string("b"))
        XCTAssertEqual(arr[2], .null)  // Padded
    }
    
    func testLenientTruncatesLongInlineArray() throws {
        let toonText = """
        items[2]: a,b,c,d
        """
        var parser = try Parser(input: toonText, options: .init(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            return XCTFail("Expected array")
        }
        
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0], .string("a"))
        XCTAssertEqual(arr[1], .string("b"))
    }
    
    func testLenientPadsShortTabularRow() throws {
        let toonText = """
        items[2]{a,b}:
          x,y
          1
        """
        var parser = try Parser(input: toonText, options: .init(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            return XCTFail("Expected array")
        }
        
        XCTAssertEqual(arr.count, 2)
        // Second row should be padded with null
        if case .object(let row2) = arr[1] {
            XCTAssertEqual(row2.value(forKey: "a"), .string("1"))
            XCTAssertEqual(row2.value(forKey: "b"), .null)
        } else {
            XCTFail("Expected object")
        }
    }
    
    func testLenientHandlesJaggedListArray() throws {
        let toonText = """
        items[3]:
          - a
          - b
        """
        var parser = try Parser(input: toonText, options: .init(lenientArrays: true))
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            return XCTFail("Expected array")
        }
        
        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[0], .string("a"))
        XCTAssertEqual(arr[1], .string("b"))
        XCTAssertEqual(arr[2], .null)  // Padded
    }
    
    func testStrictModeRejectsLenientCases() {
        let toonText = """
        items[3]: a,b
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    // MARK: - EOF Edge Cases
    
    func testEOFInMiddleOfObject() {
        let toonText = """
        key: value
        nested:
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testEOFInMiddleOfArray() {
        let toonText = """
        items[3]:
          - a
          - b
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testEOFAfterColon() {
        let toonText = "key:"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testEOFInTabularHeader() {
        let toonText = """
        items[2]{a,b
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testEOFAfterDash() {
        let toonText = """
        items[1]:
          -
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    // MARK: - Malformed Tabular Arrays
    
    func testTabularMissingClosingBrace() {
        let toonText = """
        items[2]{a,b:
          1,2
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testTabularRowTooShortStrict() {
        let toonText = """
        items[2]{a,b}:
          1,2
          3
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testTabularRowTooLongStrict() {
        let toonText = """
        items[2]{a,b}:
          1,2
          3,4,5
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testTabularWithInvalidDelimiter() {
        let toonText = """
        items[2]{a;b}:
          1,2
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testTabularEmptyHeader() {
        let toonText = """
        items[1]{}:
          1
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    // MARK: - Deep Nesting
    
    func testDeeplyNestedObjects() throws {
        let toonText = """
        a:
          b:
            c:
              d:
                e:
                  f:
                    g: value
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .object(let b) = obj.value(forKey: "a"),
              case .object(let c) = b.value(forKey: "b"),
              case .object(let d) = c.value(forKey: "c"),
              case .object(let e) = d.value(forKey: "d"),
              case .object(let f) = e.value(forKey: "e"),
              case .object(let g) = f.value(forKey: "f"),
              case .string(let val) = g.value(forKey: "g") else {
            return XCTFail("Expected nested objects")
        }
        
        XCTAssertEqual(val, "value")
    }
    
    func testDeeplyNestedArrays() throws {
        let toonText = """
        level1[1]:
          - level2[1]:
              - level3[1]:
                  - value
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr1) = obj.value(forKey: "level1"),
              case .object(let obj2) = arr1[0],
              case .array(let arr2) = obj2.value(forKey: "level2"),
              case .object(let obj3) = arr2[0],
              case .array(let arr3) = obj3.value(forKey: "level3"),
              case .string(let val) = arr3[0] else {
            return XCTFail("Expected nested arrays")
        }
        
        XCTAssertEqual(val, "value")
    }
    
    func testMixedDeepNesting() throws {
        let toonText = """
        outer:
          items[1]:
            - inner:
                data: value
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .object(let outer) = obj.value(forKey: "outer"),
              case .array(let items) = outer.value(forKey: "items"),
              case .object(let item) = items[0],
              case .object(let inner) = item.value(forKey: "inner"),
              case .string(let data) = inner.value(forKey: "data") else {
            return XCTFail("Expected mixed nesting")
        }
        
        XCTAssertEqual(data, "value")
    }
    
    // MARK: - Whitespace/Indent Edge Cases
    
    func testTrailingWhitespaceInValue() throws {
        let toonText = "key: value   "
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .string(let val) = obj.value(forKey: "key") else {
            return XCTFail("Expected string")
        }
        
        // Trailing whitespace should be trimmed
        XCTAssertEqual(val, "value")
    }
    
    func testLeadingWhitespaceBeforeKey() {
        let toonText = "  key: value"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testEmptyLinesIgnored() throws {
        let toonText = """
        key1: value1
        
        key2: value2
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result else {
            return XCTFail("Expected object")
        }
        
        XCTAssertEqual(obj.value(forKey: "key1"), .string("value1"))
        XCTAssertEqual(obj.value(forKey: "key2"), .string("value2"))
    }
    
    func testInconsistentIndentRejected() {
        let toonText = """
        outer:
          key1: value1
            key2: value2
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testIndentWithoutKey() {
        let toonText = "  value"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    // MARK: - Remaining Error Paths
    
    func testUnexpectedTokenAfterValue() {
        let toonText = "key: value extra"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testInvalidArrayLength() {
        let toonText = "items[abc]: value"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testNegativeArrayLength() {
        let toonText = "items[-5]: value"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testZeroArrayLength() throws {
        let toonText = "items[0]:"
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items") else {
            return XCTFail("Expected empty array")
        }
        
        XCTAssertTrue(arr.isEmpty)
    }
    
    func testMissingColonAfterKey() {
        let toonText = "key value"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testDoubleColon() {
        let toonText = "key:: value"
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    // MARK: - List Array Edge Cases
    
    func testListArrayWithExtraIndent() {
        let toonText = """
        items[2]:
          - value1
            - value2
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testListArrayMissingDash() {
        let toonText = """
        items[2]:
          - value1
          value2
        """
        XCTAssertThrowsError(try Parser(input: toonText).parse())
    }
    
    func testListArrayNestedObject() throws {
        let toonText = """
        items[1]:
          - nested:
              key: value
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result,
              case .array(let arr) = obj.value(forKey: "items"),
              case .object(let item) = arr[0],
              case .object(let nested) = item.value(forKey: "nested"),
              case .string(let val) = nested.value(forKey: "key") else {
            return XCTFail("Expected nested object in list")
        }
        
        XCTAssertEqual(val, "value")
    }
    
    // MARK: - Complex Scenarios
    
    func testMultipleTopLevelKeys() throws {
        let toonText = """
        key1: value1
        key2: value2
        key3: value3
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result else {
            return XCTFail("Expected object")
        }
        
        XCTAssertEqual(obj.value(forKey: "key1"), .string("value1"))
        XCTAssertEqual(obj.value(forKey: "key2"), .string("value2"))
        XCTAssertEqual(obj.value(forKey: "key3"), .string("value3"))
    }
    
    func testMixedArrayFormats() throws {
        let toonText = """
        inline[2]: a,b
        list[2]:
          - c
          - d
        tabular[2]{x}:
          1
          2
        """
        var parser = try Parser(input: toonText)
        let result = try parser.parse()
        
        guard case .object(let obj) = result else {
            return XCTFail("Expected object")
        }
        
        // Check all three array types parsed correctly
        if case .array(let inline) = obj.value(forKey: "inline") {
            XCTAssertEqual(inline.count, 2)
        } else {
            XCTFail("Expected inline array")
        }
        
        if case .array(let list) = obj.value(forKey: "list") {
            XCTAssertEqual(list.count, 2)
        } else {
            XCTFail("Expected list array")
        }
        
        if case .array(let tabular) = obj.value(forKey: "tabular") {
            XCTAssertEqual(tabular.count, 2)
        } else {
            XCTFail("Expected tabular array")
        }
    }
}
