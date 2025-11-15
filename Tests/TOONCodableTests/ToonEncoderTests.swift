import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonEncoderTests: XCTestCase {
    func testEncodesSimpleObject() throws {
        struct User: Codable, Equatable {
            let name: String
            let role: String
        }
        let user = User(name: "Ada", role: "admin")
        let encoder = ToonEncoder()
        let data = try encoder.encode(user)
        let parsed = try parseTOON(from: data)
        XCTAssertEqual(parsed, .object([
            "name": .string("Ada"),
            "role": .string("admin"),
        ]))
    }

    func testEncodesNestedStructure() throws {
        struct Profile: Codable, Equatable {
            let user: User
            let tags: [String]
        }
        struct User: Codable, Equatable {
            let name: String
            let role: String
        }
        let profile = Profile(user: User(name: "Ada", role: "admin"), tags: ["alpha", "beta", "gamma"])
        let encoder = ToonEncoder()
        let data = try encoder.encode(profile)
        let parsed = try parseTOON(from: data)
        XCTAssertEqual(parsed, .object([
            "user": .object([
                "name": .string("Ada"),
                "role": .string("admin"),
            ]),
            "tags": .array([
                .string("alpha"),
                .string("beta"),
                .string("gamma"),
            ]),
        ]))
    }

    private func parseTOON(from data: Data) throws -> JSONValue {
        let string = try XCTUnwrap(String(data: data, encoding: .utf8))
        var parser = try Parser(input: string)
        return try parser.parse()
    }
}
