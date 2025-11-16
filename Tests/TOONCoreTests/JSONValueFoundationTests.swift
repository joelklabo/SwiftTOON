import XCTest
import Foundation
@testable import TOONCore

final class JSONValueFoundationTests: XCTestCase {
    
    // MARK: - toAny() Conversion Tests
    
    func testObjectToAny() {
        let jsonValue = JSONValue.object(["key": .string("value")])
        let result = jsonValue.toAny()
        
        guard let dict = result as? [String: Any],
              let value = dict["key"] as? String else {
            XCTFail("Expected dictionary with string value")
            return
        }
        
        XCTAssertEqual(value, "value")
    }
    
    func testArrayToAny() {
        let jsonValue = JSONValue.array([.string("a"), .string("b")])
        let result = jsonValue.toAny()
        
        guard let array = result as? [Any] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0] as? String, "a")
        XCTAssertEqual(array[1] as? String, "b")
    }
    
    func testStringToAny() {
        let jsonValue = JSONValue.string("test")
        let result = jsonValue.toAny()
        
        XCTAssertEqual(result as? String, "test")
    }
    
    func testNumberToAny() {
        let jsonValue = JSONValue.number(42.5)
        let result = jsonValue.toAny()
        
        XCTAssertEqual(result as? Double, 42.5)
    }
    
    func testBoolToAny() {
        let jsonValueTrue = JSONValue.bool(true)
        let jsonValueFalse = JSONValue.bool(false)
        
        XCTAssertEqual(jsonValueTrue.toAny() as? Bool, true)
        XCTAssertEqual(jsonValueFalse.toAny() as? Bool, false)
    }
    
    func testNullToAny() {
        let jsonValue = JSONValue.null
        let result = jsonValue.toAny()
        
        XCTAssertTrue(result is NSNull)
    }
    
    func testNestedObjectToAny() {
        let jsonValue = JSONValue.object([
            "outer": .object(["inner": .string("nested")])
        ])
        let result = jsonValue.toAny()
        
        guard let dict = result as? [String: Any],
              let outer = dict["outer"] as? [String: Any],
              let inner = outer["inner"] as? String else {
            XCTFail("Expected nested dictionary")
            return
        }
        
        XCTAssertEqual(inner, "nested")
    }
    
    func testNestedArrayToAny() {
        let jsonValue = JSONValue.array([
            .array([.number(1), .number(2)]),
            .array([.number(3), .number(4)])
        ])
        let result = jsonValue.toAny()
        
        guard let array = result as? [Any],
              let first = array[0] as? [Any] else {
            XCTFail("Expected nested array")
            return
        }
        
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(first[0] as? Double, 1.0)
    }
    
    func testMixedTypesToAny() {
        let jsonValue = JSONValue.object([
            "string": .string("text"),
            "number": .number(123),
            "bool": .bool(true),
            "null": .null,
            "array": .array([.number(1), .number(2)]),
            "object": .object(["nested": .string("value")])
        ])
        let result = jsonValue.toAny()
        
        guard let dict = result as? [String: Any] else {
            XCTFail("Expected dictionary")
            return
        }
        
        XCTAssertEqual(dict["string"] as? String, "text")
        XCTAssertEqual(dict["number"] as? Double, 123)
        XCTAssertEqual(dict["bool"] as? Bool, true)
        XCTAssertTrue(dict["null"] is NSNull)
        XCTAssertNotNil(dict["array"] as? [Any])
        XCTAssertNotNil(dict["object"] as? [String: Any])
    }
    
    // MARK: - init(jsonObject:) Conversion Tests
    
    func testDictionaryToJSONValue() throws {
        let dict: [String: Any] = ["key": "value"]
        let jsonValue = try JSONValue(jsonObject: dict)
        
        guard case .object(let obj) = jsonValue,
              case .string(let str) = obj["key"] else {
            XCTFail("Expected object with string value")
            return
        }
        
        XCTAssertEqual(str, "value")
    }
    
    func testArrayToJSONValue() throws {
        let array: [Any] = ["a", "b", "c"]
        let jsonValue = try JSONValue(jsonObject: array)
        
        guard case .array(let arr) = jsonValue else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(arr.count, 3)
        guard case .string(let first) = arr[0] else {
            XCTFail("Expected string")
            return
        }
        XCTAssertEqual(first, "a")
    }
    
    func testStringToJSONValue() throws {
        let jsonValue = try JSONValue(jsonObject: "test" as Any)
        
        guard case .string(let str) = jsonValue else {
            XCTFail("Expected string")
            return
        }
        
        XCTAssertEqual(str, "test")
    }
    
    func testNumberToJSONValue() throws {
        let jsonValue = try JSONValue(jsonObject: NSNumber(value: 42.5))
        
        guard case .number(let num) = jsonValue else {
            XCTFail("Expected number")
            return
        }
        
        XCTAssertEqual(num, 42.5)
    }
    
    func testBoolToJSONValue() throws {
        let jsonValueTrue = try JSONValue(jsonObject: NSNumber(value: true))
        let jsonValueFalse = try JSONValue(jsonObject: NSNumber(value: false))
        
        guard case .bool(let t) = jsonValueTrue,
              case .bool(let f) = jsonValueFalse else {
            XCTFail("Expected bool values")
            return
        }
        
        XCTAssertTrue(t)
        XCTAssertFalse(f)
    }
    
    func testNSNullToJSONValue() throws {
        let jsonValue = try JSONValue(jsonObject: NSNull())
        
        guard case .null = jsonValue else {
            XCTFail("Expected null")
            return
        }
    }
    
    func testIntegerToJSONValue() throws {
        let jsonValue = try JSONValue(jsonObject: NSNumber(value: 42))
        
        guard case .number(let num) = jsonValue else {
            XCTFail("Expected number")
            return
        }
        
        XCTAssertEqual(num, 42.0)
    }
    
    func testNestedDictionaryToJSONValue() throws {
        let dict: [String: Any] = [
            "outer": [
                "inner": "nested"
            ]
        ]
        let jsonValue = try JSONValue(jsonObject: dict)
        
        guard case .object(let obj) = jsonValue,
              case .object(let outer) = obj["outer"],
              case .string(let inner) = outer["inner"] else {
            XCTFail("Expected nested object")
            return
        }
        
        XCTAssertEqual(inner, "nested")
    }
    
    func testNestedArrayToJSONValue() throws {
        let array: [Any] = [
            [1, 2],
            [3, 4]
        ]
        let jsonValue = try JSONValue(jsonObject: array)
        
        guard case .array(let arr) = jsonValue,
              case .array(let first) = arr[0] else {
            XCTFail("Expected nested array")
            return
        }
        
        XCTAssertEqual(first.count, 2)
    }
    
    func testMixedTypesToJSONValue() throws {
        let dict: [String: Any] = [
            "string": "text",
            "number": NSNumber(value: 123),
            "bool": NSNumber(value: true),
            "null": NSNull(),
            "array": [1, 2, 3],
            "object": ["nested": "value"]
        ]
        let jsonValue = try JSONValue(jsonObject: dict)
        
        guard case .object(let obj) = jsonValue else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertNotNil(obj["string"])
        XCTAssertNotNil(obj["number"])
        XCTAssertNotNil(obj["bool"])
        XCTAssertNotNil(obj["null"])
        XCTAssertNotNil(obj["array"])
        XCTAssertNotNil(obj["object"])
    }
    
    func testUnsupportedTypeThrows() {
        let unsupported = Date() as Any
        
        XCTAssertThrowsError(try JSONValue(jsonObject: unsupported)) { error in
            XCTAssertTrue(error is JSONValueConversionError)
        }
    }
    
    func testEmptyDictionary() throws {
        let dict: [String: Any] = [:]
        let jsonValue = try JSONValue(jsonObject: dict)
        
        guard case .object(let obj) = jsonValue else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(obj.count, 0)
    }
    
    func testEmptyArray() throws {
        let array: [Any] = []
        let jsonValue = try JSONValue(jsonObject: array)
        
        guard case .array(let arr) = jsonValue else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(arr.count, 0)
    }
    
    // MARK: - Round-Trip Tests
    
    func testRoundTripObject() throws {
        let original = JSONValue.object([
            "key1": .string("value1"),
            "key2": .number(42)
        ])
        
        let any = original.toAny()
        let converted = try JSONValue(jsonObject: any)
        
        XCTAssertEqual(original, converted)
    }
    
    func testRoundTripArray() throws {
        let original = JSONValue.array([
            .string("a"),
            .number(1),
            .bool(true),
            .null
        ])
        
        let any = original.toAny()
        let converted = try JSONValue(jsonObject: any)
        
        XCTAssertEqual(original, converted)
    }
    
    func testRoundTripNestedStructure() throws {
        let original = JSONValue.object([
            "array": .array([
                .object(["nested": .string("deep")]),
                .number(123)
            ]),
            "bool": .bool(false)
        ])
        
        let any = original.toAny()
        let converted = try JSONValue(jsonObject: any)
        
        XCTAssertEqual(original, converted)
    }
}
