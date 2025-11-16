import XCTest
@testable import TOONCodable
@testable import TOONCore

final class JSONValueDecoderEdgeCaseTests: XCTestCase {
    
    // MARK: - Nested Container Combinations
    
    func testNestedUnkeyedInKeyed() throws {
        let value: JSONValue = .object([
            "items": .array([.number(1), .number(2), .number(3)])
        ])
        
        struct Container: Decodable {
            let items: [Int]
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.items, [1, 2, 3])
    }
    
    func testNestedKeyedInUnkeyed() throws {
        let value: JSONValue = .array([
            .object(["key": .string("value1")]),
            .object(["key": .string("value2")])
        ])
        
        struct Item: Decodable {
            let key: String
        }
        
        let result = try JSONValueDecoder().decode([Item].self, from: value)
        XCTAssertEqual(result[0].key, "value1")
        XCTAssertEqual(result[1].key, "value2")
    }
    
    func testDoubleNesting() throws {
        // keyed -> unkeyed -> keyed
        let value: JSONValue = .object([
            "outer": .array([
                .object(["inner": .number(42)]),
                .object(["inner": .number(99)])
            ])
        ])
        
        struct Test: Decodable {
            let outer: [Inner]
            struct Inner: Decodable {
                let inner: Int
            }
        }
        
        let result = try JSONValueDecoder().decode(Test.self, from: value)
        XCTAssertEqual(result.outer[0].inner, 42)
        XCTAssertEqual(result.outer[1].inner, 99)
    }
    
    func testTripleNesting() throws {
        // Test maximum nesting depth
        let value: JSONValue = .array([
            .array([
                .array([.number(1), .number(2)])
            ])
        ])
        
        let result = try JSONValueDecoder().decode([[[Int]]].self, from: value)
        XCTAssertEqual(result[0][0][0], 1)
        XCTAssertEqual(result[0][0][1], 2)
    }
    
    // MARK: - superDecoder Edge Cases
    
    func testSuperDecoderWithCustomKey() throws {
        let value: JSONValue = .object([
            "data": .object(["nested": .string("value")])
        ])
        
        struct Wrapper: Decodable {
            let nested: String
            
            enum CodingKeys: String, CodingKey { case data }
            enum NestedKeys: String, CodingKey { case nested }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let superDecoder = try container.superDecoder(forKey: .data)
                let nestedContainer = try superDecoder.container(keyedBy: NestedKeys.self)
                self.nested = try nestedContainer.decode(String.self, forKey: .nested)
            }
        }
        
        let result = try JSONValueDecoder().decode(Wrapper.self, from: value)
        XCTAssertEqual(result.nested, "value")
    }
    
    func testSuperDecoderInUnkeyedContainer() throws {
        let value: JSONValue = .array([
            .object(["key": .string("value")])
        ])
        
        struct Container: Decodable {
            let key: String
            
            enum Keys: String, CodingKey { case key }
            
            init(from decoder: Decoder) throws {
                var unkeyedContainer = try decoder.unkeyedContainer()
                let superDecoder = try unkeyedContainer.superDecoder()
                let keyedContainer = try superDecoder.container(keyedBy: Keys.self)
                self.key = try keyedContainer.decode(String.self, forKey: .key)
            }
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.key, "value")
    }
    
    func testSuperDecoderWithDefaultSuper() throws {
        let value: JSONValue = .object([
            "super": .object(["nested": .number(42)])
        ])
        
        struct Container: Decodable {
            let nested: Int
            
            enum SuperKeys: String, CodingKey { case `super` }
            enum NestedKeys: String, CodingKey { case nested }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: SuperKeys.self)
                let superDecoder = try container.superDecoder()
                let nestedContainer = try superDecoder.container(keyedBy: NestedKeys.self)
                self.nested = try nestedContainer.decode(Int.self, forKey: .nested)
            }
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.nested, 42)
    }
    
    // MARK: - Type Mismatch Paths
    
    func testDecodeIntFromString() {
        let value: JSONValue = .string("not a number")
        XCTAssertThrowsError(try JSONValueDecoder().decode(Int.self, from: value))
    }
    
    func testDecodeArrayFromObject() {
        let value: JSONValue = .object(["key": .string("value")])
        XCTAssertThrowsError(try JSONValueDecoder().decode([String].self, from: value))
    }
    
    func testDecodeObjectFromArray() {
        let value: JSONValue = .array([.number(1)])
        
        struct Test: Decodable {
            let key: String
        }
        
        XCTAssertThrowsError(try JSONValueDecoder().decode(Test.self, from: value))
    }
    
    func testDecodeStringFromNumber() {
        let value: JSONValue = .number(42)
        XCTAssertThrowsError(try JSONValueDecoder().decode(String.self, from: value))
    }
    
    func testDecodeBoolFromString() {
        let value: JSONValue = .string("true")
        XCTAssertThrowsError(try JSONValueDecoder().decode(Bool.self, from: value))
    }
    
    // MARK: - Empty Containers
    
    func testDecodeEmptyArray() throws {
        let value: JSONValue = .array([])
        let result = try JSONValueDecoder().decode([Int].self, from: value)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testDecodeEmptyObject() throws {
        let value: JSONValue = .object([:])
        
        struct Empty: Decodable {}
        
        let result = try JSONValueDecoder().decode(Empty.self, from: value)
        XCTAssertNotNil(result)
    }
    
    func testDecodeEmptyStringValue() throws {
        let value: JSONValue = .string("")
        let result = try JSONValueDecoder().decode(String.self, from: value)
        XCTAssertEqual(result, "")
    }
    
    // MARK: - Container Boundary Conditions
    
    func testDecodeAllKeys() throws {
        let value: JSONValue = .object([
            "a": .number(1),
            "b": .number(2),
            "c": .number(3)
        ])
        
        struct DynamicKey: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { return nil }
        }
        
        struct Container: Decodable {
            let keys: [String]
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: DynamicKey.self)
                self.keys = container.allKeys.map(\.stringValue).sorted()
            }
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.keys, ["a", "b", "c"])
    }
    
    func testUnkeyedContainerCount() throws {
        let value: JSONValue = .array([.number(1), .number(2), .number(3)])
        
        struct Container: Decodable {
            let count: Int
            let isAtEnd: Bool
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                self.count = container.count ?? 0
                _ = try container.decode(Int.self)
                _ = try container.decode(Int.self)
                _ = try container.decode(Int.self)
                self.isAtEnd = container.isAtEnd
            }
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(result.isAtEnd)
    }
    
    func testDecodeNilFromNull() throws {
        let value: JSONValue = .null
        let result = try JSONValueDecoder().decode(Optional<String>.self, from: value)
        XCTAssertNil(result)
    }
    
    func testDecodeOptionalFromValue() throws {
        let value: JSONValue = .string("hello")
        let result = try JSONValueDecoder().decode(Optional<String>.self, from: value)
        XCTAssertEqual(result, "hello")
    }
    
    // MARK: - Nested Optional Decoding
    
    func testNestedOptionalInObject() throws {
        let value: JSONValue = .object([
            "required": .string("present"),
            "optional": .null
        ])
        
        struct Container: Decodable {
            let required: String
            let optional: String?
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.required, "present")
        XCTAssertNil(result.optional)
    }
    
    func testArrayOfOptionals() throws {
        let value: JSONValue = .array([
            .string("a"),
            .null,
            .string("b")
        ])
        
        let result = try JSONValueDecoder().decode([String?].self, from: value)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], "a")
        XCTAssertNil(result[1])
        XCTAssertEqual(result[2], "b")
    }
    
    // MARK: - Current Index Tracking
    
    func testUnkeyedContainerCurrentIndex() throws {
        let value: JSONValue = .array([.number(1), .number(2), .number(3)])
        
        struct Container: Decodable {
            let indices: [Int]
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var indices: [Int] = []
                
                indices.append(container.currentIndex)
                _ = try container.decode(Int.self)
                
                indices.append(container.currentIndex)
                _ = try container.decode(Int.self)
                
                indices.append(container.currentIndex)
                _ = try container.decode(Int.self)
                
                self.indices = indices
            }
        }
        
        let result = try JSONValueDecoder().decode(Container.self, from: value)
        XCTAssertEqual(result.indices, [0, 1, 2])
    }
}
