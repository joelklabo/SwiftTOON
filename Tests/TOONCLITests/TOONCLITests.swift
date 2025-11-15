import XCTest
@testable import TOONCLI

final class TOONCLITests: XCTestCase {
    func testHelpCommandExitsCleanly() throws {
        let output = try TOONCLI.Runner().invoke(arguments: ["--help"])
        XCTAssertTrue(output.lowercased().contains("usage"))
    }

    func testRunningWithoutArgumentsShowsUsage() throws {
        let output = try TOONCLI.Runner().invoke(arguments: [])
        XCTAssertTrue(output.lowercased().contains("usage"))
    }
}
