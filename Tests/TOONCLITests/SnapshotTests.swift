import XCTest
@testable import TOONCLI

final class SnapshotTests: XCTestCase {
    func testHelpMatchesSnapshot() throws {
        let output = try TOONCLI.Runner().invoke(arguments: ["--help"])
        XCTAssertEqual(output, try loadSnapshot(named: "help"))
    }

    private func loadSnapshot(named name: String) throws -> String {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Snapshots")
            .appendingPathComponent("\(name).txt")
        return try String(contentsOf: fileURL, encoding: .utf8)
    }
}
