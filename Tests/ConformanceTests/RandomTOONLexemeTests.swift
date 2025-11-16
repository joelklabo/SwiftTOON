#if canImport(Darwin)
import Foundation
import XCTest
@testable import TOONCodable
@testable import TOONCore

final class RandomTOONLexemeTests: XCTestCase {
    func testRandomTOONMatchesReferenceDecoder() throws {
        let cli = ReferenceCLI()
        var generator = RandomTOONGenerator(seed: 0xDEADBEEF)
        let strictDecoder = ToonDecoder()
        let lenientDecoder = ToonDecoder(options: .init(lenient: true))

        for iteration in 0..<30 {
            let sample = generator.nextCase()
            let data = Data(sample.toon.utf8)
            if ProcessInfo.processInfo.environment["DEBUG_RANDOM_TOON"] == "1" {
                print("Sample \(iteration):\n\(sample.toon)")
            }

            if sample.requiresLenient {
                XCTAssertThrowsError(try strictDecoder.decodeJSONValue(from: data), "Strict mode should fail for sample \(iteration)")
                let lenientValue = try lenientDecoder.decodeJSONValue(from: data)
                XCTAssertEqual(lenientValue, sample.expected, "Lenient decode mismatch for sample \(iteration)")
            } else {
                let decoded = try strictDecoder.decodeJSONValue(from: data)
                XCTAssertEqual(decoded, sample.expected, "Strict decode mismatch for sample \(iteration)")
                if sample.cliCompatible {
                    try assertReferenceMatch(sample: sample, iteration: iteration, cli: cli)
                }
            }
        }
    }

    private func assertReferenceMatch(sample: RandomTOONCase, iteration: Int, cli: ReferenceCLI) throws {
        let referenceJSON = try cli.decode(toon: sample.toon).trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(referenceJSON.utf8)
        let wrapper = try JSONDecoder().decode(FixtureTest.JSONValueWrapper.self, from: data)
        XCTAssertEqual(wrapper.value, sample.expected, "Reference CLI mismatch for sample \(iteration)")
    }
}
#endif
