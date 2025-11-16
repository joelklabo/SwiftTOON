import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonSerializerTests: XCTestCase {
    func testInlineScalarArrayUsesInlineFormat() throws {
        let json: JSONValue = .object([
            "tags": .array([.string("alpha"), .string("beta")])
        ])
        let output = ToonSerializer().serialize(jsonValue: json)

        XCTAssertTrue(
            output.contains("tags[2]: alpha,beta"),
            "Inline scalar arrays should emit a single line"
        )
    }

    func testUniformObjectArrayUsesTabularFormat() throws {
        let json: JSONValue = .object([
            "items": .array([
                .object(["id": .number(1), "name": .string("Ada")]),
                .object(["id": .number(2), "name": .string("Bob")])
            ])
        ])
        let output = ToonSerializer().serialize(jsonValue: json)

        XCTAssertTrue(output.contains("items[2]{id,name}:"), "Tabular header must list the derived columns")
        XCTAssertTrue(output.contains("  1,Ada"), "Rows should list all values inline")
        XCTAssertTrue(output.contains("  2,Bob"), "Tabular rows should be rendered in order")
    }

    func testHeterogeneousObjectArrayFallsBackToList() throws {
        let json: JSONValue = .object([
            "records": .array([
                .object(["id": .number(1), "name": .string("Ada")]),
                .object(["id": .number(2)])
            ])
        ])
        let output = ToonSerializer().serialize(jsonValue: json)

        XCTAssertTrue(
            output.contains("- id: 2"),
            "Arrays that fail the tabular schema guard should render as lists"
        )
    }

    func testSerializerQuotesUnsafeKeysAndValues() throws {
        let json: JSONValue = .object([
            "user name": .string("value,with,comma"),
            "code": .string("05")
        ])
        let output = ToonSerializer().serialize(jsonValue: json)

        XCTAssertTrue(output.contains("\"user name\":"), "Keys that contain spaces must be quoted")
        XCTAssertTrue(output.contains(": \"value,with,comma\""), "Values containing delimiters must be quoted")
        XCTAssertTrue(output.contains("code: \"05\""), "Values that look like numbers must be quoted to preserve text")
    }
}
