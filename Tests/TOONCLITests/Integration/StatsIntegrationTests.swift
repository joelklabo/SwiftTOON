import XCTest
@testable import TOONCLI

final class StatsIntegrationTests: XCTestCase {
    func testStatsOutputsJSONSummary() throws {
        let sampleJSON = #"{"items":[{"id":1},{"id":2}]}"#
        let inputURL = try temporaryJSONFile(contents: sampleJSON)
        let runner = TOONCLI.Runner()
        let output = try runner.invoke(arguments: ["stats", inputURL.path])
        let data = try XCTUnwrap(output.data(using: .utf8))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(object?["jsonBytes"])
        XCTAssertNotNil(object?["toonBytes"])
        XCTAssertNotNil(object?["reductionPercent"])
    }

    private func temporaryJSONFile(contents: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let path = tempDir.appendingPathComponent("input.json")
        try contents.data(using: .utf8)?.write(to: path)
        return path
    }
}
