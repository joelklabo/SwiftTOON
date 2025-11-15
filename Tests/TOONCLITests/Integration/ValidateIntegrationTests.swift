import XCTest
@testable import TOONCLI

final class ValidateIntegrationTests: XCTestCase {
    func testValidateCommandReportsSuccess() throws {
        let runner = TOONCLI.Runner()
        let sample = "name: Ada\n"
        let output = try runner.invoke(arguments: ["validate"], stdin: sample)
        XCTAssertTrue(output.contains("valid"))
    }

    func testValidateFailsForInvalidInput() {
        let runner = TOONCLI.Runner()
        XCTAssertThrowsError(try runner.invoke(arguments: ["validate"], stdin: "name: \"Ada"))
    }
}
