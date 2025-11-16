import XCTest
@testable import TOONCodable
import TOONCore

final class ToonSchemaIntegrationTests: XCTestCase {
    struct Person: Codable, Equatable {
        let name: String
        let title: String
    }

    struct SlimPerson: Codable {
        let name: String
    }

    private var strictSchema: ToonSchema {
        .object(
            fields: [
                ToonSchema.field("name", .string),
                ToonSchema.field("title", .string),
            ],
            allowAdditionalKeys: false
        )
    }

    func testEncoderFailsWhenExtraFieldIsPresent() throws {
        let encoder = ToonEncoder(schema: strictSchema)
        let person = Person(name: "Ada", title: "admin")
        struct Extra: Codable { let name: String; let title: String; let extra: String }
        let model = Extra(name: person.name, title: person.title, extra: "bad-field")

        XCTAssertThrowsError(try encoder.encode(model)) { error in
            guard case let ToonEncodingError.schemaMismatch(message) = error else {
                return XCTFail("Expected schema mismatch, got \(error)")
            }
            XCTAssertTrue(message.contains("Unexpected field"), "Unexpected message: \(message)")
        }
    }

    func testDecoderFailsWhenSchemaDisallowsField() throws {
        let toonText = """
        name: Ada
        title: admin
        bonus: true
        """
        let decoder = ToonDecoder(options: .init(schema: strictSchema))
        XCTAssertThrowsError(try decoder.decode(SlimPerson.self, from: Data(toonText.utf8))) { error in
            guard case let ToonDecodingError.schemaMismatch(message) = error else {
                return XCTFail("Expected schema mismatch, got \(error)")
            }
            XCTAssertTrue(message.contains("Unexpected field"), "Unexpected message: \(message)")
        }
    }

    func testDecoderAcceptsMatchingSchema() throws {
        let toonText = """
        name: Ada
        title: admin
        """
        let decoder = ToonDecoder(options: .init(schema: strictSchema))
        let decoded = try decoder.decode(SlimPerson.self, from: Data(toonText.utf8))
        XCTAssertEqual(decoded.name, "Ada")
    }
}
