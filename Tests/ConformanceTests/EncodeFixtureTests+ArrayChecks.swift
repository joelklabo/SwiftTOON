import XCTest
@testable import TOONCodable
@testable import TOONCore

extension EncodeFixtureTests {
    func verifyArrayRepresentations(jsonValue: JSONValue, output: String, description: String, delimiter: String = ",") {
        for analysis in analyzeArrays(in: jsonValue, keyPath: nil, delimiter: delimiter) {
            guard let keyPath = analysis.keyPath,
                  !keyPath.contains("."),
                  !keyPath.contains("[") else { continue }
            let header = generateHeader(for: analysis, delimiter: delimiter)
            switch analysis.representation {
            case .inline:
                XCTAssertTrue(
                    output.contains("\(header):"),
                    "\(description) – expected inline array at \(analysis.keyPath ?? "<root>")"
                )
                XCTAssertFalse(
                    output.contains("\(header):\n"),
                    "\(description) – inline array \(analysis.keyPath ?? "<root>") should not break lines"
                )
            case .tabular(let headers, _):
                let tabularHeader = generateHeader(for: analysis, headers: headers, delimiter: delimiter)
                XCTAssertTrue(
                    output.contains("\(tabularHeader):\n"),
                    "\(description) – expected tabular header \(tabularHeader)"
                )
            case .list:
                XCTAssertTrue(
                    output.contains("\(header):\n"),
                    "\(description) – expected list header \(header)"
                )
                XCTAssertTrue(
                    output.contains("- "),
                    "\(description) – expected list rows near \(header)"
                )
            case .empty:
                XCTAssertTrue(
                    output.contains("\(header):"),
                    "\(description) – expected empty array header \(header)"
                )
            }
        }
    }

    private func analyzeArrays(in value: JSONValue, keyPath: String?, delimiter: String) -> [ArrayAnalysis] {
        var results: [ArrayAnalysis] = []
        switch value {
        case .array(let array):
            let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: delimiter)
            results.append(ArrayAnalysis(keyPath: keyPath, representation: representation, count: array.count))
            for (index, element) in array.enumerated() {
                let nestedKey = keyPath.map { "\($0).\(index)" } ?? "[\(index)]"
                results += analyzeArrays(in: element, keyPath: nestedKey, delimiter: delimiter)
            }
        case .object(let object):
            for (key, nested) in object.orderedPairs() {
                let newPath = keyPath.map { "\($0).\(key)" } ?? key
                results += analyzeArrays(in: nested, keyPath: newPath, delimiter: delimiter)
            }
        default:
            break
        }
        return results
    }

    private func generateHeader(for analysis: ArrayAnalysis, headers: [String]? = nil, delimiter: String = ",") -> String {
        let count = analysis.count
        let suffix = delimiter == "," ? "" : delimiter
        let body = "[\(count)\(suffix)]"
        let head = analysis.keyPath.map { "\(ToonKeyQuoter.encode($0))\(body)" } ?? body
        if let headers = headers, !headers.isEmpty {
            let encodedHeaders = headers.map { ToonKeyQuoter.encode($0) }.joined(separator: delimiter)
            return "\(head){\(encodedHeaders)}"
        }
        return head
    }

    private struct ArrayAnalysis {
        let keyPath: String?
        let representation: ToonAnalyzer.ArrayRepresentation
        let count: Int
    }

    func representationMap(fromOutput output: String, delimiter: String, lenient: Bool = false) throws -> [String: ToonAnalyzer.ArrayRepresentation] {
        let decoder = ToonDecoder(options: .init(lenient: lenient))
        let value: JSONValue
        do {
            value = try decoder.decodeJSONValue(from: Data(output.utf8))
        } catch {
            print("Failed to parse TOON output (lenient=\(lenient)):\n\(output)\n---")
            throw error
        }
        return analyzeArrays(in: value, keyPath: nil, delimiter: delimiter).reduce(into: [:]) { result, analysis in
            let path = analysis.keyPath ?? "<root>"
            result[path] = analysis.representation
        }
    }

    func assertRepresentationParity(swiftOutput: String, referenceOutput: String, delimiter: String, description: String) throws {
        let swiftMap = try representationMap(fromOutput: swiftOutput, delimiter: delimiter, lenient: true)
        let referenceMap = try representationMap(fromOutput: referenceOutput, delimiter: delimiter, lenient: true)
        XCTAssertEqual(swiftMap.count, referenceMap.count, "\(description) – representation key counts differ")
        for key in swiftMap.keys {
            XCTAssertEqual(
                swiftMap[key],
                referenceMap[key],
                "\(description) – representation mismatch at \(key)"
            )
        }
    }
}
