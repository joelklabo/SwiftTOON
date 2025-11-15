import XCTest
@testable import TOONCore

final class ParserTabularTests: XCTestCase {
    func testParsesSimpleTabularArray() throws {
        let input = """
        items[2]{sku,qty,price}:
          A1,2,9.99
          B2,1,14.5
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .object(["sku": .string("A1"), "qty": .number(2), "price": .number(9.99)]),
                .object(["sku": .string("B2"), "qty": .number(1), "price": .number(14.5)]),
            ]),
        ]))
    }

    func testParsesListArrayWithMixedValues() throws {
        let input = """
        items[3]:
          - first
          - second
          -
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .string("first"),
                .string("second"),
                .object([:]),
            ]),
        ]))
    }

    func testParsesListArrayOfObjects() throws {
        let input = """
        items[2]:
          - id: 1
            name: First
          - id: 2
            name: Second
            extra: true
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .object(["id": .number(1), "name": .string("First")]),
                .object(["id": .number(2), "name": .string("Second"), "extra": .bool(true)]),
            ]),
        ]))
    }

    func testParsesObjectContainingInlineArray() throws {
        let input = """
        items[1]:
          - name: test
            data[0]:
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .object([
                    "name": .string("test"),
                    "data": .array([]),
                ]),
            ]),
        ]))
    }

    func testParsesRootTabularArray() throws {
        let input = """
        [2]{id,name}:
          1,Ada
          2,Bob
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .array([
            .object(["id": .number(1), "name": .string("Ada")]),
            .object(["id": .number(2), "name": .string("Bob")]),
        ]))
    }

    func testInlinePrimitiveArrayParsing() throws {
        let input = """
        tags[3]: alpha,beta,gamma
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "tags": .array([
                .string("alpha"),
                .string("beta"),
                .string("gamma"),
            ]),
        ]))
    }

    func testInlineArrayLengthMismatchThrows() throws {
        let input = """
        tags[2]: a,b,c
        """
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse())
    }

    func testParsesTabDelimitedTabularArray() throws {
        let input = """
        items[2\t]{sku\tqty}:
          A1\t2
          B2\t1
        """
        var parser = try Parser(input: input)
        let value = try parser.parse()
        XCTAssertEqual(value, .object([
            "items": .array([
                .object(["sku": .string("A1"), "qty": .number(2)]),
                .object(["sku": .string("B2"), "qty": .number(1)]),
            ]),
        ]))
    }

    func testTabularRowCountMismatchThrows() throws {
        let input = """
        items[2]{id,name}:
          1,Ada
        """
        var parser = try Parser(input: input)
        XCTAssertThrowsError(try parser.parse())
    }
}
