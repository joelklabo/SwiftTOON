import XCTest
@testable import TOONCodable
@testable import TOONCore

final class ToonEncoderTests: XCTestCase {
    func testEncodingThrowsNotImplemented() {
        struct Dummy: Codable {}
        let encoder = ToonEncoder()
        XCTAssertThrowsError(try encoder.encode(Dummy()))
    }
}
