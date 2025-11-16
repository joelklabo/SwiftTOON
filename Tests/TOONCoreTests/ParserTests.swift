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

    func testRootArrayMissingBodyThrows() throws {
        let input = "[1]\n"
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken(_, _, let expected) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, "array")
        }
    }

    func testNestedObjectWithoutKeyThrows() throws {
        let input = """
        root:
          : value
        """
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken(_, _, let expected) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, "identifier")
        }
    }

    func testArrayLengthMustBeNumeric() throws {
        let input = "items[foo]:"
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.invalidNumberLiteral(let literal, _, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(literal.isEmpty)
        }
    }

    func testListArrayRequiresDash() throws {
        let input = """
        items[1]:
          value: test
        """
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken(_, _, let expected) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, "list item '-'")
        }
    }

    func testLiteralTokensBecomeStrings() throws {
        let input = """
        symbols:
          comma: ,
          pipe: |
          tab:\t
          dash: -
          brace: }
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "symbols": .object([
                "comma": .string(","),
                "pipe": .string("|"),
                "tab": .string("\t"),
                "dash": .string("-"),
                "brace": .string("}"),
            ]),
        ]))
    }

    func testArrayDeclarationRequiresClosingBracket() throws {
        let input = "items[:"
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken(_, _, let expected) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, "] after array declaration")
        }
    }

    func testTabularHeaderRequiresClosingBrace() throws {
        let input = "items[1]{"
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse())
    }

    func testListArrayWithExtraDashFails() throws {
        let input = """
        items[1]:
          - value
          - another
        """
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken(_, _, let expected) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, "end of list items")
        }
    }

    func testLenientListArrayPadsMissingItems() throws {
        let input = """
        items[3]:
          - first
          - second
        """
        var parser = try Parser(input: input, options: Parser.Options(lenientArrays: true))
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .string("first"),
                .string("second"),
                .null,
            ]),
        ]))
    }

    func testLenientListArrayTruncatesExtraItems() throws {
        let input = """
        items[1]:
          - single
          - ignored
        """
        var parser = try Parser(input: input, options: Parser.Options(lenientArrays: true))
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .string("single"),
            ]),
        ]))
    }

    func testNestedArrayInlineFallbackEnabled() throws {
        let input = """
        items[1]:
          - [2
        """
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse()) { error in
            guard case ParserError.unexpectedToken(_, _, let expected) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(expected, "] after array declaration")
        }
    }

    func testLiteralFallbackForStandaloneToken() throws {
        let input = "value: ]"
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object(["value": .string("]")]))
    }

    func testListArrayFollowedBySiblingKeysParsesAllEntries() throws {
        let input = """
        active_0[2]:
          - [3]: value-4669,false,value-3577
          - null
        active_1:
          flag_0:
            name_0: false
          flag_1:
            id_0: false
            id_1: false
        meta_2[2]:
          - [1]: false
          - id_0: value-3185
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        let expected: JSONValue = .object([
            "active_0": .array([
                .array([.string("value-4669"), .bool(false), .string("value-3577")]),
                .null,
            ]),
            "active_1": .object([
                "flag_0": .object(["name_0": .bool(false)]),
                "flag_1": .object([
                    "id_0": .bool(false),
                    "id_1": .bool(false),
                ]),
            ]),
            "meta_2": .array([
                .array([.bool(false)]),
                .object(["id_0": .string("value-3185")]),
            ]),
        ])
        XCTAssertEqual(value, expected)
    }
}
