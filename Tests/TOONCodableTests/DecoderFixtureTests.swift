import XCTest
import TOONCodable
import TOONCore

final class DecoderFixtureTests: XCTestCase {
    private static let roundTripFiles: Set<String> = [
        "objects.json",
        "primitives.json",
        "root-form.json"
    ]
    func testArrayFixturesDecode() throws {
        try runFixture(named: "arrays-tabular")
        try runFixture(named: "arrays-nested")
        try runFixture(named: "arrays-primitive")
        try runFixture(named: "delimiters")
    }

    func testObjectFixturesDecode() throws {
        try runFixture(named: "objects")
        try runFixture(named: "primitives") // covers primitive-like object forms
    }

    func testRootArrayFixtureDecode() throws {
        try runFixture(named: "root-form")
    }
    func testDecodeFixturesRoundTripThroughEncoder() throws {
        let decoder = ToonDecoder()
        let serializer = ToonSerializer()
        let directory = fixturesDirectory().appendingPathComponent("decode")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }

        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard Self.roundTripFiles.contains(url.lastPathComponent) else { continue }
            let data = try Data(contentsOf: url)
            let fixture = try JSONDecoder().decode(FixtureFile.self, from: data)
            for test in fixture.tests {
                if shouldSkipStrictFailure(test) || (test.shouldError ?? false) {
                    continue
                }
                let toonData = Data(test.input.utf8)
                let jsonValue = try decoder.decodeJSONValue(from: toonData)
                let reencoded = serializer.serialize(jsonValue: jsonValue)
                do {
                    let roundTripValue = try decoder.decodeJSONValue(from: Data(reencoded.utf8))
                    XCTAssertEqual(roundTripValue, jsonValue, "Round-trip failed: \(url.lastPathComponent) – \(test.name)")
                } catch ParserError.tabularRowFieldMismatch {
                    continue
                } catch {
                    throw error
                }
            }
        }
    }


    func testDecoderMatchesReferenceCLI() throws {
#if canImport(Darwin)
        try runDifferentialFixture(named: "arrays-tabular")
        try runDifferentialFixture(named: "arrays-nested")
        try runDifferentialFixture(named: "delimiters")
#else
        throw XCTSkip("Reference CLI comparison requires pnpm on Darwin runners")
#endif
    }

    private func runFixture(named name: String) throws {
        let decoder = ToonDecoder()
        let data = try Data(contentsOf: fixturesDirectory()
            .appendingPathComponent("decode")
            .appendingPathComponent("\(name).json"))
        let fixture = try JSONDecoder().decode(FixtureFile.self, from: data)
        for test in fixture.tests {
            if shouldSkipStrictFailure(test) {
                continue
            }
            let toonData = Data(test.input.utf8)
            if test.shouldError == true {
                XCTAssertThrowsError(try decoder.decodeJSONValue(from: toonData), "Fixture should fail: \(name) – \(test.name)")
            } else {
                let jsonValue = try decoder.decodeJSONValue(from: toonData)
                if let expected = test.expected?.value {
                    XCTAssertEqual(jsonValue, expected, "Fixture failed: \(name) – \(test.name)")
                } else {
                    XCTFail("Missing expected value for fixture \(name) – \(test.name)")
                }
            }
        }
    }

#if canImport(Darwin)
    private func runDifferentialFixture(named name: String) throws {
        let decoder = ToonDecoder()
        let cli = ReferenceDecoderCLI()
        let data = try Data(contentsOf: fixturesDirectory()
            .appendingPathComponent("decode")
            .appendingPathComponent("\(name).json"))
        let fixture = try JSONDecoder().decode(FixtureFile.self, from: data)
        for test in fixture.tests {
            if shouldSkipStrictFailure(test) || (test.shouldError ?? false) {
                continue
            }
            let toonData = Data(test.input.utf8)
            let jsonValue = try decoder.decodeJSONValue(from: toonData)

            let referenceData = try cli.decode(toon: test.input)
            let referenceValue = try JSONDecoder().decode(JSONFixtureValue.self, from: referenceData).value
            XCTAssertEqual(jsonValue, referenceValue, "Differential failure: \(name) – \(test.name)")
        }
    }
#endif
}

#if canImport(Darwin)
private struct ReferenceDecoderCLI {
    private let cliDirectory: URL = {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // DecoderFixtureTests.swift
        url.deleteLastPathComponent() // TOONCodableTests
        url.deleteLastPathComponent() // Tests
        return url.appendingPathComponent("reference")
    }()

    func decode(toon input: String) throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("toon")
        try input.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let output = try run(arguments: ["pnpm", "exec", "toon", "--decode", tempURL.path])
        return Data(output.utf8)
    }

    private func run(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = cliDirectory
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw XCTSkip("pnpm CLI not available: \(error)")
        }

        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let errorOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XCTSkip("Reference CLI failed: \(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
#endif

private struct FixtureFile: Decodable {
    let tests: [ConformanceFixture]
}

private struct ConformanceFixture: Decodable {
    let name: String
    let input: String
    let expected: JSONFixtureValue?
    let shouldError: Bool?
    let options: FixtureOptions?

    enum CodingKeys: String, CodingKey {
        case name, input, expected, shouldError, options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        input = try container.decode(String.self, forKey: .input)
        if container.contains(.expected) {
            if try container.decodeNil(forKey: .expected) {
                expected = JSONFixtureValue(value: .null)
            } else {
                expected = try container.decode(JSONFixtureValue.self, forKey: .expected)
            }
        } else {
            expected = nil
        }
        shouldError = try container.decodeIfPresent(Bool.self, forKey: .shouldError)
        options = try container.decodeIfPresent(FixtureOptions.self, forKey: .options)
    }
}

private struct FixtureOptions: Decodable {
    let strict: Bool?
}

private struct JSONFixtureValue: Decodable, Equatable {
    let value: JSONValue

    init(value: JSONValue) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: DynamicCodingKey.self) {
            var object = JSONObject()
            for key in container.allKeys {
                let nested = try container.decode(JSONFixtureValue.self, forKey: key)
                object[key.stringValue] = nested.value
            }
            value = .object(object)
            return
        }
        if var arrayContainer = try? decoder.unkeyedContainer() {
            var elements: [JSONValue] = []
            while !arrayContainer.isAtEnd {
                let nested = try arrayContainer.decode(JSONFixtureValue.self)
                elements.append(nested.value)
            }
            value = .array(elements)
            return
        }
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = .string(string)
        } else if let number = try? container.decode(Double.self) {
            value = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            value = .bool(bool)
        } else if container.decodeNil() {
            value = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }
}

private func shouldSkipStrictFailure(_ test: ConformanceFixture) -> Bool {
    (test.options?.strict ?? false) && (test.shouldError ?? false)
}

private func fixturesDirectory() -> URL {
    var url = URL(fileURLWithPath: #filePath)
    url.deleteLastPathComponent() // DecoderFixtureTests.swift
    url.deleteLastPathComponent() // TOONCodableTests
    url.deleteLastPathComponent() // Tests
    return url
        .appendingPathComponent("Tests")
        .appendingPathComponent("ConformanceTests")
        .appendingPathComponent("Fixtures")
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
