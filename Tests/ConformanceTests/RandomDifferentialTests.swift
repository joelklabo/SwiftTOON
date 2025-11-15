#if canImport(Darwin)
import Foundation
import XCTest
@testable import TOONCodable
@testable import TOONCore

final class RandomDifferentialTests: XCTestCase {
    func testRandomJSONMatchesReferenceEncoderAndDecoder() throws {
        let cli = ReferenceCLI()
        var generator = RandomJSONGenerator(seed: 0xC0FFEE)
        let encoder = ToonSerializer()
        let decoder = ToonDecoder()

        for iteration in 0..<25 {
            let jsonValue = generator.nextJSON()
            let swiftOutput = encoder.serialize(jsonValue: jsonValue).trimmingCharacters(in: .whitespacesAndNewlines)

            let jsonURL = temporaryJSONURL(for: iteration)
            try jsonValue.jsonData(sortedKeys: true).write(to: jsonURL)
            let referenceOutput = try cli.encode(jsonAt: jsonURL).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(swiftOutput, referenceOutput, "Encoder mismatch for seed \(iteration)")

            let decoded = try decoder.decodeJSONValue(from: Data(referenceOutput.utf8))
            XCTAssertEqual(decoded, jsonValue, "Decoder mismatch for seed \(iteration)")

            try? FileManager.default.removeItem(at: jsonURL)
        }
    }

    private func temporaryJSONURL(for iteration: Int) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("random-\(iteration)-\(UUID().uuidString)")
            .appendingPathExtension("json")
    }
}

private struct RandomJSONGenerator {
    private var rng: LCG
    private let maxDepth = 3
    private let keys = ["id", "name", "active", "items", "meta", "value", "status", "count", "flag"]

    init(seed: UInt64) {
        self.rng = LCG(state: seed)
    }

    mutating func nextJSON(depth: Int = 0) -> JSONValue {
        if depth >= maxDepth {
            return nextScalar()
        }
        switch rng.next() % 5 {
        case 0:
            return nextScalar()
        case 1:
            return .array((0..<Int(rng.next() % 3 + 1)).map { _ in nextJSON(depth: depth + 1) })
        case 2:
            return randomObject(depth: depth + 1)
        case 3:
            return .bool((rng.next() & 1) == 0)
        default:
            return .null
        }
    }

    private mutating func randomObject(depth: Int) -> JSONValue {
        var object = JSONObject()
        let count = Int(rng.next() % 3 + 1)
        for index in 0..<count {
            let key = keys[Int(rng.next() % UInt64(keys.count))]
                + (rng.next() & 1 == 0 ? "" : "_\(index)")
            object[key] = nextJSON(depth: depth)
        }
        return .object(object)
    }

    private mutating func nextScalar() -> JSONValue {
        switch rng.next() % 4 {
        case 0:
            return .string("value-\(rng.next() % 10_000)")
        case 1:
            return .number(Double(rng.next() % 10_000) / 10.0)
        case 2:
            return .bool((rng.next() & 1) == 0)
        default:
            return .null
        }
    }

    private struct LCG {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1
            return state
        }
    }
}

private extension JSONValue {
    func jsonData(sortedKeys: Bool = false) throws -> Data {
        let any = toAny()
        var options: JSONSerialization.WritingOptions = []
        if sortedKeys {
            options.insert(.sortedKeys)
        }
        return try JSONSerialization.data(withJSONObject: any, options: options)
    }
}
#endif
