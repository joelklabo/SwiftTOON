import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonAnalyzerTests: XCTestCase {
    func testInlineScalarArrayDetected() throws {
        let array: [JSONValue] = [.string("alpha"), .string("beta")]
        let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: ",")
        XCTAssertEqual(representation, .inline(values: ["alpha", "beta"]))
    }

    func testTabularObjectsDetectedWithDerivedHeaders() throws {
        let array: [JSONValue] = [
            .object(["id": .number(1), "name": .string("Ada")]),
            .object(["id": .number(2), "name": .string("Bob")]),
        ]
        let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: ",")
        XCTAssertEqual(representation, .tabular(headers: ["id", "name"], rows: [["1", "Ada"], ["2", "Bob"]]))
    }

    func testListUsedForHeterogeneousObjects() throws {
        let array: [JSONValue] = [
            .object(["id": .number(1)]),
            .object(["id": .number(2), "extra": .bool(true)]),
        ]
        let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: ",")
        XCTAssertEqual(representation, .list)
    }

    func testSchemaHintForTabularOverridesInlineDetection() throws {
        let array: [JSONValue] = [
            .object(["sku": .string("A"), "qty": .number(1)]),
            .object(["sku": .string("B"), "qty": .number(2)]),
        ]
        let schema = ToonSchema.array(element: .object(fields: [], allowAdditionalKeys: true), representation: .tabular(headers: ["sku", "qty"]))
        let representation = ToonAnalyzer.analyzeArray(array, schema: schema, delimiterSymbol: ",")
        XCTAssertEqual(representation, .tabular(headers: ["sku", "qty"], rows: [["A", "1"], ["B", "2"]]))
    }

    func testSchemaHintForListKeepsList() throws {
        let array: [JSONValue] = [
            .object(["value": .number(1)]),
        ]
        let schema = ToonSchema.array(element: .any, representation: .list)
        XCTAssertEqual(ToonAnalyzer.analyzeArray(array, schema: schema, delimiterSymbol: ","), .list)
    }

    func testEmptyArrayReportsEmpty() throws {
        let representation = ToonAnalyzer.analyzeArray([], schema: nil, delimiterSymbol: ",")
        XCTAssertEqual(representation, .empty)
    }
}
