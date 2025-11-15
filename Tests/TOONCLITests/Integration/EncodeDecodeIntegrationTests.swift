import XCTest
@testable import TOONCLI

final class EncodeDecodeIntegrationTests: XCTestCase {
    func testEncodeRoundTripFromFile() throws {
        let (jsonURL, toonURL) = try temporaryFiles(json: #"{"name":"Ada","tags":["ops","swift"]}"#)
        let runner = TOONCLI.Runner()
        let output = try runner.invoke(arguments: ["encode", jsonURL.path, "--output", toonURL.path])
        XCTAssertTrue(output.isEmpty)
        let encoded = try String(contentsOf: toonURL, encoding: .utf8)
        XCTAssertTrue(encoded.contains("name:"))
        XCTAssertTrue(encoded.contains("Ada"))
    }

    func testDecodeRoundTripToStdout() throws {
        let runner = TOONCLI.Runner()
        let sampleTOON = "name: Ada\n"
        let output = try runner.invoke(arguments: ["decode"], stdin: sampleTOON)
        XCTAssertTrue(output.contains("\"name\""))
        XCTAssertTrue(output.contains("\"Ada\""))
    }

    private func temporaryFiles(json: String) throws -> (URL, URL) {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let jsonURL = tempDir.appendingPathComponent("input.json")
        let toonURL = tempDir.appendingPathComponent("output.toon")
        try json.data(using: .utf8)?.write(to: jsonURL)
        return (jsonURL, toonURL)
    }
}
