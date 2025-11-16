import XCTest
@testable import TOONCodable
@testable import TOONCore

final class JSONValueDecoderAdditionalTests: XCTestCase {
    func testNumericConversionFailureThrows() {
        let decoder = JSONValueDecoder()
        XCTAssertThrowsError(try decoder.decode(Int.self, from: .number(1.5))) { error in
            guard case let DecodingError.dataCorrupted(context) = error else {
                return XCTFail("Expected dataCorrupted, got \(error)")
            }
            XCTAssertTrue(context.debugDescription.contains("Value not representable"))
        }
    }

    func testNestedKeyedDecodingContainer() throws {
        let value: JSONValue = .object([
            "root": .object([
                "child": .object([
                    "name": .string("Ada")
                ])
            ])
        ])
        let decoder = JSONValueDecoder()
        struct Model: Decodable {
            let root: Child
            struct Child: Decodable {
                let child: Inner
            }
            struct Inner: Decodable {
                let name: String
            }
        }
        let model = try decoder.decode(Model.self, from: value)
        XCTAssertEqual(model.root.child.name, "Ada")
    }

    func testSingleValueDecoderNilHandling() throws {
        let decoder = JSONValueDecoder()
        let value = JSONValue.null
        struct Nullable: Decodable {
            let optional: String?
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                optional = try? container.decode(String.self)
            }
        }
        let decoded = try decoder.decode(Nullable.self, from: value)
        XCTAssertNil(decoded.optional)
    }
}
