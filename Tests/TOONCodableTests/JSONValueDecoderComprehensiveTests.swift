import XCTest
@testable import TOONCodable
@testable import TOONCore

/// Comprehensive tests to push JSONValueDecoder to 95%+ coverage
final class JSONValueDecoderComprehensiveTests: XCTestCase {
    
    // MARK: - Integer Type Conversions (lines 204-214)
    
    func testDecodeInt8() throws {
        struct TestInt8: Codable {
            let value: Int8
        }
        
        let json = JSONValue.object(["value": .number(42)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestInt8.self, from: json)
        XCTAssertEqual(result.value, 42)
    }
    
    func testDecodeInt16() throws {
        struct TestInt16: Codable {
            let value: Int16
        }
        
        let json = JSONValue.object(["value": .number(1000)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestInt16.self, from: json)
        XCTAssertEqual(result.value, 1000)
    }
    
    func testDecodeInt32() throws {
        struct TestInt32: Codable {
            let value: Int32
        }
        
        let json = JSONValue.object(["value": .number(100000)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestInt32.self, from: json)
        XCTAssertEqual(result.value, 100000)
    }
    
    func testDecodeInt64() throws {
        struct TestInt64: Codable {
            let value: Int64
        }
        
        let json = JSONValue.object(["value": .number(9999999999)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestInt64.self, from: json)
        XCTAssertEqual(result.value, 9999999999)
    }
    
    func testDecodeUInt() throws {
        struct TestUInt: Codable {
            let value: UInt
        }
        
        let json = JSONValue.object(["value": .number(42)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestUInt.self, from: json)
        XCTAssertEqual(result.value, 42)
    }
    
    func testDecodeUInt8() throws {
        struct TestUInt8: Codable {
            let value: UInt8
        }
        
        let json = JSONValue.object(["value": .number(255)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestUInt8.self, from: json)
        XCTAssertEqual(result.value, 255)
    }
    
    func testDecodeUInt16() throws {
        struct TestUInt16: Codable {
            let value: UInt16
        }
        
        let json = JSONValue.object(["value": .number(65000)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestUInt16.self, from: json)
        XCTAssertEqual(result.value, 65000)
    }
    
    func testDecodeUInt32() throws {
        struct TestUInt32: Codable {
            let value: UInt32
        }
        
        let json = JSONValue.object(["value": .number(4000000000)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestUInt32.self, from: json)
        XCTAssertEqual(result.value, 4000000000)
    }
    
    func testDecodeUInt64() throws {
        struct TestUInt64: Codable {
            let value: UInt64
        }
        
        let json = JSONValue.object(["value": .number(18000000000000000000)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestUInt64.self, from: json)
        XCTAssertEqual(result.value, 18000000000000000000)
    }
    
    func testDecodeFloat() throws {
        struct TestFloat: Codable {
            let value: Float
        }
        
        let json = JSONValue.object(["value": .number(3.14)])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestFloat.self, from: json)
        XCTAssertEqual(result.value, 3.14, accuracy: 0.01)
    }
    
    // MARK: - decodeNil in SingleValueContainer (lines 197-199)
    
    func testSingleValueDecodeNil() throws {
        struct TestOptional: Codable {
            let value: String?
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if container.decodeNil() {
                    value = nil
                } else {
                    value = try container.decode(String.self)
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            }
        }
        
        let json = JSONValue.null
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestOptional.self, from: json)
        XCTAssertNil(result.value)
    }
    
    func testSingleValueDecodeNilReturnsFalse() throws {
        struct TestNonNil: Codable {
            let isNull: Bool
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                isNull = container.decodeNil()
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(isNull)
            }
        }
        
        let json = JSONValue.string("value")
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestNonNil.self, from: json)
        XCTAssertFalse(result.isNull)
    }
    
    // MARK: - nestedUnkeyedContainer (lines 166-169)
    
    func testNestedUnkeyedContainer() throws {
        struct TestNested: Codable {
            let values: [[Int]]
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var result: [[Int]] = []
                
                while !container.isAtEnd {
                    var nested = try container.nestedUnkeyedContainer()
                    var innerArray: [Int] = []
                    while !nested.isAtEnd {
                        innerArray.append(try nested.decode(Int.self))
                    }
                    result.append(innerArray)
                }
                self.values = result
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                for array in values {
                    var nested = container.nestedUnkeyedContainer()
                    for value in array {
                        try nested.encode(value)
                    }
                }
            }
        }
        
        let json = JSONValue.array([
            .array([.number(1), .number(2)]),
            .array([.number(3), .number(4)])
        ])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestNested.self, from: json)
        XCTAssertEqual(result.values.count, 2)
        XCTAssertEqual(result.values[0], [1, 2])
        XCTAssertEqual(result.values[1], [3, 4])
    }
    
    // MARK: - superDecoder in UnkeyedContainer (lines 171-173)
    
    func testUnkeyedSuperDecoder() throws {
        struct TestSuper: Codable {
            let value: String
            
            init(from decoder: Decoder) throws {
                var container = try decoder.unkeyedContainer()
                let superDecoder = try container.superDecoder()
                let nested = try superDecoder.singleValueContainer()
                value = try nested.decode(String.self)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(value)
            }
        }
        
        let json = JSONValue.array([.string("test")])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestSuper.self, from: json)
        XCTAssertEqual(result.value, "test")
    }
    
    // MARK: - Generic decode in SingleValueContainer (lines 216-219)
    
    func testSingleValueGenericDecode() throws {
        struct Inner: Codable {
            let name: String
        }
        
        struct TestGeneric: Codable {
            let nested: Inner
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                nested = try container.decode(Inner.self)
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(nested)
            }
        }
        
        let json = JSONValue.object(["name": .string("Alice")])
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestGeneric.self, from: json)
        XCTAssertEqual(result.nested.name, "Alice")
    }
    
    // MARK: - Complex nested structures
    
    func testComplexNestedStructure() throws {
        struct Person: Codable {
            let name: String
            let age: Int
            let emails: [String]
        }
        
        let json = JSONValue.object([
            "name": .string("Bob"),
            "age": .number(30),
            "emails": .array([.string("bob@test.com"), .string("bob2@test.com")])
        ])
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(Person.self, from: json)
        
        XCTAssertEqual(result.name, "Bob")
        XCTAssertEqual(result.age, 30)
        XCTAssertEqual(result.emails.count, 2)
    }
    
    func testArrayOfOptionals() throws {
        struct TestOptArray: Codable {
            let values: [Int?]
        }
        
        let json = JSONValue.object([
            "values": .array([.number(1), .null, .number(3)])
        ])
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(TestOptArray.self, from: json)
        
        XCTAssertEqual(result.values.count, 3)
        XCTAssertEqual(result.values[0], 1)
        XCTAssertNil(result.values[1])
        XCTAssertEqual(result.values[2], 3)
    }
    
    func testDeeplyNestedObjects() throws {
        struct Level3: Codable {
            let value: String
        }
        
        struct Level2: Codable {
            let level3: Level3
        }
        
        struct Level1: Codable {
            let level2: Level2
        }
        
        let json = JSONValue.object([
            "level2": .object([
                "level3": .object([
                    "value": .string("deep")
                ])
            ])
        ])
        
        let decoder = JSONValueDecoder()
        let result = try decoder.decode(Level1.self, from: json)
        XCTAssertEqual(result.level2.level3.value, "deep")
    }
}
