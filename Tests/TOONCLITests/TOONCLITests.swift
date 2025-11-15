import XCTest
@testable import TOONCLI

final class TOONCLITests: XCTestCase {
    func testHelpCommandExitsCleanly() throws {
        let output = try TOONCLI.Runner().invoke(arguments: ["--help"])
        XCTAssertTrue(output.contains("toon-swift encode"))
        XCTAssertTrue(output.contains("toon-swift validate"))
    }

    func testRunningWithoutArgumentsShowsUsage() throws {
        let output = try TOONCLI.Runner().invoke(arguments: [])
        XCTAssertTrue(output.contains("toon-swift decode"))
    }
}
