import XCTest
@testable import TOONCLI

final class BenchIntegrationTests: XCTestCase {
    func testBenchOutputsJSON() throws {
        let runner = TOONCLI.Runner()
        let output = try runner.invoke(arguments: ["bench", "--format", "json", "--iterations", "1"])
        let data = try XCTUnwrap(output.data(using: .utf8))
        let samples = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(samples)
        XCTAssertFalse(samples?.isEmpty ?? true)
    }

    func testBenchWritesToFile() throws {
        let runner = TOONCLI.Runner()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let outputURL = tempDir.appendingPathComponent("bench.json")
        _ = try runner.invoke(arguments: ["bench", "--format", "json", "--output", outputURL.path, "--iterations", "1"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        let contents = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("lexer_micro"))
    }
}
