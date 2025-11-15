import XCTest
import TOONCodable
import TOONCore

final class DecoderFixtureTests: XCTestCase {
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
            let toonData = Data(test.input.utf8)
            let jsonValue = try decoder.decodeJSONValue(from: toonData)
            XCTAssertEqual(jsonValue, test.expected.value, "Fixture failed: \(name) – \(test.name)")
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
    let expected: JSONFixtureValue
}

private struct JSONFixtureValue: Decodable, Equatable {
    let value: JSONValue

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: JSONFixtureValue].self) {
            value = .object(dict.mapValues(\.value))
        } else if let array = try? container.decode([JSONFixtureValue].self) {
            value = .array(array.map(\.value))
        } else if let string = try? container.decode(String.self) {
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
