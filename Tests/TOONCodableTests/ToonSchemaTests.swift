import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonSchemaTests: XCTestCase {
    func testValidatePassesForNestedObject() throws {
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("id", .number),
            ToonSchema.field("name", .string),
            ToonSchema.field("flags", .array(element: .bool)),
        ])
        let value: JSONValue = .object([
            "id": .number(1),
            "name": .string("Ada"),
            "flags": .array([.bool(true), .bool(false)]),
        ])
        XCTAssertNoThrow(try schema.validate(value))
    }

    func testValidateThrowsMissingField() {
        let schema = ToonSchema.object(fields: [ToonSchema.field("id", .number)], allowAdditionalKeys: false)
        let value: JSONValue = .object([:])
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.missingField(let path) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, "$id")
        }
    }

    func testValidateThrowsUnexpectedFieldWhenAdditionalNotAllowed() {
        let schema = ToonSchema.object(fields: [ToonSchema.field("id", .number)], allowAdditionalKeys: false)
        let value: JSONValue = .object([
            "id": .number(1),
            "extra": .string("nope"),
        ])
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.unexpectedField(let path) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, "$extra")
        }
    }

    func testValidateArrayReportsElementPath() {
        let schema = ToonSchema.array(element: .string)
        let value: JSONValue = .array([
            .string("ok"),
            .number(42),
        ])
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(_, _, let path) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path, "$[1]")
        }
    }

    func testSchemaHelpersExposeMetadata() {
        let schema = ToonSchema.object(fields: [
            ToonSchema.field("child", .array(element: .number, representation: .tabular(headers: ["value"]))),
        ], allowAdditionalKeys: false)
        if case .object(_, let allow) = schema {
            XCTAssertFalse(allow)
        }
        XCTAssertEqual(schema.schema(forField: "child"), .array(element: .number, representation: .tabular(headers: ["value"])))
        XCTAssertNil(schema.schema(forField: "missing"))

        let arraySchema = ToonSchema.array(element: .bool, representation: .list)
        XCTAssertEqual(arraySchema.arrayElementSchema, .bool)
        XCTAssertEqual(arraySchema.arrayRepresentationHint, .list)
        XCTAssertTrue(ToonSchema.string.allowsAdditionalKeys)
    }
}
