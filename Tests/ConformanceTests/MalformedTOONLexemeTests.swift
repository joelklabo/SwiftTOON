import Foundation
import XCTest
@testable import TOONCodable
@testable import TOONCore

final class MalformedTOONLexemeTests: XCTestCase {
    func testMalformedTOONInputsAlwaysFailDecoding() throws {
        var generator = MalformedTOONGenerator(seed: 0xBAD0C0DE)
        let decoder = ToonDecoder()

        for iteration in 0..<40 {
            let sample = generator.nextCase()
            let data = Data(sample.toon.utf8)
            XCTAssertThrowsError(try decoder.decodeJSONValue(from: data), "Expected failure for malformed sample #\(iteration)") { error in
                XCTAssertTrue(sample.expectation.matches(error), "Unexpected error for sample #\(iteration): expected \(sample.expectation.description), got \(error)")
            }
        }
    }
}
