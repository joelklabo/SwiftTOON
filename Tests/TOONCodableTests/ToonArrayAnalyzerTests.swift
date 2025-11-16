import XCTest
@testable import TOONCodable
import TOONCore

final class ToonArrayAnalyzerTests: XCTestCase {
    func testAnalyzerPrefersInlineForScalarArrays() {
        let array: [JSONValue] = [.string("a"), .number(1), .bool(true)]
        let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: ",")

        switch representation {
        case .inline(let values):
            XCTAssertEqual(values, ["a", "1", "true"])
        default:
            XCTFail("Expected inline representation, got \(representation)")
        }
    }

    func testAnalyzerDetectsTabularObjectArray() {
        let array: [JSONValue] = [
            .object(["id": .number(1), "flag": .bool(false)]),
            .object(["id": .number(2), "flag": .bool(true)])
        ]
        let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: ",")

        switch representation {
        case .tabular(let headers, let rows):
            XCTAssertEqual(headers, ["id", "flag"])
            XCTAssertEqual(rows, [["1", "false"], ["2", "true"]])
        default:
            XCTFail("Expected tabular representation, got \(representation)")
        }
    }

    func testAnalyzerFallsBackToListForHeterogeneousArrays() {
        let array: [JSONValue] = [
            .object(["id": .number(1)]),
            .string("unexpected")
        ]
        let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: ",")
        switch representation {
        case .list:
            break
        default:
            XCTFail("Expected list representation for heterogeneous array, got \(representation)")
        }
    }
}
