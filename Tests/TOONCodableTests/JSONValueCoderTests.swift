import XCTest
@testable import TOONCodable
@testable import TOONCore

final class JSONValueCoderTests: XCTestCase {
    func testJSONValueEncoderEncodesSimpleStruct() throws {
        struct Payload: Codable, Equatable {
            let id: Int
            let name: String
        }
        let encoder = JSONValueEncoder()
        let json = try encoder.encode(Payload(id: 42, name: "Ada"))
        let expected = JSONValue.object(JSONObject(dictionaryLiteral: ("id", .number(42)), ("name", .string("Ada"))))
        XCTAssertEqual(json, expected)
    }

    func testJSONValueDecoderDecodesNestedStructure() throws {
        struct Profile: Codable, Equatable {
            struct User: Codable, Equatable {
                let name: String
                let tags: [String]
            }

            let user: User
        }

        let json = JSONValue.object(JSONObject(dictionaryLiteral: (
            "user",
            .object(JSONObject(dictionaryLiteral: (
                "name", .string("Ada")), (
                "tags", .array([.string("a"), .string("b")])
            )))
        )))

        let decoder = JSONValueDecoder()
        let decoded = try decoder.decode(Profile.self, from: json)
        XCTAssertEqual(decoded.user.name, "Ada")
        XCTAssertEqual(decoded.user.tags, ["a", "b"])
    }

    func testEncoderDecoderRoundTrip() throws {
        struct Record: Codable, Equatable {
            let flag: Bool
            let values: [Int]
        }
        let original = Record(flag: true, values: [1, 2, 3])

        let json = try JSONValueEncoder().encode(original)
        let decoded = try JSONValueDecoder().decode(Record.self, from: json)
        XCTAssertEqual(decoded, original)
    }
}
