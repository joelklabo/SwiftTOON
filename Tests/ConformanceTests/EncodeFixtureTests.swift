import Foundation
import XCTest
@testable import TOONCodable
@testable import TOONCore

final class EncodeFixtureTests: XCTestCase {
    private static let roundTripExclusions: Set<String> = [
        "arrays-objects.json",
        "key-folding.json"
    ]
    func testEncoderMatchesFixtures() throws {
        let bundle = Bundle.module
        let urls = try XCTUnwrap(bundle.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures/encode"))

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.lastPathComponent != "representation-manifest.json" else { continue }
            let fixtureFile = try EncodeFixtureFile.load(from: url)
            for fixture in fixtureFile.tests {
                let options = fixture.options?.encodingOptions() ?? ToonEncodingOptions()
                let serializer = ToonSerializer(options: options)
                let output = serializer.serialize(jsonValue: fixture.input.value)
                XCTAssertEqual(output, fixture.expected, "\(url.lastPathComponent) – \(fixture.name)")
                verifyArrayRepresentations(
                    jsonValue: fixture.input.value,
                    output: output,
                    description: "\(url.lastPathComponent) – \(fixture.name)",
                    delimiter: options.delimiter.symbol
                )
            }
        }
    }

    func testEncodeFixturesRoundTripThroughDecoder() throws {
        let decoder = ToonDecoder()
        let bundle = Bundle.module
        let urls = try XCTUnwrap(bundle.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures/encode"))

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.lastPathComponent != "representation-manifest.json" else { continue }
            guard !Self.roundTripExclusions.contains(url.lastPathComponent) else { continue }
            let fixtureFile = try EncodeFixtureFile.load(from: url)
            for fixture in fixtureFile.tests {
                guard fixture.supportsRoundTrip else { continue }
                let serializer = ToonSerializer(options: fixture.options?.encodingOptions() ?? ToonEncodingOptions())
                let output = serializer.serialize(jsonValue: fixture.input.value)
                let decoded = try decoder.decodeJSONValue(from: Data(output.utf8))
                XCTAssertEqual(decoded, fixture.input.value, "\(url.lastPathComponent) – \(fixture.name)")
            }
        }
    }

#if canImport(Darwin)
    func testEncoderMatchesReferenceCLIOutput() throws {
        let cli = ReferenceCLI()
        let bundle = Bundle.module
        let urls = try XCTUnwrap(bundle.urls(forResourcesWithExtension: "json", subdirectory: "Fixtures/encode"))

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard url.lastPathComponent != "representation-manifest.json" else { continue }
            let fixtureFile = try EncodeFixtureFile.load(from: url)
            for fixture in fixtureFile.tests {
                guard fixture.supportsRoundTrip else { continue }
                let options = fixture.options?.encodingOptions() ?? ToonEncodingOptions()
                let serializer = ToonSerializer(options: options)
                let swiftOutput = serializer.serialize(jsonValue: fixture.input.value).trimmingCharacters(in: .whitespacesAndNewlines)

                let jsonURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("json")
                defer { try? FileManager.default.removeItem(at: jsonURL) }
                try fixture.input.jsonData().write(to: jsonURL)

                let referenceOptions = fixture.options?.encodingOptions()
                let referenceOutput = try cli.encode(jsonAt: jsonURL, options: referenceOptions)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertEqual(swiftOutput, referenceOutput, "Reference mismatch: \(url.lastPathComponent) – \(fixture.name)")
                verifyArrayRepresentations(jsonValue: fixture.input.value, output: swiftOutput, description: "\(url.lastPathComponent) – \(fixture.name)", delimiter: options.delimiter.symbol)
                try assertRepresentationParity(
                    swiftOutput: swiftOutput,
                    referenceOutput: referenceOutput,
                    delimiter: options.delimiter.symbol,
                    description: "\(url.lastPathComponent) – \(fixture.name)"
                )
            }
        }
    }
#endif
}

private enum EncodeFixtureLoaderError: Error {
    case invalidFormat(String)
}

private extension EncodeFixtureFile {
    static func load(from url: URL) throws -> EncodeFixtureFile {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else {
            throw EncodeFixtureLoaderError.invalidFormat("File is not UTF-8: \(url)")
        }
        var parser = JSONTextParser(text: text)
        let root = try parser.parse()
        return try EncodeFixtureFile(json: root)
    }

    init(json value: JSONValue) throws {
        guard case .object(let object) = value else {
            throw EncodeFixtureLoaderError.invalidFormat("Fixture root must be an object")
        }
        guard let testsValue = object.value(forKey: "tests"), case .array(let array) = testsValue else {
            throw EncodeFixtureLoaderError.invalidFormat("Missing tests array")
        }
        tests = try array.map { try EncodeFixture(json: $0) }
    }
}

private extension EncodeFixture {
    init(json value: JSONValue) throws {
        guard case .object(let object) = value else {
            throw EncodeFixtureLoaderError.invalidFormat("Fixture entry must be an object")
        }
        name = try object.requireString("name")
        input = JSONFixtureValue(value: try object.requireValue("input"))
        expected = try object.requireString("expected")
        if let optionsValue = object.value(forKey: "options") {
            options = try EncodeFixtureOptions(json: optionsValue)
        } else {
            options = nil
        }
    }
}

private extension EncodeFixtureOptions {
    init(json value: JSONValue) throws {
        guard case .object(let object) = value else {
            throw EncodeFixtureLoaderError.invalidFormat("Options must be an object")
        }
        if let delimiterValue = object.value(forKey: "delimiter"), case .string(let string) = delimiterValue {
            delimiter = string
        } else {
            delimiter = nil
        }
        if let indentValue = object.value(forKey: "indent") {
            indent = try indentValue.intValue()
        } else {
            indent = nil
        }
        if let flattenValue = object.value(forKey: "flattenDepth") {
            flattenDepth = try flattenValue.intValue()
        } else {
            flattenDepth = nil
        }
        if let foldingValue = object.value(forKey: "keyFolding"), case .string(let string) = foldingValue {
            keyFolding = KeyFoldingMode(rawValue: string)
        } else {
            keyFolding = nil
        }
    }
}

private extension JSONObject {
    func requireString(_ key: String) throws -> String {
        guard let value = value(forKey: key), case .string(let string) = value else {
            throw EncodeFixtureLoaderError.invalidFormat("Missing string for key \(key)")
        }
        return string
    }

    func requireValue(_ key: String) throws -> JSONValue {
        guard let value = value(forKey: key) else {
            throw EncodeFixtureLoaderError.invalidFormat("Missing value for key \(key)")
        }
        return value
    }
}

private extension JSONValue {
    func intValue() throws -> Int {
        switch self {
        case .number(let double):
            return Int(double)
        case .string(let string):
            guard let int = Int(string) else {
                throw EncodeFixtureLoaderError.invalidFormat("Expected integer string but found \(string)")
            }
            return int
        default:
            throw EncodeFixtureLoaderError.invalidFormat("Expected integer but found \(self)")
        }
    }
}

private extension JSONFixtureValue {
    func jsonData() throws -> Data {
        try value.orderedJSONData()
    }
}

private extension EncodeFixture {
    var supportsRoundTrip: Bool {
        guard let options else { return true }
        return options.flattenDepth == nil && options.keyFolding == nil
    }
}
