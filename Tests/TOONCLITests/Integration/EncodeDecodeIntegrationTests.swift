import XCTest
@testable import TOONCLI

final class EncodeDecodeIntegrationTests: XCTestCase {
    func testEncodeOutputsExpectedTOON() throws {
        let jsonInput = """
        {"name":"Ada","tags":["ops","swift"]}
        """
        let runner = TOONCLI.Runner()
        let output = try runner.invoke(arguments: ["encode", "--input", jsonInput])
        XCTAssertTrue(output.contains("name:"))
    }
}
