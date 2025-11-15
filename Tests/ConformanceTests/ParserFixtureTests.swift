import Foundation
import XCTest
@testable import TOONCore

final class ParserFixtureTests: XCTestCase {
    func testTabularFixtureParity() throws {
        try runFixture(named: "arrays-tabular")
        try runFixture(named: "arrays-nested")
    }

    private func runFixture(named name: String) throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/decode"))
        let data = try Data(contentsOf: url)
        let fixture = try JSONDecoder().decode(FixtureFile.self, from: data)
        for test in fixture.tests {
            var parser = try Parser(input: test.input)
            let value = try parser.parse()
            XCTAssertEqual(value, test.expected.value, "Fixture failed: \(name) – \(test.name)")
        }
    }
}

private struct FixtureFile: Decodable {
    let tests: [FixtureTest]
}
