import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonEncoderSchemaTests: XCTestCase {
    func testEncoderHonorsSchemaTabularHint() throws {
        struct StockItem: Codable, Equatable {
            let sku: String
            let qty: Int
        }
        struct Catalog: Codable, Equatable {
            let items: [StockItem]
        }
        let catalog = Catalog(items: [StockItem(sku: "A1", qty: 5), StockItem(sku: "B2", qty: 3)])
        let schema = ToonSchema.object(fields: [
            ToonSchema.field(
                "items",
                .array(
                    element: .object(fields: [
                        ToonSchema.field("sku", .string),
                        ToonSchema.field("qty", .number),
                    ], allowAdditionalKeys: false),
                    representation: .tabular(headers: ["sku", "qty"])
                )
            ),
        ], allowAdditionalKeys: false)

        let encoder = ToonEncoder(schema: schema)
        let output = try String(data: encoder.encode(catalog), encoding: .utf8)
        XCTAssertNotNil(output)
        XCTAssertTrue(output!.contains("items[2]{sku,qty}:"), "Schema tabular header should appear")
        XCTAssertTrue(output!.contains("  A1,5"))
        XCTAssertTrue(output!.contains("  B2,3"))
    }
}
