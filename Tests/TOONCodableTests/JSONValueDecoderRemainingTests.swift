import XCTest
@testable import TOONCodable
@testable import TOONCore

/// Target remaining JSONValueDecoder coverage gaps (76.63% → 95%+)
final class JSONValueDecoderRemainingTests: XCTestCase {
    
    // MARK: - KeyedContainer.allKeys Coverage
    
    struct DynamicKeys: Decodable {
        let keys: [String]
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: AnyCodingKey.self)
            self.keys = container.allKeys.map(\.stringValue).sorted()
        }
    }
    
    func testKeyedContainerAllKeys() throws {
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("name", .string("Alice")),
            ("age", .number(30)),
            ("active", .bool(true))
        ))
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(DynamicKeys.self, from: json)
        
        XCTAssertEqual(result.keys, ["active", "age", "name"])
    }
    
    // MARK: - Integer Type Conversions
    
    func testDecodeUInt16() throws {
        struct Container: Decodable {
            let value: UInt16
        }
        
        let json = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(500))))
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(Container.self, from: json)
        
        XCTAssertEqual(result.value, 500)
    }
    
    func testDecodeUInt32() throws {
        struct Container: Decodable {
            let value: UInt32
        }
        
        let json = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(100000))))
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(Container.self, from: json)
        
        XCTAssertEqual(result.value, 100000)
    }
    
    func testDecodeUInt64() throws {
        struct Container: Decodable {
            let value: UInt64
        }
        
        let json = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(9876543210))))
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(Container.self, from: json)
        
        XCTAssertEqual(result.value, 9876543210)
    }
    
    // MARK: - UnkeyedContainer.count
    
    struct ArrayCounter: Decodable {
        let count: Int?
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            self.count = container.count
        }
    }
    
    func testUnkeyedContainerCount() throws {
        let json = JSONValue.array([.string("a"), .string("b"), .string("c")])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(ArrayCounter.self, from: json)
        
        XCTAssertEqual(result.count, 3)
    }
    
    // MARK: - UnkeyedContainer Integer Types
    
    struct UnkeyedIntegers: Decodable {
        let uint8: UInt8
        let uint16: UInt16
        let uint32: UInt32
        let uint64: UInt64
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            self.uint8 = try container.decode(UInt8.self)
            self.uint16 = try container.decode(UInt16.self)
            self.uint32 = try container.decode(UInt32.self)
            self.uint64 = try container.decode(UInt64.self)
        }
    }
    
    func testUnkeyedContainerIntegerTypes() throws {
        let json = JSONValue.array([
            .number(255),
            .number(65535),
            .number(4294967295),
            .number(1234567890123) // Large but within Double precision
        ])
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(UnkeyedIntegers.self, from: json)
        
        XCTAssertEqual(result.uint8, 255)
        XCTAssertEqual(result.uint16, 65535)
        XCTAssertEqual(result.uint32, 4294967295)
        XCTAssertEqual(result.uint64, 1234567890123)
    }
    
    // MARK: - Nested Containers
    
    struct NestedStructure: Decodable {
        let outer: Nested
        
        struct Nested: Decodable {
            let inner: String
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let nestedContainer = try container.nestedContainer(keyedBy: NestedKeys.self, forKey: .outer)
            let innerValue = try nestedContainer.decode(String.self, forKey: .inner)
            self.outer = Nested(inner: innerValue)
        }
        
        enum CodingKeys: String, CodingKey {
            case outer
        }
        
        enum NestedKeys: String, CodingKey {
            case inner
        }
    }
    
    func testNestedKeyedContainer() throws {
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("outer", .object(JSONObject(dictionaryLiteral:
                ("inner", .string("nested value"))
            )))
        ))
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(NestedStructure.self, from: json)
        
        XCTAssertEqual(result.outer.inner, "nested value")
    }
    
    struct NestedArrayStructure: Decodable {
        let items: [Nested]
        
        struct Nested: Decodable {
            let value: String
        }
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var items: [Nested] = []
            
            while !container.isAtEnd {
                let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.self)
                let value = try nestedContainer.decode(String.self, forKey: .value)
                items.append(Nested(value: value))
            }
            
            self.items = items
        }
        
        enum CodingKeys: String, CodingKey {
            case value
        }
    }
    
    func testNestedContainerInUnkeyedContainer() throws {
        let json = JSONValue.array([
            .object(JSONObject(dictionaryLiteral: ("value", .string("first")))),
            .object(JSONObject(dictionaryLiteral: ("value", .string("second"))))
        ])
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(NestedArrayStructure.self, from: json)
        
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].value, "first")
        XCTAssertEqual(result.items[1].value, "second")
    }
    
    // MARK: - SuperDecoder
    
    func testSuperDecoder() throws {
        class TestClass: Decodable {
            let name: String
            let superValue: String
            
            required init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.name = try container.decode(String.self, forKey: .name)
                
                // Access superDecoder which looks for "super" key
                let superDecoder = try container.superDecoder()
                let superContainer = try superDecoder.container(keyedBy: SuperKeys.self)
                self.superValue = try superContainer.decode(String.self, forKey: .value)
            }
            
            enum CodingKeys: String, CodingKey {
                case name
                case `super`
            }
            
            enum SuperKeys: String, CodingKey {
                case value
            }
        }
        
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("name", .string("test")),
            ("super", .object(JSONObject(dictionaryLiteral: ("value", .string("super value")))))
        ))
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestClass.self, from: json)
        
        XCTAssertEqual(result.name, "test")
        XCTAssertEqual(result.superValue, "super value")
    }
    
    // MARK: - nestedDecoder Coverage
    
    struct DeepNesting: Decodable {
        let level1: Level1
        
        struct Level1: Decodable {
            let level2: Level2
            
            struct Level2: Decodable {
                let value: String
            }
        }
    }
    
    func testNestedDecoder() throws {
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("level1", .object(JSONObject(dictionaryLiteral:
                ("level2", .object(JSONObject(dictionaryLiteral:
                    ("value", .string("deeply nested"))
                )))
            )))
        ))
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(DeepNesting.self, from: json)
        
        XCTAssertEqual(result.level1.level2.value, "deeply nested")
    }
    
    // MARK: - UnkeyedContainer.isAtEnd Edge Cases
    
    struct EmptyArray: Decodable {
        let items: [String]
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var items: [String] = []
            
            while !container.isAtEnd {
                items.append(try container.decode(String.self))
            }
            
            self.items = items
        }
    }
    
    func testUnkeyedContainerEmptyArray() throws {
        let json = JSONValue.array([])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(EmptyArray.self, from: json)
        
        XCTAssertEqual(result.items, [])
    }
    
    // MARK: - Error Path: Invalid Conversions
    
    func testInvalidUInt16Conversion() {
        struct Container: Decodable {
            let value: UInt16
        }
        
        let json = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(999999))))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(Container.self, from: json))
    }
    
    func testInvalidUInt8InArrayConversion() {
        struct Container: Decodable {
            let values: [UInt8]
        }
        
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("values", .array([.number(255), .number(256)]))
        ))
        let decoder = JSONValueDecoder()
        
        XCTAssertThrowsError(try decoder.decode(Container.self, from: json))
    }
    
    // MARK: - Contains Key
    
    struct OptionalFields: Decodable {
        let required: String
        let optional: String?
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.required = try container.decode(String.self, forKey: .required)
            
            if container.contains(.optional) {
                self.optional = try container.decode(String.self, forKey: .optional)
            } else {
                self.optional = nil
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case required
            case optional
        }
    }
    
    func testContainsKey() throws {
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("required", .string("present"))
        ))
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(OptionalFields.self, from: json)
        
        XCTAssertEqual(result.required, "present")
        XCTAssertNil(result.optional)
    }
    
    func testContainsKeyWhenPresent() throws {
        let json = JSONValue.object(JSONObject(dictionaryLiteral:
            ("required", .string("present")),
            ("optional", .string("also present"))
        ))
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(OptionalFields.self, from: json)
        
        XCTAssertEqual(result.required, "present")
        XCTAssertEqual(result.optional, "also present")
    }
}
