import XCTest
@testable import TOONCodable

final class ToonDecoderSchemaTests: XCTestCase {
    func testDecoderRoundTripsNestedArrays() throws {
        struct Catalog: Codable, Equatable {
            let items: [Item]
        }
        struct Item: Codable, Equatable {
            let sku: String
            let tags: [String]
        }
        let catalog = Catalog(items: [
            Item(sku: "A1", tags: ["alpha", "beta"]),
            Item(sku: "B2", tags: ["gamma"]),
        ])
        let encoder = ToonEncoder()
        let raw = try encoder.encode(catalog)

        let decoder = ToonDecoder()
        let decoded = try decoder.decode(Catalog.self, from: raw)
        XCTAssertEqual(decoded, catalog)
    }

    func testDecoderWithSchemaRejectsMissingFieldInNestedArray() throws {
        let toonText = """
        items[1]:
          - sku: A1
            tags[2]: alpha,beta
          - sku: B2
        """
        let schema = ToonSchema.object(fields: [
            ToonSchema.field(
                "items",
                .array(
                    element: .object(fields: [
                        ToonSchema.field("sku", .string),
                        ToonSchema.field("tags", .array(element: .string))
                    ], allowAdditionalKeys: false),
                    representation: .list
                )
            ),
        ], allowAdditionalKeys: false)
        struct ItemSpec: Codable {
            let sku: String
            let tags: [String]
        }
        struct CatalogSpec: Codable {
            let items: [ItemSpec]
        }
        let decoder = ToonDecoder(options: .init(schema: schema))

        XCTAssertThrowsError(try decoder.decode(CatalogSpec.self, from: Data(toonText.utf8))) { error in
            guard case ToonDecodingError.schemaMismatch(let message) = error else {
                return XCTFail("Expected schema mismatch, got \(error)")
            }
            XCTAssertTrue(message.contains("tags"), "Expected violation to mention missing tags")
        }
    }
}
