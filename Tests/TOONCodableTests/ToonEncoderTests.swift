import XCTest
@testable import TOONCodable

final class ToonEncoderTests: XCTestCase {
    func testEncodesSimpleObject() throws {
        struct User: Codable {
            let name: String
            let role: String
        }
        let user = User(name: "Ada", role: "admin")
        let encoder = ToonEncoder()
        let data = try encoder.encode(user)
        let output = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(output, "name: Ada\nrole: admin")
    }

    func testEncodesNestedStructure() throws {
        struct Profile: Codable {
            let user: User
            let tags: [String]
        }
        struct User: Codable {
            let name: String
            let role: String
        }
        let profile = Profile(user: User(name: "Ada", role: "admin"), tags: ["alpha", "beta", "gamma"])
        let encoder = ToonEncoder()
        let data = try encoder.encode(profile)
        let output = try XCTUnwrap(String(data: data, encoding: .utf8))
        let expected = """
user:
  name: Ada
  role: admin
tags[3]: alpha,beta,gamma
"""
        XCTAssertEqual(output, expected)
    }
}
