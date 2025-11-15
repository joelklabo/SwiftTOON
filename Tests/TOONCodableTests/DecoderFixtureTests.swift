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
}

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
