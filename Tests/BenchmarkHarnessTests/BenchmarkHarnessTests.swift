import Foundation
import XCTest
@testable import TOONBenchmarks

final class BenchmarkHarnessTests: XCTestCase {
    func testSmokeBenchmarkPlaceholder() {
        XCTAssertEqual(BenchmarkSuite.smoke(), "benchmarks pending")
    }

    func testLexerThroughputReturnsPositiveValue() throws {
        let throughput = try BenchmarkSuite.lexerThroughput(iterations: 1)
        XCTAssertGreaterThan(throughput, 0)
    }

    func testParserThroughputReturnsPositiveValue() throws {
        let throughput = try BenchmarkSuite.parserThroughput(iterations: 1)
        XCTAssertGreaterThan(throughput, 0)
    }

    func testBaselineManifestExists() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // BenchmarkHarnessTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repo root
            .appendingPathComponent("Benchmarks/baseline_reference.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), "Baseline manifest missing. Create Benchmarks/baseline_reference.json.")
    }
}
