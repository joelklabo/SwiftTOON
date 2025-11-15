import XCTest
@testable import TOONCore

final class JSONObjectTests: XCTestCase {
    func testInsertUpdateRemoveMaintainsExpectedState() {
        var object = JSONObject()
        XCTAssertTrue(object.isEmpty)

        object["name"] = .string("Ada")
        object["id"] = .number(1)
        XCTAssertEqual(object.count, 2)
        XCTAssertEqual(object.orderedPairs().map(\.0), ["name", "id"], "Insertion order should be preserved")

        let previous = object.updateValue(.number(2), forKey: "id")
        XCTAssertEqual(previous, .number(1))
        XCTAssertEqual(object["id"], .number(2))

        let removed = object.removeValue(forKey: "name")
        XCTAssertEqual(removed, .string("Ada"))
        XCTAssertNil(object["name"])

        object["active"] = .bool(true)
        let dictionary = object.toDictionary()
        XCTAssertEqual(dictionary["active"], .bool(true))
        XCTAssertEqual(object.value(forKey: "active"), .bool(true))
    }

    func testEqualityAndValueLookup() {
        let lhs: JSONObject = [
            "count": .number(2),
            "items": .array([.string("a"), .string("b")]),
        ]

        var rhs = JSONObject()
        rhs["items"] = .array([.string("a"), .string("b")])
        rhs["count"] = .number(2)

        XCTAssertEqual(lhs, rhs, "Equality should not depend on insertion order")
        XCTAssertEqual(lhs.value(forKey: "count"), .number(2))
        XCTAssertNil(lhs.value(forKey: "missing"))
    }
}
