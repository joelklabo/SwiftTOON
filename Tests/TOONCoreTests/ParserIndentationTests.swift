import XCTest
@testable import TOONCore

final class ParserIndentationTests: XCTestCase {
    func testIndentationVariationsProduceExpectedStructure() throws {
        let fixtures: [(name: String, input: String, expected: JSONValue)] = [
            (
                "increase",
                """
                root:
                  child:
                    value: deep
                  sibling: flat
                """,
                .object([
                    "root": .object([
                        "child": .object([
                            "value": .string("deep"),
                        ]),
                        "sibling": .string("flat"),
                    ]),
                ])
            ),
            (
                "flat",
                """
                first: one
                second: two
                third: three
                """,
                .object([
                    "first": .string("one"),
                    "second": .string("two"),
                    "third": .string("three"),
                ])
            ),
            (
                "decrease",
                """
                a:
                  nested:
                    value: deep
                standalone: top
                """,
                .object([
                    "a": .object([
                        "nested": .object([
                            "value": .string("deep"),
                        ]),
                    ]),
                    "standalone": .string("top"),
                ])
            ),
        ]

        for fixture in fixtures {
            var parser = try Parser(input: fixture.input)
            let result = try parser.parse()
            XCTAssertEqual(result, fixture.expected, "Failed indentation fixture: \(fixture.name)")
        }
    }

    func testInvalidDedentRaisesLexerError() throws {
        let input = "root:\n  child:\n   grandchild: value\n sibling: broken\n"
        XCTAssertThrowsError(try Parser(input: input)) { error in
            guard let lexerError = error as? LexerError else {
                return XCTFail("Expected LexerError, got \(error)")
            }
            guard case .invalidIndentation(_, _, let description) = lexerError else {
                return XCTFail("Expected invalidIndentation, got \(lexerError)")
            }
            XCTAssertTrue(description.contains("Mismatched dedent"))
        }
    }
}
