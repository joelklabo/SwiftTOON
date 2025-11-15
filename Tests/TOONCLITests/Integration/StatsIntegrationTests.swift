import XCTest
@testable import TOONCLI

final class StatsIntegrationTests: XCTestCase {
    func testStatsOutputsJSONSummary() throws {
        let jsonInput = """
        {"items":[{"id":1},{"id":2}]}
        """
        let runner = TOONCLI.Runner()
        let output = try runner.invoke(arguments: ["stats", "--input", jsonInput])
        XCTAssertTrue(output.contains("{"))
    }
}
