import XCTest
@testable import TOONCodable

final class TOONCodableTests: XCTestCase {
    func testDecodesNestedObject() throws {
        struct User: Codable, Equatable {
            let name: String
            let role: String
        }
        struct Envelope: Codable, Equatable {
            let user: User
        }

        let toon = """
        user:
          name: Ada
          role: admin
        """
        let decoder = ToonDecoder()
        let value = try decoder.decode(Envelope.self, from: Data(toon.utf8))
        XCTAssertEqual(value, Envelope(user: User(name: "Ada", role: "admin")))
    }

    func testDecodesTabularArray() throws {
        struct Item: Codable, Equatable {
            let sku: String
            let qty: Int
            let price: Double
        }
        struct Inventory: Codable, Equatable {
            let items: [Item]
        }

        let toon = """
        items[2]{sku,qty,price}:
          A1,2,9.99
          B2,1,14.5
        """
        let decoder = ToonDecoder()
        let inventory = try decoder.decode(Inventory.self, from: Data(toon.utf8))
        XCTAssertEqual(inventory.items.count, 2)
        XCTAssertEqual(inventory.items[0], Item(sku: "A1", qty: 2, price: 9.99))
    }

    func testDecodesRootArray() throws {
        struct Item: Codable, Equatable {
            let id: Int
            let name: String
        }
        let toon = """
        [2]{id,name}:
          1,Ada
          2,Bob
        """
        let decoder = ToonDecoder()
        let value = try decoder.decode([Item].self, from: Data(toon.utf8))
        XCTAssertEqual(value[1], Item(id: 2, name: "Bob"))
    }

    func testDecodingInvalidUTF8Throws() {
        let decoder = ToonDecoder()
        XCTAssertThrowsError(try decoder.decode([String].self, from: Data([0xFF])))
    }

    func testDecodesFromInputStream() throws {
        struct Wrapper: Codable, Equatable {
            let value: String
        }
        let toon = "value: streamed\n"
        let stream = InputStream(data: Data(toon.utf8))
        let decoder = ToonDecoder()
        let result = try decoder.decode(Wrapper.self, from: stream)
        XCTAssertEqual(result.value, "streamed")
    }

    func testDecodesLargeDatasetFromFileStream() throws {
        struct User: Codable, Equatable {
            let id: Int
            let name: String
            let active: Bool
        }
        struct Dataset: Codable, Equatable {
            let users: [User]
        }
        let url = datasetURL(named: "large.toon")
        guard let stream = InputStream(url: url) else {
            return XCTFail("Failed to open dataset stream")
        }
        let decoder = ToonDecoder()
        let result = try decoder.decode(Dataset.self, from: stream)
        XCTAssertEqual(result.users.count, 200)
        XCTAssertEqual(result.users.first?.name, "User-0001")
    }

    func testEncoderRoundTripsSimpleStruct() throws {
        struct Payload: Codable, Equatable {
            let name: String
            let tags: [String]
        }
        let value = Payload(name: "Ada", tags: ["alpha", "beta"])
        let encoder = ToonEncoder()
        let toon = try encoder.encode(value)
        let decoder = ToonDecoder()
        let decoded = try decoder.decode(Payload.self, from: toon)
        XCTAssertEqual(decoded, value)
    }

    func testDecoderSchemaMismatchThrows() throws {
        struct Payload: Codable {
            let count: Int
        }
        let toon = "count: 5"
        var decoder = ToonDecoder()
        decoder.options.schema = .object(
            fields: [
                ToonSchema.field("count", .string),
            ],
            allowAdditionalKeys: false
        )
        XCTAssertThrowsError(try decoder.decode(Payload.self, from: Data(toon.utf8))) { error in
            guard case ToonDecodingError.schemaMismatch = error else {
                return XCTFail("Expected schema mismatch error, got \(error)")
            }
        }
    }

    func testDecoderSchemaAllowsValidData() throws {
        struct Payload: Codable, Equatable {
            let flag: Bool
            let nested: Nested

            struct Nested: Codable, Equatable {
                let name: String
            }
        }
        let toon = """
        flag: true
        nested:
          name: Ada
        """
        var decoder = ToonDecoder()
        decoder.options.schema = .object(
            fields: [
                ToonSchema.field("flag", .bool),
                ToonSchema.field("nested", .object(
                    fields: [ToonSchema.field("name", .string)],
                    allowAdditionalKeys: false
                )),
            ],
            allowAdditionalKeys: false
        )
        let value = try decoder.decode(Payload.self, from: Data(toon.utf8))
        XCTAssertEqual(value.flag, true)
        XCTAssertEqual(value.nested.name, "Ada")
    }

    func testEncoderSchemaControlsTabularHeaders() throws {
        struct Row: Codable {
            let second: Int
            let first: Int
        }
        let rows = [Row(second: 1, first: 2)]
        var encoder = ToonEncoder()
        encoder.schema = .array(
            element: .object(
                fields: [
                    ToonSchema.field("first", .number),
                    ToonSchema.field("second", .number),
                ],
                allowAdditionalKeys: false
            ),
            representation: .tabular(headers: ["first", "second"])
        )
        let data = try encoder.encode(rows)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(text, "[1]{first,second}:\n  2,1")
    }

    func testEncoderSchemaMismatchThrows() throws {
        struct Row: Codable {
            let value: String
        }
        let rows = [Row(value: "text")]
        var encoder = ToonEncoder()
        encoder.schema = .array(
            element: .object(
                fields: [
                    ToonSchema.field("value", .number),
                ],
                allowAdditionalKeys: false
            ),
            representation: .tabular(headers: ["value"])
        )
        XCTAssertThrowsError(try encoder.encode(rows)) { error in
            guard case ToonEncodingError.schemaMismatch = error else {
                return XCTFail("Expected schema mismatch, got \(error)")
            }
        }
    }
}

private func datasetURL(named name: String) -> URL {
    var url = URL(fileURLWithPath: #filePath)
    url.deleteLastPathComponent() // TOONCodableTests.swift
    url.deleteLastPathComponent() // TOONCodableTests
    url.deleteLastPathComponent() // Tests
    return url.appendingPathComponent("Benchmarks").appendingPathComponent("Datasets").appendingPathComponent(name)
}
