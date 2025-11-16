import Foundation
import TOONCodable
import TOONCore

struct RepresentationEntry: Codable {
    let testName: String
    let delimiter: String
    let arrays: [ArrayRepresentationRecord]
}

struct ArrayRepresentationRecord: Codable {
    let keyPath: String?
    let format: String
    let headers: [String]?
    let count: Int
}

struct Analyzer {
    static func analyze(value: JSONValue, keyPath: String?, delimiter: String) -> [ArrayRepresentationRecord] {
        var results: [ArrayRepresentationRecord] = []
        switch value {
        case .array(let array):
            let representation = ToonAnalyzer.analyzeArray(array, schema: nil, delimiterSymbol: delimiter)
            results.append(
                ArrayRepresentationRecord(
                    keyPath: keyPath,
                    format: formatName(for: representation),
                    headers: headers(for: representation),
                    count: array.count
                )
            )
            for (index, element) in array.enumerated() {
                let nestedPath = keyPath.map { "\($0).\(index)" } ?? "[\(index)]"
                results += analyze(value: element, keyPath: nestedPath, delimiter: delimiter)
            }
        case .object(let dict):
            for (key, nested) in dict.orderedPairs() {
                let path = keyPath.map { "\($0).\(key)" } ?? key
                results += analyze(value: nested, keyPath: path, delimiter: delimiter)
            }
        default:
            break
        }
        return results
    }

    private static func formatName(for representation: ToonAnalyzer.ArrayRepresentation) -> String {
        switch representation {
        case .empty: return "empty"
        case .inline: return "inline"
        case .tabular: return "tabular"
        case .list: return "list"
        }
    }

    private static func headers(for representation: ToonAnalyzer.ArrayRepresentation) -> [String]? {
        switch representation {
        case .tabular(let headers, _): return headers
        default: return nil
        }
    }
}

func jsonValue(from object: Any) throws -> JSONValue {
    return try JSONValue(jsonObject: object)
}

var fixturesDirectory = URL(fileURLWithPath: #filePath)
for _ in 0..<3 {
    fixturesDirectory.deleteLastPathComponent()
}
fixturesDirectory.appendPathComponent("Tests")
fixturesDirectory.appendPathComponent("TOONCodableTests")
fixturesDirectory.appendPathComponent("Fixtures")
fixturesDirectory.appendPathComponent("encode")

let fileManager = FileManager.default
let jsonFiles = try fileManager
    .contentsOfDirectory(at: fixturesDirectory, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension == "json" }

var manifest: [String: [RepresentationEntry]] = [:]

for file in jsonFiles {
    let data = try Data(contentsOf: file)
    let object = try JSONSerialization.jsonObject(with: data)
    guard let root = object as? [String: Any], let tests = root["tests"] as? [[String: Any]] else {
        continue
    }
    var entries: [RepresentationEntry] = []
    for test in tests {
        guard let name = test["name"] as? String else { continue }
        let delimiter = (test["options"] as? [String: Any])?["delimiter"] as? String ?? ","
        let input = test["input"] ?? NSNull()
        let jsonValue = try jsonValue(from: input)
        let arrays = Analyzer.analyze(value: jsonValue, keyPath: nil, delimiter: delimiter)
        entries.append(RepresentationEntry(testName: name, delimiter: delimiter, arrays: arrays))
    }
    manifest[file.lastPathComponent] = entries
}

let outputURL = fixturesDirectory.appendingPathComponent("representation-manifest.json")
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let manifestData = try encoder.encode(manifest)
try manifestData.write(to: outputURL)
print("Wrote representation manifest to \(outputURL.path)")
