import XCTest
@testable import TOONCodable
@testable import TOONCore

/// Comprehensive coverage tests for JSONValueEncoder to achieve 95%+
final class JSONValueEncoderCoverageTests: XCTestCase {
    
    // MARK: - All Integer Type Coverage
    
    func testEncodeAllIntegerTypes() throws {
        struct AllInts: Codable {
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
        
        let value = AllInts(
            i8: -128,
            i16: -32768,
            i32: -2147483648,
            i64: -9223372036854775808,
            u: 42,
            u8: 255,
            u16: 65535,
            u32: 4294967295,
            u64: 18446744073709551615
        )
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(value)
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(obj["i8"], .number(-128))
        XCTAssertEqual(obj["i16"], .number(-32768))
        XCTAssertEqual(obj["i32"], .number(-2147483648))
        XCTAssertEqual(obj["i64"], .number(Double(-9223372036854775808)))
        XCTAssertEqual(obj["u"], .number(42))
        XCTAssertEqual(obj["u8"], .number(255))
        XCTAssertEqual(obj["u16"], .number(65535))
        XCTAssertEqual(obj["u32"], .number(4294967295))
    }
    
    func testEncodeIntegerTypesInArray() throws {
        struct IntArray: Codable {
            let values: [Int8]
            let unsigned: [UInt16]
        }
        
        let value = IntArray(values: [-1, 0, 127], unsigned: [0, 100, 65535])
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(value)
        
        guard case .object(let obj) = result,
              case .array(let vals) = obj["values"],
              case .array(let unsignedVals) = obj["unsigned"] else {
            XCTFail("Expected arrays")
            return
        }
        
        XCTAssertEqual(vals, [.number(-1), .number(0), .number(127)])
        XCTAssertEqual(unsignedVals, [.number(0), .number(100), .number(65535)])
    }
    
    // MARK: - Nested Container Coverage
    
    func testNestedKeyedContainer() throws {
        struct Outer: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                var nested = container.nestedContainer(keyedBy: NestedKeys.self, forKey: .data)
                try nested.encode("value1", forKey: .field1)
                try nested.encode(42, forKey: .field2)
            }
            
            enum CodingKeys: String, CodingKey {
                case data
            }
            
            enum NestedKeys: String, CodingKey {
                case field1, field2
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Outer())
        
        guard case .object(let obj) = result,
              case .object(let nested) = obj["data"] else {
            XCTFail("Expected nested object")
            return
        }
        
        XCTAssertEqual(nested["field1"], .string("value1"))
        XCTAssertEqual(nested["field2"], .number(42))
    }
    
    func testNestedUnkeyedContainer() throws {
        struct Outer: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                var nested = container.nestedUnkeyedContainer(forKey: .items)
                try nested.encode("a")
                try nested.encode("b")
                try nested.encode(123)
            }
            
            enum CodingKeys: String, CodingKey {
                case items
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Outer())
        
        guard case .object(let obj) = result,
              case .array(let items) = obj["items"] else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertEqual(items, [.string("a"), .string("b"), .number(123)])
    }
    
    func testNestedContainerInArray() throws {
        struct Outer: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                var nested = container.nestedContainer(keyedBy: CodingKeys.self)
                try nested.encode("test", forKey: .key)
            }
            
            enum CodingKeys: String, CodingKey {
                case key
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Outer())
        
        guard case .array(let arr) = result,
              arr.count == 1,
              case .object(let obj) = arr[0] else {
            XCTFail("Expected array with object")
            return
        }
        
        XCTAssertEqual(obj["key"], .string("test"))
    }
    
    func testNestedUnkeyedInArray() throws {
        struct Outer: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                var nested = container.nestedUnkeyedContainer()
                try nested.encode(1)
                try nested.encode(2)
                try nested.encode(3)
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Outer())
        
        guard case .array(let arr) = result,
              arr.count == 1,
              case .array(let nested) = arr[0] else {
            XCTFail("Expected nested array")
            return
        }
        
        XCTAssertEqual(nested, [.number(1), .number(2), .number(3)])
    }
    
    // MARK: - Super Encoder Coverage
    
    func testSuperEncoderInKeyedContainer() throws {
        class Base: Codable {
            let baseValue: String
            init(baseValue: String) {
                self.baseValue = baseValue
            }
        }
        
        class Derived: Base {
            let derivedValue: Int
            
            init(baseValue: String, derivedValue: Int) {
                self.derivedValue = derivedValue
                super.init(baseValue: baseValue)
            }
            
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                derivedValue = try container.decode(Int.self, forKey: .derivedValue)
                let superDecoder = try container.superDecoder()
                try super.init(from: superDecoder)
            }
            
            override func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(derivedValue, forKey: .derivedValue)
                let superEncoder = container.superEncoder()
                try super.encode(to: superEncoder)
            }
            
            enum CodingKeys: String, CodingKey {
                case derivedValue
            }
        }
        
        let encoder = JSONValueEncoder()
        let value = Derived(baseValue: "base", derivedValue: 42)
        let result = try encoder.encode(value)
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(obj["derivedValue"], .number(42))
        XCTAssert(obj["super"] != nil)
    }
    
    func testSuperEncoderForKeyInKeyedContainer() throws {
        struct Custom: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                let superEncoder = container.superEncoder(forKey: .custom)
                var superContainer = superEncoder.singleValueContainer()
                try superContainer.encode("superValue")
            }
            
            enum CodingKeys: String, CodingKey {
                case custom
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Custom())
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertEqual(obj["custom"], .string("superValue"))
    }
    
    func testSuperEncoderInUnkeyedContainer() throws {
        struct Custom: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode("first")
                let superEncoder = container.superEncoder()
                var superContainer = superEncoder.singleValueContainer()
                try superContainer.encode("superValue")
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Custom())
        
        guard case .array(let arr) = result, arr.count == 2 else {
            XCTFail("Expected array with 2 elements")
            return
        }
        
        XCTAssertEqual(arr[0], .string("first"))
        XCTAssertEqual(arr[1], .string("superValue"))
    }
    
    // MARK: - Single Value Container Coverage
    
    func testSingleValueContainerAllTypes() throws {
        let encoder = JSONValueEncoder()
        
        // Nil
        XCTAssertEqual(try encoder.encode(Optional<String>.none), .null)
        
        // Bool
        XCTAssertEqual(try encoder.encode(true), .bool(true))
        XCTAssertEqual(try encoder.encode(false), .bool(false))
        
        // String
        XCTAssertEqual(try encoder.encode("test"), .string("test"))
        
        // Numbers
        XCTAssertEqual(try encoder.encode(42.5), .number(42.5))
        // Float has precision loss when converted to Double
        let floatResult = try encoder.encode(Float(3.14))
        guard case .number(let num) = floatResult else {
            XCTFail("Expected number")
            return
        }
        XCTAssertEqual(num, Double(Float(3.14)), accuracy: 0.001)
        XCTAssertEqual(try encoder.encode(Int(123)), .number(123))
        XCTAssertEqual(try encoder.encode(Int8(-128)), .number(-128))
        XCTAssertEqual(try encoder.encode(Int16(32000)), .number(32000))
        XCTAssertEqual(try encoder.encode(Int32(-2000000)), .number(-2000000))
        XCTAssertEqual(try encoder.encode(Int64(9000000000)), .number(9000000000))
        XCTAssertEqual(try encoder.encode(UInt(99)), .number(99))
        XCTAssertEqual(try encoder.encode(UInt8(255)), .number(255))
        XCTAssertEqual(try encoder.encode(UInt16(60000)), .number(60000))
        XCTAssertEqual(try encoder.encode(UInt32(4000000000)), .number(4000000000))
        XCTAssertEqual(try encoder.encode(UInt64(18000000000000000000)), .number(18000000000000000000))
    }
    
    // MARK: - Empty Container Coverage
    
    func testEmptyObject() throws {
        struct Empty: Codable {}
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Empty())
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        XCTAssertTrue(obj.isEmpty)
    }
    
    func testEmptyArray() throws {
        let encoder = JSONValueEncoder()
        let result = try encoder.encode([Int]())
        
        guard case .array(let arr) = result else {
            XCTFail("Expected array")
            return
        }
        
        XCTAssertTrue(arr.isEmpty)
    }
    
    // MARK: - Complex Nested Structures
    
    func testDeeplyNestedStructure() throws {
        struct Level3: Codable {
            let value: String
        }
        
        struct Level2: Codable {
            let items: [Level3]
        }
        
        struct Level1: Codable {
            let data: Level2
        }
        
        let value = Level1(data: Level2(items: [Level3(value: "deep")]))
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(value)
        
        guard case .object(let l1) = result,
              case .object(let l2) = l1["data"],
              case .array(let items) = l2["items"],
              case .object(let l3) = items[0] else {
            XCTFail("Expected deeply nested structure")
            return
        }
        
        XCTAssertEqual(l3["value"], .string("deep"))
    }
    
    func testMixedNestedContainers() throws {
        struct Mixed: Encodable {
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                // Nested object
                var nested = container.nestedContainer(keyedBy: NestedKeys.self, forKey: .object)
                try nested.encode("value", forKey: .field)
                
                // Nested array
                var array = container.nestedUnkeyedContainer(forKey: .array)
                try array.encode(1)
                try array.encode(2)
                
                // Nested array of objects
                var arrayOfObjects = container.nestedUnkeyedContainer(forKey: .arrayOfObjects)
                var obj1 = arrayOfObjects.nestedContainer(keyedBy: ItemKeys.self)
                try obj1.encode("item1", forKey: .name)
                var obj2 = arrayOfObjects.nestedContainer(keyedBy: ItemKeys.self)
                try obj2.encode("item2", forKey: .name)
            }
            
            enum CodingKeys: String, CodingKey {
                case object, array, arrayOfObjects
            }
            
            enum NestedKeys: String, CodingKey {
                case field
            }
            
            enum ItemKeys: String, CodingKey {
                case name
            }
        }
        
        let encoder = JSONValueEncoder()
        let result = try encoder.encode(Mixed())
        
        guard case .object(let obj) = result else {
            XCTFail("Expected object")
            return
        }
        
        // Verify nested object
        guard case .object(let nestedObj) = obj["object"] else {
            XCTFail("Expected nested object")
            return
        }
        XCTAssertEqual(nestedObj["field"], .string("value"))
        
        // Verify nested array
        guard case .array(let arr) = obj["array"] else {
            XCTFail("Expected array")
            return
        }
        XCTAssertEqual(arr, [.number(1), .number(2)])
        
        // Verify array of objects
        guard case .array(let arrOfObjs) = obj["arrayOfObjects"],
              arrOfObjs.count == 2,
              case .object(let item1) = arrOfObjs[0],
              case .object(let item2) = arrOfObjs[1] else {
            XCTFail("Expected array of objects")
            return
        }
        XCTAssertEqual(item1["name"], .string("item1"))
        XCTAssertEqual(item2["name"], .string("item2"))
    }
    
    // MARK: - User Info Coverage
    
    func testUserInfo() throws {
        struct Custom: Encodable {
            func encode(to encoder: Encoder) throws {
                XCTAssertNotNil(encoder.userInfo[testKey])
                XCTAssertEqual(encoder.userInfo[testKey] as? String, "testValue")
                // Must actually encode something to avoid invalidValue error
                var container = encoder.singleValueContainer()
                try container.encode("dummy")
            }
        }
        
        let encoder = JSONValueEncoder()
        encoder.userInfo[testKey] = "testValue"
        _ = try encoder.encode(Custom())
    }
    
    // MARK: - Coding Path Coverage
    
    func testCodingPathInNestedStructures() throws {
        struct Recorder: Encodable {
            var recordedPath: [String] = []
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                var nested = container.nestedContainer(keyedBy: NestedKeys.self, forKey: .nested)
                
                // Record the coding path at this level
                let path = nested.codingPath.map { $0.stringValue }
                XCTAssertEqual(path, ["nested"])
            }
            
            enum CodingKeys: String, CodingKey {
                case nested
            }
            
            enum NestedKeys: String, CodingKey {
                case field
            }
        }
        
        let encoder = JSONValueEncoder()
        _ = try encoder.encode(Recorder())
    }
    
    // MARK: - Error Cases
    
    func testEncodingErrorForInvalidValue() throws {
        struct NoOutput: Encodable {
            func encode(to encoder: Encoder) throws {
                // Don't encode anything
            }
        }
        
        let encoder = JSONValueEncoder()
        XCTAssertThrowsError(try encoder.encode(NoOutput())) { error in
            guard case EncodingError.invalidValue = error else {
                XCTFail("Expected invalidValue error")
                return
            }
        }
    }
}

private let testKey = CodingUserInfoKey(rawValue: "test")!
