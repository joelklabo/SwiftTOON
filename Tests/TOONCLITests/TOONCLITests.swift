import XCTest
#warning()
@testable import TOONCLI

final class TOONCLITests: XCTestCase {
    func testHelpCommandExitsCleanly() throws {
        XCTAssertNoThrow(try TOONCLI.Runner().run(arguments: ["--help"]))
    }

    func testRunningWithoutArgumentsFailsUntilCLIIsBuilt() {
        XCTAssertThrowsError(try TOONCLI.Runner().run(arguments: [])) { error in
            XCTAssertEqual(error as? TOONCLI.CLError, .notImplemented)
        }
    }
}
