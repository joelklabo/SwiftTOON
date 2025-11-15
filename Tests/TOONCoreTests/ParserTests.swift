import XCTest
@testable import TOONCore

final class ParserTests: XCTestCase {
    func testParseSimpleObject() throws {
        var parser = try Parser(input: "name: Alice\nage: 30\n")
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "name": .string("Alice"),
            "age": .number(30),
        ]))
    }

    func testParseNestedObjectUsingIndent() throws {
        let input = """
        user:
          name: Ada
          profile:
            role: admin
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "user": .object([
                "name": .string("Ada"),
                "profile": .object([
                    "role": .string("admin"),
                ]),
            ]),
        ]))
    }

    func testMissingIndentAfterColonProducesEmptyObject() throws {
        var parser = try Parser(input: "user:\n")
        let value = try parser.parse()
        XCTAssertEqual(value, .object(["user": .object([:])]))
    }

    func testParseObjectWithInlinePrimitives() throws {
        let input = """
        item:
          active: true
          count: 2
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "item": .object([
                "active": .bool(true),
                "count": .number(2),
            ]),
        ]))
    }

    func testTrailingWhitespaceIgnored() throws {
        let input = "name: Ada   \n"
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object(["name": .string("Ada")]))
    }

    func testQuotedRootValue() throws {
        let input = "\"hello world\""
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .string("hello world"))
    }

    func testLenientInlineArrayAllowsMismatch() throws {
        let input = "tags[2]: alpha,beta,gamma"
        var parser = try Parser(input: input, options: Parser.Options(lenientArrays: true))
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "tags": .array([.string("alpha"), .string("beta"), .string("gamma")]),
        ]))
    }

    func testStrictInlineArrayThrowsMismatch() throws {
        let input = "tags[2]: alpha,beta,gamma"
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case let ParserError.inlineArrayLengthMismatch(expected, actual, _, _) = error else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(expected, 2)
            XCTAssertEqual(actual, 3)
        }
    }

    func testRootEmptyInputProducesEmptyObject() throws {
        var parser = try Parser(input: "")
        let value = try parser.parse()
        XCTAssertEqual(value, .object([:]))
    }

    func testStandaloneValueAsStringPreservesSpacing() throws {
        let input = "value: hello world  \n"
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object(["value": .string("hello world  ")]))
    }

    func testLooseTokensProduceStringValue() throws {
        let input = ": value"
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .string(" value"))
    }
}
