import XCTest
@testable import TOONCLI

final class CLITests: XCTestCase {
    func testHelpOutputContainsUsage() throws {
        let runner = TOONCLI.Runner()
        let output = try runner.invoke(arguments: ["--help"])
        XCTAssertTrue(output.contains("Usage:"), "Help output should include usage information")
        XCTAssertTrue(output.contains("toon-swift encode"), "Help should document encode command")
    }

    func testStatsCommandEmitsJSON() throws {
        let runner = TOONCLI.Runner()
        let json = """
        {"name": "Ada", "score": 42}
        """
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        try json.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let output = try runner.invoke(arguments: ["stats", tempURL.path])
        let data = try XCTUnwrap(output.data(using: .utf8))
        let parsed = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = parsed as? [String: Any] else {
            return XCTFail("Stats output should be JSON object")
        }
        XCTAssertNotNil(dict["jsonBytes"])
        XCTAssertNotNil(dict["toonBytes"])
        XCTAssertNotNil(dict["reductionPercent"])
    }
}
