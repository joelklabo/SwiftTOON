import XCTest
@testable import TOONCodable
@testable import TOONCore

final class JSONValueCoderTests: XCTestCase {
    func testJSONValueEncoderEncodesSimpleStruct() throws {
        struct Payload: Codable, Equatable {
            let id: Int
            let name: String
        }
        let encoder = JSONValueEncoder()
        let json = try encoder.encode(Payload(id: 42, name: "Ada"))
        let expected = JSONValue.object(JSONObject(dictionaryLiteral: ("id", .number(42)), ("name", .string("Ada"))))
        XCTAssertEqual(json, expected)
    }

    func testJSONValueDecoderDecodesNestedStructure() throws {
        struct Profile: Codable, Equatable {
            struct User: Codable, Equatable {
                let name: String
                let tags: [String]
            }

            let user: User
        }

        let json = JSONValue.object(JSONObject(dictionaryLiteral: (
            "user",
            .object(JSONObject(dictionaryLiteral: (
                "name", .string("Ada")), (
                "tags", .array([.string("a"), .string("b")])
            )))
        )))

        let decoder = JSONValueDecoder()
        let decoded = try decoder.decode(Profile.self, from: json)
        XCTAssertEqual(decoded.user.name, "Ada")
        XCTAssertEqual(decoded.user.tags, ["a", "b"])
    }

    func testEncoderDecoderRoundTrip() throws {
        struct Record: Codable, Equatable {
            let flag: Bool
            let values: [Int]
        }
        let original = Record(flag: true, values: [1, 2, 3])

        let json = try JSONValueEncoder().encode(original)
        let decoded = try JSONValueDecoder().decode(Record.self, from: json)
        XCTAssertEqual(decoded, original)
    }

    func testJSONValueDecoderDecodesFullScalarMatrix() throws {
        let json = JSONValue.object(
            JSONObject(dictionaryLiteral:
                ("bool", .bool(true)),
                ("string", .string("Ada")),
                ("double", .number(123.5)),
                ("float", .number(9.25)),
                ("int", .number(42)),
                ("int8", .number(8)),
                ("int16", .number(16)),
                ("int32", .number(32)),
                ("int64", .number(64)),
                ("uint", .number(7)),
                ("uint8", .number(80)),
                ("uint16", .number(160)),
                ("uint32", .number(320)),
                ("uint64", .number(640)),
                ("optional", .null)
            )
        )

        let decoded = try JSONValueDecoder().decode(NumericScalars.self, from: json)
        let expected = NumericScalars(
            bool: true,
            string: "Ada",
            double: 123.5,
            float: 9.25,
            int: 42,
            int8: 8,
            int16: 16,
            int32: 32,
            int64: 64,
            uint: 7,
            uint8: 80,
            uint16: 160,
            uint32: 320,
            uint64: 640,
            optional: nil,
            missing: nil
        )
        XCTAssertEqual(decoded, expected)
    }

    func testJSONValueDecoderHandlesNestedContainersAndSuperDecoder() throws {
        let json = JSONValue.object(
            JSONObject(dictionaryLiteral:
                ("object", .object(JSONObject(dictionaryLiteral: ("value", .number(3)), ("label", .string("node"))))),
                ("list", .array([.string("alpha"), .string("beta")])),
                ("nestedSuper", .object(JSONObject(dictionaryLiteral: ("value", .number(9))))),
                ("super", .string("root"))
            )
        )

        let decoded = try JSONValueDecoder().decode(NestedDecoderProbe.self, from: json)
        XCTAssertEqual(decoded.nestedValue, 3)
        XCTAssertEqual(decoded.label, "node")
        XCTAssertEqual(decoded.items, ["alpha", "beta"])
        XCTAssertEqual(decoded.rootFromSuper, "root")
        XCTAssertEqual(decoded.overrideFromSuper, 9)
    }

    func testJSONValueDecoderUnkeyedContainerNilAndOverflow() throws {
        let source = JSONValue.array([
            .null,
            .bool(true),
            .string("leaf"),
            .number(1.5),
            .number(2.5),
            .number(-9),
            .number(1),
            .number(2),
            .number(3),
            .number(4),
            .number(5),
            .number(6)
        ])
        let decoded = try JSONValueDecoder().decode(NumericUnkeyedSample.self, from: source)
        XCTAssertTrue(decoded.sawNil)
        XCTAssertTrue(decoded.boolean)
        XCTAssertEqual(decoded.string, "leaf")
        XCTAssertEqual(decoded.double, 1.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.float, 2.5, accuracy: 0.0001)
        XCTAssertEqual(decoded.int, -9)
        XCTAssertEqual(decoded.int8, 1)
        XCTAssertEqual(decoded.int16, 2)
        XCTAssertEqual(decoded.int32, 3)
        XCTAssertEqual(decoded.int64, 4)
        XCTAssertEqual(decoded.uint, 5)
        XCTAssertEqual(decoded.uint8, 6)

        let overflow = JSONValue.array([.number(1)])
        XCTAssertThrowsError(try JSONValueDecoder().decode(OverflowProbe.self, from: overflow)) { error in
            guard case DecodingError.valueNotFound = error else {
                XCTFail("Expected valueNotFound, got \(error)")
                return
            }
        }
    }

    func testJSONValueDecoderTypeMismatchThrows() {
        XCTAssertThrowsError(
            try JSONValueDecoder().decode(NumericScalars.self, from: .array([])),
            "Decoding keyed container from array should fail"
        ) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testJSONValueDecoderDecodesTopLevelScalars() throws {
        XCTAssertTrue(try JSONValueDecoder().decode(Bool.self, from: .bool(true)))
        XCTAssertEqual(try JSONValueDecoder().decode(String.self, from: .string("Ada")), "Ada")
        XCTAssertEqual(try JSONValueDecoder().decode(Int.self, from: .number(5)), 5)

        let wrapped = JSONValue.object(JSONObject(dictionaryLiteral: ("value", .number(7))))
        let decoded = try JSONValueDecoder().decode(SingleValueDecodableWrapper.self, from: wrapped)
        XCTAssertEqual(decoded.value, 7)
    }

    func testJSONValueEncoderEncodesTopLevelScalars() throws {
        XCTAssertEqual(try JSONValueEncoder().encode(true), .bool(true))
        XCTAssertEqual(try JSONValueEncoder().encode("Ada"), .string("Ada"))
        XCTAssertEqual(try JSONValueEncoder().encode(3), .number(3))
    }

    func testJSONValueEncoderCoversNestedContainersAndSuperEncoder() throws {
        let encoded = try JSONValueEncoder().encode(EncoderExplorer())
        let expected = JSONValue.object(
            JSONObject(dictionaryLiteral:
                ("name", .string("Ada")),
                ("list", .array([
                    .null,
                    .number(1),
                    .bool(true),
                    .object(JSONObject(dictionaryLiteral: ("label", .string("leaf")))),
                    .array([.string("inner")]),
                    .string("list-super")
                ])),
                ("nested", .object(JSONObject(dictionaryLiteral: ("flag", .bool(false))))),
                ("otherList", .array([.number(2)])),
                ("override", .object(JSONObject(dictionaryLiteral: ("value", .number(9))))),
                ("super", .string("root-super"))
            )
        )
        XCTAssertEqual(encoded, expected)
    }

    func testJSONValueEncoderCoversUnkeyedNumericWrites() throws {
        let encoded = try JSONValueEncoder().encode(NumericArrayEmitter())
        let expected = JSONValue.array([
            .null,
            .bool(true),
            .string("text"),
            .number(1.5),
            .number(2.5),
            .number(-9),
            .number(-2),
            .number(-3),
            .number(-4),
            .number(-5),
            .number(6),
            .number(7),
            .number(8),
            .number(9),
            .number(10)
        ])
        XCTAssertEqual(encoded, expected)
    }

    func testJSONValueEncoderSingleValueEncodesCustomType() throws {
        let payload = SingleValueEncodableWrapper(payload: NumericEntry(value: 7))
        let encoded = try JSONValueEncoder().encode(payload)
        XCTAssertEqual(encoded, .object(JSONObject(dictionaryLiteral: ("value", .number(7)))))
    }

    func testJSONValueEncoderThrowsWhenNoValueProduced() {
        XCTAssertThrowsError(try JSONValueEncoder().encode(EmptyEncodable())) { error in
            guard case EncodingError.invalidValue = error else {
                XCTFail("Expected invalidValue error, got \(error)")
                return
            }
        }
    }

    func testAnyCodingKeyInitializers() {
        let stringKey = AnyCodingKey(stringValue: "field")
        XCTAssertEqual(stringKey?.stringValue, "field")
        XCTAssertNil(stringKey?.intValue)

        let intKey = AnyCodingKey(intValue: 5)
        XCTAssertEqual(intKey?.stringValue, "5")
        XCTAssertEqual(intKey?.intValue, 5)

        let indexed = AnyCodingKey(index: 3)
        XCTAssertEqual(indexed.stringValue, "Index3")
        XCTAssertEqual(indexed.intValue, 3)
    }
}

private struct NumericScalars: Codable, Equatable {
    let bool: Bool
    let string: String
    let double: Double
    let float: Float
    let int: Int
    let int8: Int8
    let int16: Int16
    let int32: Int32
    let int64: Int64
    let uint: UInt
    let uint8: UInt8
    let uint16: UInt16
    let uint32: UInt32
    let uint64: UInt64
    let optional: String?
    let missing: Int?
}

private struct NestedDecoderProbe: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case object
        case list
        case nestedSuper
        case root = "super"
    }

    enum NestedKeys: String, CodingKey {
        case value
        case label
    }

    enum OverrideKeys: String, CodingKey {
        case value
    }

    let nestedValue: Int
    let label: String
    let items: [String]
    let rootFromSuper: String
    let overrideFromSuper: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nested = try container.nestedContainer(keyedBy: NestedKeys.self, forKey: .object)
        self.nestedValue = try nested.decode(Int.self, forKey: .value)
        self.label = try nested.decode(String.self, forKey: .label)

        var list = try container.nestedUnkeyedContainer(forKey: .list)
        var collected: [String] = []
        while !list.isAtEnd {
            collected.append(try list.decode(String.self))
        }
        self.items = collected

        let rootDecoder = try container.superDecoder()
        self.rootFromSuper = try rootDecoder.singleValueContainer().decode(String.self)

        let overrideDecoder = try container.superDecoder(forKey: .nestedSuper)
        let overrideContainer = try overrideDecoder.container(keyedBy: OverrideKeys.self)
        self.overrideFromSuper = try overrideContainer.decode(Int.self, forKey: .value)
    }
}

private struct NumericUnkeyedSample: Decodable, Equatable {
    let sawNil: Bool
    let boolean: Bool
    let string: String
    let double: Double
    let float: Float
    let int: Int
    let int8: Int8
    let int16: Int16
    let int32: Int32
    let int64: Int64
    let uint: UInt
    let uint8: UInt8

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.sawNil = try container.decodeNil()
        self.boolean = try container.decode(Bool.self)
        self.string = try container.decode(String.self)
        self.double = try container.decode(Double.self)
        self.float = try container.decode(Float.self)
        self.int = try container.decode(Int.self)
        self.int8 = try container.decode(Int8.self)
        self.int16 = try container.decode(Int16.self)
        self.int32 = try container.decode(Int32.self)
        self.int64 = try container.decode(Int64.self)
        self.uint = try container.decode(UInt.self)
        self.uint8 = try container.decode(UInt8.self)
    }
}

private struct OverflowProbe: Decodable {
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try container.decode(Int.self)
        _ = try container.decode(Int.self)
    }
}

private struct EncoderExplorer: Encodable {
    enum CodingKeys: String, CodingKey {
        case name
        case list
        case nested
        case otherList
        case override
    }

    enum NestedKeys: String, CodingKey {
        case flag
        case label
    }

    enum OverrideKeys: String, CodingKey {
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("Ada", forKey: .name)

        var list = container.nestedUnkeyedContainer(forKey: .list)
        try list.encodeNil()
        try list.encode(1)
        try list.encode(true)
        var nestedLabel = list.nestedContainer(keyedBy: NestedKeys.self)
        try nestedLabel.encode("leaf", forKey: .label)
        var nestedArray = list.nestedUnkeyedContainer()
        try nestedArray.encode("inner")
        let listSuper = list.superEncoder()
        var listSuperContainer = listSuper.singleValueContainer()
        try listSuperContainer.encode("list-super")

        var nested = container.nestedContainer(keyedBy: NestedKeys.self, forKey: .nested)
        try nested.encode(false, forKey: .flag)

        var otherList = container.nestedUnkeyedContainer(forKey: .otherList)
        try otherList.encode(2)

        let overrideEncoder = container.superEncoder(forKey: .override)
        var overrideContainer = overrideEncoder.container(keyedBy: OverrideKeys.self)
        try overrideContainer.encode(9, forKey: .value)

        let rootSuper = container.superEncoder()
        var rootSingle = rootSuper.singleValueContainer()
        try rootSingle.encode("root-super")
    }
}

private struct NumericArrayEmitter: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encodeNil()
        try container.encode(true)
        try container.encode("text")
        try container.encode(Double(1.5))
        try container.encode(Float(2.5))
        try container.encode(Int(-9))
        try container.encode(Int8(-2))
        try container.encode(Int16(-3))
        try container.encode(Int32(-4))
        try container.encode(Int64(-5))
        try container.encode(UInt(6))
        try container.encode(UInt8(7))
        try container.encode(UInt16(8))
        try container.encode(UInt32(9))
        try container.encode(UInt64(10))
    }
}

private struct SingleValueEncodableWrapper: Encodable {
    let payload: NumericEntry

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(payload)
    }
}

private struct NumericEntry: Codable, Equatable {
    let value: Int
}

private struct SingleValueDecodableWrapper: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(Int.self)
    }
}

private struct EmptyEncodable: Encodable {
    func encode(to encoder: Encoder) throws {}
}
