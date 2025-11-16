import XCTest
import TOONCore
@testable import TOONCodable

final class JSONValueDecoderErrorTests: XCTestCase {
    
    // MARK: - Type Mismatch Errors
    
    func testDecodeStringFromNumber() throws {
        struct TestStruct: Decodable {
            let value: String
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(42))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch, got \(error)")
                return
            }
        }
    }
    
    func testDecodeNumberFromString() throws {
        struct TestStruct: Decodable {
            let value: Double
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .string("not a number"))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch, got \(error)")
                return
            }
        }
    }
    
    func testDecodeBoolFromNumber() throws {
        struct TestStruct: Decodable {
            let value: Bool
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(1))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch, got \(error)")
                return
            }
        }
    }
    
    func testDecodeArrayFromObject() throws {
        struct TestStruct: Decodable {
            let value: [Int]
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .object(JSONObject()))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch, got \(error)")
                return
            }
        }
    }
    
    func testDecodeObjectFromArray() throws {
        struct Inner: Decodable {
            let key: String
        }
        struct TestStruct: Decodable {
            let value: Inner
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .array([.string("item")]))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Missing Key Errors
    
    func testDecodeMissingRequiredKey() throws {
        struct TestStruct: Decodable {
            let required: String
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("other", .string("value"))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case let DecodingError.keyNotFound(key, _) = error else {
                XCTFail("Expected keyNotFound, got \(error)")
                return
            }
            XCTAssertEqual(key.stringValue, "required")
        }
    }
    
    func testDecodeMultipleMissingKeys() throws {
        struct TestStruct: Decodable {
            let first: String
            let second: Int
        }
        
        let jsonValue = JSONValue.object(JSONObject())
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.keyNotFound = error else {
                XCTFail("Expected keyNotFound, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Number Conversion Errors
    
    func testDecodeIntFromFloat() throws {
        struct TestStruct: Decodable {
            let value: Int
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(3.14))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted, got \(error)")
                return
            }
        }
    }
    
    func testDecodeInt8Overflow() throws {
        struct TestStruct: Decodable {
            let value: Int8
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(256))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted for Int8 overflow, got \(error)")
                return
            }
        }
    }
    
    func testDecodeInt8Underflow() throws {
        struct TestStruct: Decodable {
            let value: Int8
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(-200))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted for Int8 underflow, got \(error)")
                return
            }
        }
    }
    
    func testDecodeUInt8Negative() throws {
        struct TestStruct: Decodable {
            let value: UInt8
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(-1))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted for UInt8 negative, got \(error)")
                return
            }
        }
    }
    
    func testDecodeInt16Overflow() throws {
        struct TestStruct: Decodable {
            let value: Int16
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(40000))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted for Int16 overflow, got \(error)")
                return
            }
        }
    }
    
    func testDecodeInt32Overflow() throws {
        struct TestStruct: Decodable {
            let value: Int32
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(3_000_000_000))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted for Int32 overflow, got \(error)")
                return
            }
        }
    }
    
    func testDecodeUIntOverflow() throws {
        struct TestStruct: Decodable {
            let value: UInt
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(Double(UInt64.max)))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected dataCorrupted for UInt overflow, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Array Container Errors
    
    func testUnkeyedContainerAtEnd() throws {
        struct TestStruct: Decodable {
            let items: [String]
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var items: [String] = []
                
                // Try to read more items than exist
                for _ in 0..<5 {
                    if !container.isAtEnd {
                        items.append(try container.decode(String.self))
                    }
                }
                
                // This should throw
                if !container.isAtEnd {
                    _ = try container.decode(String.self)
                }
                
                self.items = items
            }
        }
        
        let jsonValue = JSONValue.array([.string("a"), .string("b")])
        let decoder = JSONValueDecoder()
        
        // Should succeed because we check isAtEnd
        let result = try decoder.decode(TestStruct.self, from: jsonValue)
        XCTAssertEqual(result.items.count, 2)
    }
    
    func testUnkeyedContainerValueNotFound() throws {
        struct TestStruct: Decodable {
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                _ = try container.decode(String.self)
                _ = try container.decode(String.self)
                // This should throw - past the end
                _ = try container.decode(String.self)
            }
        }
        
        let jsonValue = JSONValue.array([.string("a")])
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.valueNotFound = error else {
                XCTFail("Expected valueNotFound, got \(error)")
                return
            }
        }
    }
    
    func testDecodeTypeMismatchInArray() throws {
        struct TestStruct: Decodable {
            let items: [Int]
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral:
            ("items", .array([.number(1), .string("not a number"), .number(3)]))
        ))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Nested Container Errors
    
    func testNestedKeyedContainerTypeMismatch() throws {
        struct Inner: Decodable {
            let value: String
        }
        struct TestStruct: Decodable {
            let nested: Inner
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral:
            ("nested", .array([.string("not an object")]))
        ))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch for nested container, got \(error)")
                return
            }
        }
    }
    
    func testNestedUnkeyedContainerTypeMismatch() throws {
        struct TestStruct: Decodable {
            let nested: [[String]]
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral:
            ("nested", .array([.string("not an array")]))
        ))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch for nested unkeyed container, got \(error)")
                return
            }
        }
    }
    
    func testDeepNestedMissingKey() throws {
        struct Level3: Decodable {
            let value: String
        }
        struct Level2: Decodable {
            let level3: Level3
        }
        struct Level1: Decodable {
            let level2: Level2
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral:
            ("level2", .object(JSONObject(dictionaryLiteral:
                ("level3", .object(JSONObject()))
            )))
        ))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(Level1.self, from: jsonValue)) { error in
            guard case DecodingError.keyNotFound = error else {
                XCTFail("Expected keyNotFound in nested structure, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Super Decoder Errors
    
    func testSuperDecoderWithMissingKey() throws {
        class TestClass: Decodable {
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _ = try container.superDecoder()
            }
            
            enum CodingKeys: String, CodingKey {
                case `super`
            }
        }
        
        let jsonValue = JSONValue.object(JSONObject())
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestClass.self, from: jsonValue)) { error in
            guard case DecodingError.keyNotFound = error else {
                XCTFail("Expected keyNotFound for super decoder, got \(error)")
                return
            }
        }
    }
    
    func testSuperDecoderForKeyWithMissingValue() throws {
        class TestClass: Decodable {
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _ = try container.superDecoder(forKey: .custom)
            }
            
            enum CodingKeys: String, CodingKey {
                case custom
            }
        }
        
        let jsonValue = JSONValue.object(JSONObject())
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestClass.self, from: jsonValue)) { error in
            guard case DecodingError.keyNotFound = error else {
                XCTFail("Expected keyNotFound for super decoder with key, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Float Conversion Edge Cases
    
    func testDecodeFloatFromDouble() throws {
        struct TestStruct: Decodable {
            let value: Float
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(3.14159))))
        let decoder = JSONValueDecoder()
        
        // Should succeed with precision loss
        let result = try decoder.decode(TestStruct.self, from: jsonValue)
        XCTAssertEqual(result.value, Float(3.14159), accuracy: 0.00001)
    }
    
    func testDecodeAllIntegerTypesFromDouble() throws {
        struct TestStruct: Decodable {
            let i: Int
            let i8: Int8
            let i16: Int16
            let i32: Int32
            let i64: Int64
            let u: UInt
            let u8: UInt8
            let u16: UInt16
            let u32: UInt32
            let u64: UInt64
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral:
            ("i", .number(42)),
            ("i8", .number(42)),
            ("i16", .number(42)),
            ("i32", .number(42)),
            ("i64", .number(42)),
            ("u", .number(42)),
            ("u8", .number(42)),
            ("u16", .number(42)),
            ("u32", .number(42)),
            ("u64", .number(42))
        ))
        let decoder = JSONValueDecoder()
        
        let result = try decoder.decode(TestStruct.self, from: jsonValue)
        XCTAssertEqual(result.i, 42)
        XCTAssertEqual(result.i8, 42)
        XCTAssertEqual(result.i16, 42)
        XCTAssertEqual(result.i32, 42)
        XCTAssertEqual(result.i64, 42)
        XCTAssertEqual(result.u, 42)
        XCTAssertEqual(result.u8, 42)
        XCTAssertEqual(result.u16, 42)
        XCTAssertEqual(result.u32, 42)
        XCTAssertEqual(result.u64, 42)
    }
    
    // MARK: - Container Type Mismatch at Decoder Level
    
    func testRequestKeyedContainerFromArray() throws {
        struct TestStruct: Decodable {
            init(from decoder: Decoder) throws {
                _ = try decoder.container(keyedBy: CodingKeys.self)
            }
            enum CodingKeys: CodingKey {}
        }
        
        let jsonValue = JSONValue.array([.string("item")])
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch for keyed container from array, got \(error)")
                return
            }
        }
    }
    
    func testRequestUnkeyedContainerFromObject() throws {
        struct TestStruct: Decodable {
            init(from decoder: Decoder) throws {
                _ = try decoder.unkeyedContainer()
            }
        }
        
        let jsonValue = JSONValue.object(JSONObject(dictionaryLiteral: ("key", .string("value"))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(TestStruct.self, from: jsonValue)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch for unkeyed container from object, got \(error)")
                return
            }
        }
    }
}
