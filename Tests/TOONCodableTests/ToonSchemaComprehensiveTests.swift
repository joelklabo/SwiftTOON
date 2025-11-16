import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonSchemaComprehensiveTests: XCTestCase {
    
    // MARK: - .any Schema Coverage
    
    func testAnySchemaAcceptsString() throws {
        let schema = ToonSchema.any
        let value: JSONValue = .string("hello")
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testAnySchemaAcceptsNumber() throws {
        let schema = ToonSchema.any
        let value: JSONValue = .number(42)
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testAnySchemaAcceptsBool() throws {
        let schema = ToonSchema.any
        let value: JSONValue = .bool(true)
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testAnySchemaAcceptsNull() throws {
        let schema = ToonSchema.any
        let value: JSONValue = .null
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testAnySchemaAcceptsObject() throws {
        let schema = ToonSchema.any
        let value: JSONValue = .object(["key": .string("value")])
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testAnySchemaAcceptsArray() throws {
        let schema = ToonSchema.any
        let value: JSONValue = .array([.number(1), .string("two")])
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    // MARK: - .null Schema Coverage
    
    func testNullSchemaAcceptsNull() throws {
        let schema = ToonSchema.null
        let value: JSONValue = .null
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testNullSchemaRejectsString() {
        let schema = ToonSchema.null
        let value: JSONValue = .string("not null")
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, let path) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "null")
            XCTAssertEqual(actual, "string")
            XCTAssertEqual(path, "$")
        }
    }
    
    func testNullSchemaRejectsNumber() {
        let schema = ToonSchema.null
        let value: JSONValue = .number(0)
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, _) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "null")
            XCTAssertEqual(actual, "number")
        }
    }
    
    // MARK: - Type Mismatch Error Paths
    
    func testObjectSchemaRejectsArray() {
        let schema = ToonSchema.object(fields: [
            .field("id", .number)
        ])
        let value: JSONValue = .array([.number(1)])
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, let path) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "object")
            XCTAssertEqual(actual, "array")
            XCTAssertEqual(path, "$")
        }
    }
    
    func testObjectSchemaRejectsString() {
        let schema = ToonSchema.object(fields: [])
        let value: JSONValue = .string("not an object")
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, _) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "object")
            XCTAssertEqual(actual, "string")
        }
    }
    
    func testArraySchemaRejectsObject() {
        let schema = ToonSchema.array(element: .string)
        let value: JSONValue = .object(["key": .string("value")])
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, let path) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "array")
            XCTAssertEqual(actual, "object")
            XCTAssertEqual(path, "$")
        }
    }
    
    func testArraySchemaRejectsNumber() {
        let schema = ToonSchema.array(element: .bool)
        let value: JSONValue = .number(123)
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, _) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "array")
            XCTAssertEqual(actual, "number")
        }
    }
    
    func testBoolSchemaRejectsBool() {
        let schema = ToonSchema.string
        let value: JSONValue = .bool(true)
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(let expected, let actual, _) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(expected, "string")
            XCTAssertEqual(actual, "bool")
        }
    }
    
    // MARK: - Nested Schema Validation
    
    func testNestedObjectSchemaValidation() throws {
        let schema = ToonSchema.object(fields: [
            .field("user", .object(fields: [
                .field("profile", .object(fields: [
                    .field("name", .string),
                    .field("age", .number)
                ]))
            ]))
        ])
        
        let value: JSONValue = .object([
            "user": .object([
                "profile": .object([
                    "name": .string("Alice"),
                    "age": .number(30)
                ])
            ])
        ])
        
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testNestedObjectSchemaReportsDeepPath() {
        let schema = ToonSchema.object(fields: [
            .field("level1", .object(fields: [
                .field("level2", .object(fields: [
                    .field("level3", .number)
                ]))
            ]))
        ])
        
        let value: JSONValue = .object([
            "level1": .object([
                "level2": .object([
                    "level3": .string("wrong")
                ])
            ])
        ])
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(_, _, let path) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(path, "$level1.level2.level3")
        }
    }
    
    func testNestedArrayValidation() throws {
        let schema = ToonSchema.array(
            element: .array(element: .number)
        )
        
        let value: JSONValue = .array([
            .array([.number(1), .number(2)]),
            .array([.number(3), .number(4)])
        ])
        
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testNestedArrayReportsDeepPath() {
        let schema = ToonSchema.array(
            element: .array(element: .string)
        )
        
        let value: JSONValue = .array([
            .array([.string("ok")]),
            .array([.number(999)])
        ])
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(_, _, let path) = error else {
                return XCTFail("Expected typeMismatch, got \(error)")
            }
            XCTAssertEqual(path, "$[1][0]")
        }
    }
    
    // MARK: - Helper Methods Coverage
    
    func testAllowsAdditionalKeysWhenTrue() {
        let schema = ToonSchema.object(fields: [], allowAdditionalKeys: true)
        XCTAssertTrue(schema.allowsAdditionalKeys)
    }
    
    func testAllowsAdditionalKeysWhenFalse() {
        let schema = ToonSchema.object(fields: [], allowAdditionalKeys: false)
        XCTAssertFalse(schema.allowsAdditionalKeys)
    }
    
    func testAllowsAdditionalKeysForNonObjectSchemas() {
        XCTAssertTrue(ToonSchema.string.allowsAdditionalKeys)
        XCTAssertTrue(ToonSchema.number.allowsAdditionalKeys)
        XCTAssertTrue(ToonSchema.bool.allowsAdditionalKeys)
        XCTAssertTrue(ToonSchema.null.allowsAdditionalKeys)
        XCTAssertTrue(ToonSchema.any.allowsAdditionalKeys)
        XCTAssertTrue(ToonSchema.array(element: .string).allowsAdditionalKeys)
    }
    
    func testSchemaForFieldReturnsNilForNonObject() {
        let arraySchema = ToonSchema.array(element: .number)
        XCTAssertNil(arraySchema.schema(forField: "anyField"))
        
        XCTAssertNil(ToonSchema.string.schema(forField: "field"))
        XCTAssertNil(ToonSchema.number.schema(forField: "field"))
    }
    
    func testArrayElementSchemaReturnsNilForNonArray() {
        let objectSchema = ToonSchema.object(fields: [])
        XCTAssertNil(objectSchema.arrayElementSchema)
        
        XCTAssertNil(ToonSchema.string.arrayElementSchema)
        XCTAssertNil(ToonSchema.bool.arrayElementSchema)
    }
    
    func testArrayRepresentationHintReturnsAutoForNonArray() {
        let objectSchema = ToonSchema.object(fields: [])
        XCTAssertEqual(objectSchema.arrayRepresentationHint, .auto)
        
        XCTAssertEqual(ToonSchema.number.arrayRepresentationHint, .auto)
    }
    
    // MARK: - Error Description Coverage
    
    func testTypeMismatchErrorDescription() {
        let error = ToonSchemaError.typeMismatch(expected: "string", actual: "number", path: "$field")
        XCTAssertEqual(error.errorDescription, "Expected string at $field, found number.")
    }
    
    func testMissingFieldErrorDescription() {
        let error = ToonSchemaError.missingField("$user.name")
        XCTAssertEqual(error.errorDescription, "Missing expected field at $user.name.")
    }
    
    func testUnexpectedFieldErrorDescription() {
        let error = ToonSchemaError.unexpectedField("$extra")
        XCTAssertEqual(error.errorDescription, "Unexpected field at $extra.")
    }
    
    // MARK: - Complex Mixed Scenarios
    
    func testMixedNestedStructure() throws {
        let schema = ToonSchema.object(fields: [
            .field("users", .array(
                element: .object(fields: [
                    .field("id", .number),
                    .field("tags", .array(element: .string))
                ])
            ))
        ])
        
        let value: JSONValue = .object([
            "users": .array([
                .object([
                    "id": .number(1),
                    "tags": .array([.string("admin"), .string("active")])
                ]),
                .object([
                    "id": .number(2),
                    "tags": .array([.string("guest")])
                ])
            ])
        ])
        
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testEmptyArrayValidates() throws {
        let schema = ToonSchema.array(element: .string)
        let value: JSONValue = .array([])
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testEmptyObjectValidates() throws {
        let schema = ToonSchema.object(fields: [])
        let value: JSONValue = .object([:])
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testEmptyObjectWithAdditionalFieldsWhenAllowed() throws {
        let schema = ToonSchema.object(fields: [], allowAdditionalKeys: true)
        let value: JSONValue = .object(["extra": .string("allowed")])
        XCTAssertNoThrow(try schema.validate(value))
    }
    
    func testPathRenderingForRootElement() {
        let schema = ToonSchema.number
        let value: JSONValue = .string("wrong")
        
        XCTAssertThrowsError(try schema.validate(value)) { error in
            guard case ToonSchemaError.typeMismatch(_, _, let path) = error else {
                return XCTFail("Expected typeMismatch")
            }
            XCTAssertEqual(path, "$")
        }
    }
}
